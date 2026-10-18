#include "TtsBackend.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMap>
#include <cmath>
#include <functional>

#ifdef RESONALENS_HAS_SHERPA_ONNX
#include "sherpa-onnx/c-api/c-api.h"
#endif

// Locate the espeak-ng-data directory that has the compiled binary data files
// required by sherpa-onnx (phontab, phonindex, phondata, intonations).
// Checks (in order):
//   1. Inside the model directory — csukuangfj/kokoro-en-v0_19 on HuggingFace
//      ships pre-compiled espeak-ng-data alongside the model files.
//   2. Next to the executable — copied there by CMake POST_BUILD (desktop builds).
//   3. System-wide install paths (Linux/macOS package managers).
static QString findEspeakDataDir(const QString &modelDir = {})
{
    // A usable espeak-ng-data must have:
    //   • phontab / phonindex / phondata — compiled phoneme tables (checked by sherpa-onnx Validate())
    //   • lang/                           — voice/language files (needed by espeak at synthesis time)
    auto isComplete = [](const QString &dir) {
        return QFileInfo::exists(dir + "/phontab") &&
               QDir(dir + "/lang").exists();
    };

    // 1. Inside the downloaded model directory
    if (!modelDir.isEmpty()) {
        QString inModel = modelDir + "/espeak-ng-data";

#ifdef Q_OS_ANDROID
        // On Android, phoneme tables are downloaded with the model but lang/
        // is bundled as an APK asset. Extract lang/ once into the model dir.
        if (QFileInfo::exists(inModel + "/phontab") && !QDir(inModel + "/lang").exists()) {
            QDir assetLang("assets:/espeak-ng-data/lang");
            if (assetLang.exists()) {
                // Recursively copy lang/ from assets to model dir
                std::function<void(const QString&, const QString&)> copyDir;
                copyDir = [&](const QString &src, const QString &dst) {
                    QDir().mkpath(dst);
                    QDir srcDir(src);
                    for (const QString &entry : srcDir.entryList(QDir::Files)) {
                        QString srcFile = src + "/" + entry;
                        QString dstFile = dst + "/" + entry;
                        if (!QFileInfo::exists(dstFile))
                            QFile::copy(srcFile, dstFile);
                    }
                    for (const QString &entry : srcDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
                        copyDir(src + "/" + entry, dst + "/" + entry);
                    }
                };
                copyDir("assets:/espeak-ng-data/lang", inModel + "/lang");
                qInfo() << "TTS: extracted espeak-ng lang/ data to" << inModel;
            }
        }
#endif

        if (isComplete(inModel))
            return inModel;
    }

    // 2. Next to the executable (desktop: CMake copies it via POST_BUILD)
    QString nextToExe = QCoreApplication::applicationDirPath() + "/espeak-ng-data";
    if (isComplete(nextToExe))
        return nextToExe;

    // 3. System package install locations
    static const char *kSystemPaths[] = {
        "/usr/lib/x86_64-linux-gnu/espeak-ng-data",
        "/usr/lib/aarch64-linux-gnu/espeak-ng-data",
        "/usr/lib/arm-linux-gnueabihf/espeak-ng-data",
        "/usr/share/espeak-ng-data",
        "/usr/local/share/espeak-ng-data",
        "/opt/homebrew/share/espeak-ng-data",   // macOS Homebrew
        nullptr
    };
    for (int i = 0; kSystemPaths[i]; ++i) {
        if (isComplete(kSystemPaths[i]))
            return kSystemPaths[i];
    }

    return {};
}

// Voice name → speaker ID mapping for Kokoro en-v0.19
// See: https://huggingface.co/csukuangfj/kokoro-en-v0_19
static const QMap<QString, int> kVoiceMap = {
    {"af_heart",    0},
    {"af_bella",    1},
    {"af_nicole",   2},
    {"af_sarah",    3},
    {"af_sky",      4},
    {"am_adam",     5},
    {"am_michael",  6},
    {"bf_emma",     7},
    {"bf_isabella", 8},
    {"bm_george",   9},
    {"bm_lewis",   10},
};

TtsBackend::TtsBackend(QObject *parent)
    : QObject(nullptr)  // No parent — objects moved to another thread cannot have a parent
{
    Q_UNUSED(parent)
    moveToThread(&m_workerThread);
    m_workerThread.start();
}

TtsBackend::~TtsBackend()
{
    unloadModel();
    m_workerThread.quit();
    m_workerThread.wait();
}

bool TtsBackend::loadModel(const QString &modelDir)
{
    qInfo() << "TtsBackend::loadModel() called from thread:" << QThread::currentThread();
#ifdef RESONALENS_HAS_SHERPA_ONNX
    unloadModel();

    if (!QDir(modelDir).exists()) {
        qWarning() << "TTS: model directory not found:" << modelDir;
        return false;
    }

    QString espeakDir = findEspeakDataDir(modelDir);
    qInfo() << "TTS: espeak-ng-data resolved to:" << (espeakDir.isEmpty() ? "(not found)" : espeakDir);
    if (espeakDir.isEmpty()) {
        qWarning() << "TTS: espeak-ng-data not found. "
                      "Install espeak-ng (apt install espeak-ng) or rebuild the app.";
        return false;
    }

    QString modelOnnx = modelDir + "/model.onnx";
    QString voicesBin = modelDir + "/voices.bin";
    QString tokensTxt = modelDir + "/tokens.txt";

    // Keep QByteArrays alive for the duration of the SherpaOnnx config init
    QByteArray modelOnnxB  = modelOnnx.toUtf8();
    QByteArray voicesBinB  = voicesBin.toUtf8();
    QByteArray tokensTxtB  = tokensTxt.toUtf8();
    QByteArray espeakDirB  = espeakDir.toUtf8();

    SherpaOnnxOfflineTtsConfig config;
    memset(&config, 0, sizeof(config));

    config.model.kokoro.model    = modelOnnxB.constData();
    config.model.kokoro.voices   = voicesBinB.constData();
    config.model.kokoro.tokens   = tokensTxtB.constData();
    config.model.kokoro.lexicon  = "";  // kokoro-en-v0_19 has no lexicon; espeak-ng handles G2P
    config.model.kokoro.data_dir = espeakDirB.constData();
    config.model.num_threads    = 2;
    config.model.debug          = 0;
    config.max_num_sentences    = 1;

    try {
        m_tts = SherpaOnnxCreateOfflineTts(&config);
    } catch (const std::exception &ex) {
        qWarning() << "TTS: SherpaOnnxCreateOfflineTts threw:" << ex.what();
        return false;
    }

    if (!m_tts) {
        qWarning() << "TTS: failed to initialise sherpa-onnx handle";
        return false;
    }

    m_modelLoaded = true;
    qInfo() << "Kokoro TTS loaded from" << modelDir;
    return true;
#else
    Q_UNUSED(modelDir)
    qWarning() << "TTS: sherpa-onnx not compiled in (RESONALENS_HAS_SHERPA_ONNX not set)";
    return false;
#endif
}

void TtsBackend::unloadModel()
{
#ifdef RESONALENS_HAS_SHERPA_ONNX
    if (m_tts) {
        SherpaOnnxDestroyOfflineTts(m_tts);
        m_tts = nullptr;
    }
#endif
    m_modelLoaded = false;
}

bool TtsBackend::isModelLoaded() const
{
    return m_modelLoaded;
}

QStringList TtsBackend::availableVoices() const
{
    return QStringList(kVoiceMap.keys());
}

int TtsBackend::voiceToSid(const QString &voiceId)
{
    return kVoiceMap.value(voiceId, 0);
}

void TtsBackend::speak(const QString &text, const QString &voiceId, double speed)
{
    qInfo() << "TtsBackend::speak() — voice:" << voiceId;
    m_stopRequested = false;

#ifdef RESONALENS_HAS_SHERPA_ONNX
    if (!m_tts || m_stopRequested)
        return;

    const SherpaOnnxGeneratedAudio *audio = nullptr;
    try {
        audio = SherpaOnnxOfflineTtsGenerate(
            m_tts,
            text.toUtf8().constData(),
            voiceToSid(voiceId),
            static_cast<float>(speed));
    } catch (const std::exception &ex) {
        emit errorOccurred(QString("TTS synthesis error: %1").arg(ex.what()));
        return;
    }

    if (!audio || audio->n == 0) {
        if (audio) SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
        emit audioReady(QByteArray(), 0);
        return;
    }

    // Convert float → int16 PCM. NaN/Inf samples must be silenced explicitly —
    // qBound can't tame NaN (comparisons with NaN are always false) and a
    // static_cast of a non-finite float to int is UB in C++.
    QByteArray pcm(audio->n * 2, Qt::Uninitialized);
    auto *dst = reinterpret_cast<int16_t *>(pcm.data());
    for (int i = 0; i < audio->n; ++i) {
        float s = audio->samples[i];
        if (!std::isfinite(s)) s = 0.0f;
        s = qBound(-1.0f, s, 1.0f);
        dst[i] = static_cast<int16_t>(s * 32767.0f);
    }
    int sampleRate = audio->sample_rate;
    SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);

    if (!m_stopRequested)
        emit audioReady(pcm, sampleRate);
#else
    Q_UNUSED(text) Q_UNUSED(voiceId) Q_UNUSED(speed)
    qWarning() << "TTS speak called but sherpa-onnx not compiled in";
#endif
}

void TtsBackend::stop()
{
    // Atomic write — safe to call from any thread.
    // speak() checks this after synthesis and won't emit audioReady if set.
    m_stopRequested = true;
}
