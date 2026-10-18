#pragma once

#include <QObject>
#include <QString>
#include <QAudioFormat>

class WhisperBackend;
class ModelDownloader;
class QAudioSource;
class QFile;
class QTimer;

class AudioController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool isRecording READ isRecording NOTIFY isRecordingChanged)
    Q_PROPERTY(int recordingDuration READ recordingDuration NOTIFY recordingDurationChanged)
    Q_PROPERTY(bool isTranscribing READ isTranscribing NOTIFY isTranscribingChanged)
    Q_PROPERTY(QString lastRecordingPath READ lastRecordingPath NOTIFY lastRecordingPathChanged)
    Q_PROPERTY(bool sttModelInstalled READ sttModelInstalled NOTIFY sttModelInstalledChanged)
    Q_PROPERTY(bool isDownloadingSttModel READ isDownloadingSttModel NOTIFY sttDownloadStateChanged)
    Q_PROPERTY(double sttDownloadProgress READ sttDownloadProgress NOTIFY sttDownloadStateChanged)
    Q_PROPERTY(QString sttDownloadStatus READ sttDownloadStatus NOTIFY sttDownloadStateChanged)

public:
    explicit AudioController(QObject *parent = nullptr);
    ~AudioController();

    bool isRecording() const;
    int recordingDuration() const;
    bool isTranscribing() const;
    QString lastRecordingPath() const;
    bool sttModelInstalled() const;
    bool isDownloadingSttModel() const;
    double sttDownloadProgress() const;
    QString sttDownloadStatus() const;

public slots:
    void startRecording();
    void stopRecording();
    void transcribe(const QString &filePath);
    void transcribeLastRecording();
    void downloadSttModel();
    void cancelSttDownload();

signals:
    void transcriptionReady(const QString &text);
    void recordingLevelChanged(float level);
    void isRecordingChanged();
    void recordingDurationChanged();
    void isTranscribingChanged();
    void lastRecordingPathChanged();
    void sttModelInstalledChanged();
    void sttDownloadStateChanged();
    void sttModelRequired();

private:
    void writeWavHeader(QFile *file, const QAudioFormat &format);
    void finalizeWavHeader(QFile *file);
    bool checkSttModelInstalled() const;
    QString sttModelPath() const;
    QString sttModelDir() const;
    void loadSttModelIfNeeded();

    bool m_isRecording = false;
    int m_recordingDuration = 0;
    bool m_isTranscribing = false;
    QString m_lastRecordingPath;
    bool m_sttModelInstalled = false;
    bool m_isDownloadingSttModel = false;
    double m_sttDownloadProgress = 0.0;
    QString m_sttDownloadStatus;

    WhisperBackend *m_whisperBackend = nullptr;
    ModelDownloader *m_downloader = nullptr;
    QAudioSource *m_audioSource = nullptr;
    QFile *m_recordingFile = nullptr;
    QTimer *m_durationTimer = nullptr;
};
