#include "AudioController.h"
#include "core/WhisperBackend.h"
#include "network/ModelDownloader.h"

#include <QDebug>
#include <QDir>
#include <QTimer>
#include <QStandardPaths>
#include <QAudioSource>
#include <QMediaDevices>
#include <QAudioDevice>
#include <QFile>

// ── Whisper Large v3 Turbo (quantized Q5_0) ─────────────────────────────
// https://huggingface.co/ggerganov/whisper.cpp
// Single file download into {AppDataLocation}/models/whisper/
// ─────────────────────────────────────────────────────────────────────────
static const char *kWhisperRepo     = "ggerganov/whisper.cpp";
static const char *kWhisperFile     = "ggml-large-v3-turbo-q5_0.bin";
static const char *kWhisperLocalDir = "whisper";

AudioController::AudioController(QObject *parent)
    : QObject(parent)
    , m_whisperBackend(new WhisperBackend(this))
    , m_downloader(new ModelDownloader(this))
{
    connect(m_whisperBackend, &WhisperBackend::transcriptionReady,
            this, &AudioController::transcriptionReady);
    connect(m_whisperBackend, &WhisperBackend::transcriptionReady,
            this, [this]() {
        m_isTranscribing = false;
        emit isTranscribingChanged();
    });
    connect(m_whisperBackend, &WhisperBackend::errorOccurred,
            this, [this](const QString &err) {
        qWarning() << "STT error:" << err;
        m_isTranscribing = false;
        emit isTranscribingChanged();
    });

    // Download signals
    connect(m_downloader, &ModelDownloader::progressChanged,
            this, [this](double percent, double speedMBps, qint64 received, qint64 total) {
        m_sttDownloadProgress = percent;
        QString recv = QString::number(received / (1024.0 * 1024), 'f', 0) + " MB";
        QString tot  = QString::number(total / (1024.0 * 1024), 'f', 0) + " MB";
        m_sttDownloadStatus = QString("%1% · %2 MB/s · %3 / %4")
            .arg(static_cast<int>(percent))
            .arg(speedMBps, 0, 'f', 1)
            .arg(recv, tot);
        emit sttDownloadStateChanged();
    });
    connect(m_downloader, &ModelDownloader::downloadFinished,
            this, [this](const QString &filePath) {
        Q_UNUSED(filePath)
        m_isDownloadingSttModel = false;
        m_sttDownloadProgress = 100.0;
        m_sttDownloadStatus.clear();
        m_sttModelInstalled = true;
        emit sttDownloadStateChanged();
        emit sttModelInstalledChanged();
        loadSttModelIfNeeded();
    });
    connect(m_downloader, &ModelDownloader::downloadError,
            this, [this](const QString &err) {
        qWarning() << "STT model download failed:" << err;
        m_isDownloadingSttModel = false;
        m_sttDownloadStatus = "Download failed";
        emit sttDownloadStateChanged();
    });

    m_durationTimer = new QTimer(this);
    m_durationTimer->setInterval(1000);
    connect(m_durationTimer, &QTimer::timeout, this, [this]() {
        m_recordingDuration++;
        emit recordingDurationChanged();
    });

    // Check if model already installed
    m_sttModelInstalled = checkSttModelInstalled();
    if (m_sttModelInstalled)
        loadSttModelIfNeeded();
}

AudioController::~AudioController() = default;

bool AudioController::isRecording() const { return m_isRecording; }
int AudioController::recordingDuration() const { return m_recordingDuration; }
bool AudioController::isTranscribing() const { return m_isTranscribing; }
QString AudioController::lastRecordingPath() const { return m_lastRecordingPath; }
bool AudioController::sttModelInstalled() const { return m_sttModelInstalled; }
bool AudioController::isDownloadingSttModel() const { return m_isDownloadingSttModel; }
double AudioController::sttDownloadProgress() const { return m_sttDownloadProgress; }
QString AudioController::sttDownloadStatus() const { return m_sttDownloadStatus; }

QString AudioController::sttModelDir() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + "/models/" + kWhisperLocalDir;
}

QString AudioController::sttModelPath() const
{
    return sttModelDir() + "/" + kWhisperFile;
}

bool AudioController::checkSttModelInstalled() const
{
    return QFile::exists(sttModelPath());
}

void AudioController::loadSttModelIfNeeded()
{
    if (!m_sttModelInstalled || m_whisperBackend->isModelLoaded())
        return;
    m_whisperBackend->loadModel(sttModelPath());
}

void AudioController::downloadSttModel()
{
    if (m_isDownloadingSttModel) return;

    QDir().mkpath(sttModelDir());

    m_isDownloadingSttModel = true;
    m_sttDownloadProgress = 0.0;
    m_sttDownloadStatus = "Starting download...";
    emit sttDownloadStateChanged();

    m_downloader->download(kWhisperRepo, kWhisperFile, sttModelPath());
}

void AudioController::cancelSttDownload()
{
    m_downloader->cancel();
    m_isDownloadingSttModel = false;
    m_sttDownloadStatus.clear();
    emit sttDownloadStateChanged();
}

void AudioController::startRecording()
{
    if (m_isRecording)
        return;

    // 16kHz mono 16-bit PCM — optimal for whisper.cpp
    QAudioFormat format;
    format.setSampleRate(16000);
    format.setChannelCount(1);
    format.setSampleFormat(QAudioFormat::Int16);

    QAudioDevice inputDevice = QMediaDevices::defaultAudioInput();
    if (inputDevice.isNull()) {
        qWarning() << "No audio input device found";
        return;
    }
    if (!inputDevice.isFormatSupported(format)) {
        format = inputDevice.preferredFormat();
        qWarning() << "16kHz/mono not supported, falling back to preferred format";
    }

    QString filePath = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                       + "/resonalens_recording.wav";

    // Use deleteLater so any pending signals from the previous QFile/QAudioSource
    // drain safely before the object is freed.
    if (m_recordingFile) { m_recordingFile->deleteLater(); m_recordingFile = nullptr; }
    m_recordingFile = new QFile(filePath, this);
    if (!m_recordingFile->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "Cannot open recording file:" << filePath;
        m_recordingFile->deleteLater();
        m_recordingFile = nullptr;
        return;
    }

    writeWavHeader(m_recordingFile, format);

    if (m_audioSource) { m_audioSource->deleteLater(); m_audioSource = nullptr; }
    m_audioSource = new QAudioSource(inputDevice, format, this);
    m_audioSource->start(m_recordingFile);

    m_lastRecordingPath = filePath;
    m_isRecording = true;
    m_recordingDuration = 0;
    emit isRecordingChanged();
    emit recordingDurationChanged();
    emit lastRecordingPathChanged();
    m_durationTimer->start();

    qInfo() << "Recording started:" << filePath;
}

void AudioController::stopRecording()
{
    if (!m_isRecording)
        return;

    m_durationTimer->stop();

    if (m_audioSource) {
        m_audioSource->stop();
        m_audioSource->deleteLater();
        m_audioSource = nullptr;
    }

    if (m_recordingFile) {
        finalizeWavHeader(m_recordingFile);
        m_recordingFile->close();
        m_recordingFile->deleteLater();
        m_recordingFile = nullptr;
    }

    m_isRecording = false;
    emit isRecordingChanged();
    qInfo() << "Recording stopped:" << m_lastRecordingPath;
}

void AudioController::transcribeLastRecording()
{
    if (m_lastRecordingPath.isEmpty()) {
        qWarning() << "No recording to transcribe";
        return;
    }

    if (!m_sttModelInstalled) {
        emit sttModelRequired();
        return;
    }

    loadSttModelIfNeeded();
    transcribe(m_lastRecordingPath);
}

void AudioController::transcribe(const QString &filePath)
{
    if (!m_sttModelInstalled) {
        emit sttModelRequired();
        return;
    }

    m_isTranscribing = true;
    emit isTranscribingChanged();
    m_whisperBackend->transcribe(filePath);
}

void AudioController::writeWavHeader(QFile *file, const QAudioFormat &format)
{
    if (!file) {
        qWarning() << "writeWavHeader called with null file";
        return;
    }
    const quint32 zero       = 0;
    const quint32 fmtSize    = 16;
    const quint16 pcmFormat  = 1;
    const quint16 channels   = static_cast<quint16>(format.channelCount());
    const quint32 sampleRate = static_cast<quint32>(format.sampleRate());
    const quint16 bytesPerSample = static_cast<quint16>(format.bytesPerSample());
    const quint16 bitsPerSample  = bytesPerSample * 8;
    const quint16 blockAlign     = channels * bytesPerSample;
    const quint32 byteRate       = sampleRate * blockAlign;

    file->write("RIFF");
    file->write(reinterpret_cast<const char*>(&zero),        4);
    file->write("WAVE");
    file->write("fmt ");
    file->write(reinterpret_cast<const char*>(&fmtSize),     4);
    file->write(reinterpret_cast<const char*>(&pcmFormat),   2);
    file->write(reinterpret_cast<const char*>(&channels),    2);
    file->write(reinterpret_cast<const char*>(&sampleRate),  4);
    file->write(reinterpret_cast<const char*>(&byteRate),    4);
    file->write(reinterpret_cast<const char*>(&blockAlign),  2);
    file->write(reinterpret_cast<const char*>(&bitsPerSample), 2);
    file->write("data");
    file->write(reinterpret_cast<const char*>(&zero),        4);
}

void AudioController::finalizeWavHeader(QFile *file)
{
    if (!file) {
        qWarning() << "finalizeWavHeader called with null file";
        return;
    }
    const qint64 total = file->size();
    if (total < 44) {
        // No audio was written — the 44-byte RIFF header is the minimum.
        // Zero the size fields rather than producing negative values that
        // wrap around after the unsigned cast below.
        const quint32 zero = 0;
        if (file->seek(4)) file->write(reinterpret_cast<const char*>(&zero), 4);
        if (file->seek(40)) file->write(reinterpret_cast<const char*>(&zero), 4);
        return;
    }
    const quint32 dataSize = static_cast<quint32>(total - 44);
    const quint32 riffSize = static_cast<quint32>(total - 8);

    file->seek(4);
    file->write(reinterpret_cast<const char*>(&riffSize), 4);
    file->seek(40);
    file->write(reinterpret_cast<const char*>(&dataSize), 4);
}
