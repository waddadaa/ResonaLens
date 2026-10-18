#include "WhisperBackend.h"

#include <QDebug>
#include <QFile>
#include <QMetaObject>

#ifdef RESONALENS_HAS_WHISPER
#include "whisper.h"
#endif

WhisperBackend::WhisperBackend(QObject *parent)
    : QObject(nullptr)
{
    Q_UNUSED(parent)
    this->moveToThread(&m_workerThread);
    m_workerThread.start();
}

WhisperBackend::~WhisperBackend()
{
    if (m_modelLoaded) {
        QMetaObject::invokeMethod(this, [this]() {
#ifdef RESONALENS_HAS_WHISPER
            if (m_ctx) { whisper_free(m_ctx); m_ctx = nullptr; }
#endif
            m_modelLoaded = false;
        }, Qt::BlockingQueuedConnection);
    }
    m_workerThread.quit();
    m_workerThread.wait();
}

void WhisperBackend::loadModel(const QString &modelPath)
{
    QMetaObject::invokeMethod(this, [this, modelPath]() {
        doLoadModel(modelPath);
    }, Qt::QueuedConnection);
}

void WhisperBackend::unloadModel()
{
    if (!m_modelLoaded) return;
    QMetaObject::invokeMethod(this, [this]() {
#ifdef RESONALENS_HAS_WHISPER
        if (m_ctx) { whisper_free(m_ctx); m_ctx = nullptr; }
#endif
        m_modelLoaded = false;
    }, Qt::QueuedConnection);
}

bool WhisperBackend::isModelLoaded() const
{
    return m_modelLoaded;
}

bool WhisperBackend::doLoadModel(const QString &modelPath)
{
#ifdef RESONALENS_HAS_WHISPER
    if (m_ctx) { whisper_free(m_ctx); m_ctx = nullptr; }
    m_modelLoaded = false;

    qInfo() << "Loading Whisper model:" << modelPath;

    whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true;
    cparams.flash_attn = true;

    m_ctx = whisper_init_from_file_with_params(modelPath.toUtf8().constData(), cparams);
    if (!m_ctx) {
        emit errorOccurred("Failed to load Whisper model: " + modelPath);
        return false;
    }

    m_modelLoaded = true;
    qInfo() << "Whisper model loaded —" << whisper_model_type_readable(m_ctx);
    emit modelLoaded();
    return true;
#else
    Q_UNUSED(modelPath)
    emit errorOccurred("whisper.cpp not compiled in");
    return false;
#endif
}

void WhisperBackend::transcribe(const QString &audioPath)
{
    m_stopRequested = false;
    QMetaObject::invokeMethod(this, [this, audioPath]() {
        doTranscribe(audioPath);
    }, Qt::QueuedConnection);
}

void WhisperBackend::stop()
{
    m_stopRequested = true;
}

void WhisperBackend::doTranscribe(const QString &audioPath)
{
    if (!m_modelLoaded) {
        emit errorOccurred("Whisper model not loaded");
        return;
    }

#ifdef RESONALENS_HAS_WHISPER
    // Read WAV file: skip 44-byte header, convert Int16 PCM → float32
    QFile file(audioPath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit errorOccurred("Cannot open audio file: " + audioPath);
        return;
    }

    QByteArray raw = file.readAll();
    file.close();

    if (raw.size() < 44) {
        emit errorOccurred("Audio file too small");
        return;
    }

    const int16_t *pcm16 = reinterpret_cast<const int16_t *>(raw.constData() + 44);
    int nSamples = (raw.size() - 44) / sizeof(int16_t);

    std::vector<float> pcmf32(nSamples);
    for (int i = 0; i < nSamples; i++) {
        pcmf32[i] = static_cast<float>(pcm16[i]) / 32768.0f;
    }

    // Configure whisper inference
    whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.n_threads        = 4;
    wparams.no_timestamps    = true;
    wparams.single_segment   = false;
    wparams.print_special    = false;
    wparams.print_progress   = false;
    wparams.print_realtime   = false;
    wparams.print_timestamps = false;
    wparams.language         = "auto";
    wparams.translate        = false;
    wparams.suppress_blank   = true;
    wparams.suppress_nst     = true;

    // Abort callback for stop support
    wparams.abort_callback = [](void *user_data) -> bool {
        auto *stopped = static_cast<std::atomic<bool> *>(user_data);
        return stopped->load();
    };
    wparams.abort_callback_user_data = &m_stopRequested;

    // Run full inference: PCM → mel → encoder → decoder → text
    int result = whisper_full(m_ctx, wparams, pcmf32.data(), static_cast<int>(pcmf32.size()));
    if (result != 0) {
        if (m_stopRequested) {
            qInfo() << "Transcription stopped by user";
        } else {
            emit errorOccurred("Whisper inference failed");
        }
        return;
    }

    // Collect all segments into one string
    QString transcription;
    int nSegments = whisper_full_n_segments(m_ctx);
    for (int i = 0; i < nSegments; i++) {
        const char *text = whisper_full_get_segment_text(m_ctx, i);
        if (text) transcription += QString::fromUtf8(text);
    }

    emit transcriptionReady(transcription.trimmed());

#else
    Q_UNUSED(audioPath)
    emit errorOccurred("whisper.cpp not compiled in");
#endif
}
