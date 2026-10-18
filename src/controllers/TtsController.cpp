#include "TtsController.h"
#include "core/TtsBackend.h"
#include "core/StreamingPcmDevice.h"
#include "network/ModelDownloader.h"

#include <QAudioFormat>
#include <QAudioSink>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QMediaDevices>
#include <QStandardPaths>

// ── Kokoro en-v0.19 in sherpa-onnx format ─────────────────────────────────
static const char *kKokoroRepo = "csukuangfj/kokoro-en-v0_19";

struct ModelFile {
    const char *remote;
    const char *local;
};

static const ModelFile kModelFiles[] = {
    {"model.onnx",                       "model.onnx"},
    {"voices.bin",                       "voices.bin"},
    {"tokens.txt",                       "tokens.txt"},
    {"espeak-ng-data/phontab",           "espeak-ng-data/phontab"},
    {"espeak-ng-data/phonindex",         "espeak-ng-data/phonindex"},
    {"espeak-ng-data/phondata",          "espeak-ng-data/phondata"},
    {"espeak-ng-data/intonations",       "espeak-ng-data/intonations"},
    {"espeak-ng-data/en_dict",           "espeak-ng-data/en_dict"},
};
static const int kModelFileCount = static_cast<int>(sizeof(kModelFiles) / sizeof(kModelFiles[0]));

// ──────────────────────────────────────────────────────────────────────────

TtsController::TtsController(QObject *parent)
    : QObject(parent)
    , m_ttsBackend(new TtsBackend(this))
    , m_downloader(new ModelDownloader(this))
    , m_pcmDevice(new StreamingPcmDevice(this))
{
    // TtsBackend::speak runs on its worker thread.
    connect(this, &TtsController::speakRequested,
            m_ttsBackend, &TtsBackend::speak,
            Qt::QueuedConnection);

    // When a chunk is synthesized, append it to the streaming device and
    // immediately start synthesizing the next chunk.
    connect(m_ttsBackend, &TtsBackend::audioReady,
            this, &TtsController::onAudioReady,
            Qt::QueuedConnection);

    connect(m_ttsBackend, &TtsBackend::errorOccurred, this, [this](const QString &err) {
        m_synthesizing = false;
        m_isSpeaking = false;
        emit isSpeakingChanged();
        emit errorOccurred(err);
    });

    // When all audio has been played after finish()
    connect(m_pcmDevice, &StreamingPcmDevice::fullyConsumed, this, [this]() {
        stopAudioSink();
        m_isSpeaking = false;
        emit isSpeakingChanged();
        emit speakingFinished();
    }, Qt::QueuedConnection);

    // ── Download wiring ──
    connect(m_downloader, &ModelDownloader::progressChanged,
            this, [this](double percent, double speedMBps, qint64 received, qint64 total) {
        double fileOffset  = static_cast<double>(m_downloadFileIndex) / kModelFileCount;
        double fileContrib = percent / 100.0 / kModelFileCount;
        m_modelDownloadProgress = (fileOffset + fileContrib) * 100.0;

        QString recv = total > 1024LL*1024*1024
            ? QString::number(received / (1024.0*1024*1024), 'f', 1) + " GB"
            : QString::number(received / (1024.0*1024), 'f', 0) + " MB";
        QString tot = total > 1024LL*1024*1024
            ? QString::number(total / (1024.0*1024*1024), 'f', 1) + " GB"
            : QString::number(total / (1024.0*1024), 'f', 0) + " MB";
        m_modelDownloadStatus = QString("File %1/%2 · %3% · %4 MB/s · %5 / %6")
            .arg(m_downloadFileIndex + 1)
            .arg(kModelFileCount)
            .arg(qRound(percent))
            .arg(speedMBps, 0, 'f', 1)
            .arg(recv)
            .arg(tot);
        emit downloadStateChanged();
    });

    connect(m_downloader, &ModelDownloader::downloadFinished,
            this, &TtsController::onDownloadFinished);

    connect(m_downloader, &ModelDownloader::downloadError,
            this, [this](const QString &error) {
        m_isDownloadingModel = false;
        m_downloadFileIndex  = 0;
        m_modelDownloadProgress = 0.0;
        m_modelDownloadStatus.clear();
        emit downloadStateChanged();
        emit errorOccurred("TTS download failed: " + error);
    });

    // Check if all model files are already on disk
    if (checkModelInstalled()) {
        if (m_ttsBackend->loadModel(modelDir())) {
            m_ttsAvailable = true;
            m_availableVoices = m_ttsBackend->availableVoices();
            emit availableVoicesChanged();
        } else {
            qWarning() << "TTS: model files present but loadModel() failed — TTS disabled";
        }
    }
}

TtsController::~TtsController() = default;

// ── Property accessors ────────────────────────────────────────────────────

bool TtsController::ttsAvailable() const        { return m_ttsAvailable; }
bool TtsController::isSpeaking() const          { return m_isSpeaking; }
QStringList TtsController::availableVoices() const { return m_availableVoices; }
QString TtsController::activeVoice() const      { return m_activeVoice; }
double TtsController::speed() const             { return m_speed; }
bool TtsController::isDownloadingModel() const  { return m_isDownloadingModel; }
double TtsController::modelDownloadProgress() const { return m_modelDownloadProgress; }
QString TtsController::modelDownloadStatus() const  { return m_modelDownloadStatus; }

// ── Slots ─────────────────────────────────────────────────────────────────

void TtsController::speak(const QString &text)
{
    if (!m_ttsAvailable || text.isEmpty())
        return;

    m_sentenceQueue.enqueue(text);

    // If the TTS worker is idle, start synthesizing the next chunk.
    if (!m_synthesizing)
        synthesizeNext();
}

void TtsController::setGenerationActive(bool active)
{
    bool wasActive = m_generationActive;
    m_generationActive = active;

    if (wasActive && !active) {
        // Generation finished. If nothing is queued or synthesizing,
        // tell the streaming device no more audio is coming.
        if (m_sentenceQueue.isEmpty() && !m_synthesizing) {
            m_pcmDevice->finish();
        }
    }
}

void TtsController::stop()
{
    m_sentenceQueue.clear();
    m_synthesizing = false;
    m_generationActive = false;
    m_ttsBackend->stop();
    stopAudioSink();
    m_isSpeaking = false;
    emit isSpeakingChanged();
}

void TtsController::setVoice(const QString &voiceId)
{
    if (m_activeVoice != voiceId) {
        m_activeVoice = voiceId;
        emit activeVoiceChanged();
    }
}

void TtsController::setSpeed(double speed)
{
    if (!qFuzzyCompare(m_speed, speed)) {
        m_speed = speed;
        emit speedChanged();
    }
}

void TtsController::downloadModel()
{
    if (m_isDownloadingModel || m_ttsAvailable)
        return;

    QDir().mkpath(modelDir());
    m_isDownloadingModel = true;
    m_downloadFileIndex  = 0;
    m_modelDownloadProgress = 0.0;
    m_modelDownloadStatus = "Starting download...";
    emit downloadStateChanged();

    startNextFileDownload();
}

void TtsController::cancelDownload()
{
    m_downloader->cancel();
    m_isDownloadingModel = false;
    m_downloadFileIndex  = 0;
    m_modelDownloadProgress = 0.0;
    m_modelDownloadStatus.clear();
    emit downloadStateChanged();
}

// ── Streaming audio pipeline ─────────────────────────────────────────────

void TtsController::synthesizeNext()
{
    if (m_sentenceQueue.isEmpty()) {
        m_synthesizing = false;
        // If generation is done and nothing left to synthesize, signal EOF
        if (!m_generationActive && m_pcmDevice->isOpen())
            m_pcmDevice->finish();
        return;
    }

    QString sentence = m_sentenceQueue.dequeue();
    m_synthesizing = true;
    emit speakRequested(sentence, m_activeVoice, m_speed);
}

void TtsController::onAudioReady(const QByteArray &pcm, int sampleRate)
{
    if (pcm.isEmpty()) {
        m_synthesizing = false;
        synthesizeNext();
        return;
    }

    // Ensure the audio sink is running (created on first chunk)
    ensureAudioSink(sampleRate);

    // Append PCM to the streaming device — QAudioSink picks it up seamlessly
    m_pcmDevice->appendAudio(pcm);

    if (!m_isSpeaking) {
        m_isSpeaking = true;
        emit isSpeakingChanged();
    }

    // Immediately start synthesizing the next chunk — pipeline concurrency
    m_synthesizing = false;
    synthesizeNext();
}

void TtsController::ensureAudioSink(int sampleRate)
{
    if (m_audioSink)
        return;  // already running

    QAudioDevice dev = QMediaDevices::defaultAudioOutput();
    if (dev.isNull()) {
        qWarning() << "TTS: no audio output device";
        return;
    }

    QAudioFormat fmt;
    fmt.setSampleRate(sampleRate);
    fmt.setChannelCount(1);
    fmt.setSampleFormat(QAudioFormat::Int16);

    // Reset the streaming device for a fresh generation. If it won't open
    // we must not hand a closed device to QAudioSink — start() would then
    // immediately enter the IdleState and we'd silently play no audio.
    m_pcmDevice->resetStream();
    if (!m_pcmDevice->open(QIODevice::ReadOnly)) {
        qWarning() << "TTS: failed to open PCM streaming device";
        return;
    }

    m_audioSink = new QAudioSink(dev, fmt, this);
    m_audioSink->start(m_pcmDevice);
    if (m_audioSink->error() != QAudio::NoError) {
        qWarning() << "TTS: audio sink start failed:" << m_audioSink->error();
        m_audioSink->deleteLater();
        m_audioSink = nullptr;
        m_pcmDevice->close();
        return;
    }
    qInfo() << "TTS: streaming sink started, sampleRate:" << sampleRate;
}

void TtsController::stopAudioSink()
{
    if (m_audioSink) {
        QAudioSink *sink = m_audioSink;
        m_audioSink = nullptr;
        sink->stop();
        sink->deleteLater();
    }
    if (m_pcmDevice->isOpen())
        m_pcmDevice->close();
}

// ── Private helpers ───────────────────────────────────────────────────────

QString TtsController::modelDir() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + "/models/kokoro";
}

bool TtsController::checkModelInstalled() const
{
    const QString dir = modelDir();
    for (int i = 0; i < kModelFileCount; ++i) {
        if (!QFileInfo::exists(dir + "/" + kModelFiles[i].local))
            return false;
    }
    return true;
}

void TtsController::startNextFileDownload()
{
    if (m_downloadFileIndex >= kModelFileCount)
        return;

    const ModelFile &f = kModelFiles[m_downloadFileIndex];
    QString dest = modelDir() + "/" + f.local;
    QDir().mkpath(QFileInfo(dest).absolutePath());
    m_downloader->download(kKokoroRepo, f.remote, dest);
}

void TtsController::onDownloadFinished(const QString &filePath)
{
    Q_UNUSED(filePath)
    m_downloadFileIndex++;

    if (m_downloadFileIndex < kModelFileCount) {
        startNextFileDownload();
        return;
    }

    m_isDownloadingModel = false;
    m_modelDownloadProgress = 100.0;
    m_modelDownloadStatus.clear();

    if (checkModelInstalled()) {
        if (m_ttsBackend->loadModel(modelDir())) {
            m_ttsAvailable = true;
            m_availableVoices = m_ttsBackend->availableVoices();
            emit availableVoicesChanged();
            emit ttsAvailableChanged();
        } else {
            qWarning() << "TTS: download complete but loadModel() failed";
        }
    }

    emit downloadStateChanged();
}
