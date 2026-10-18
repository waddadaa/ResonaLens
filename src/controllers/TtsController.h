#pragma once

#include <QObject>
#include <QStringList>
#include <QString>
#include <QByteArray>
#include <QQueue>

class TtsBackend;
class ModelDownloader;
class QAudioSink;
class StreamingPcmDevice;

// Streaming TTS controller — concurrent pipeline architecture.
//
// LLM tokens → ChatController sentence buffer → TtsController queue
//                                                    ↓
//                                         TtsBackend worker (synthesize)
//                                                    ↓
//                                         StreamingPcmDevice (append PCM)
//                                                    ↓
//                                         QAudioSink (continuous playback)
//
// One QAudioSink + StreamingPcmDevice per generation session.
// TTS worker synthesizes chunks and appends audio; QAudioSink reads
// continuously — no gaps between sentences.
class TtsController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool ttsAvailable READ ttsAvailable NOTIFY ttsAvailableChanged)
    Q_PROPERTY(bool isSpeaking READ isSpeaking NOTIFY isSpeakingChanged)
    Q_PROPERTY(QStringList availableVoices READ availableVoices NOTIFY availableVoicesChanged)
    Q_PROPERTY(QString activeVoice READ activeVoice NOTIFY activeVoiceChanged)
    Q_PROPERTY(double speed READ speed NOTIFY speedChanged)
    Q_PROPERTY(bool isDownloadingModel READ isDownloadingModel NOTIFY downloadStateChanged)
    Q_PROPERTY(double modelDownloadProgress READ modelDownloadProgress NOTIFY downloadStateChanged)
    Q_PROPERTY(QString modelDownloadStatus READ modelDownloadStatus NOTIFY downloadStateChanged)

public:
    explicit TtsController(QObject *parent = nullptr);
    ~TtsController();

    bool ttsAvailable() const;
    bool isSpeaking() const;
    QStringList availableVoices() const;
    QString activeVoice() const;
    double speed() const;
    bool isDownloadingModel() const;
    double modelDownloadProgress() const;
    QString modelDownloadStatus() const;

public slots:
    void speak(const QString &text);
    void stop();
    void setVoice(const QString &voiceId);
    void setSpeed(double speed);
    void downloadModel();
    void cancelDownload();
    void setGenerationActive(bool active);

signals:
    void ttsAvailableChanged();
    void isSpeakingChanged();
    void availableVoicesChanged();
    void activeVoiceChanged();
    void speedChanged();
    void speakingFinished();
    void errorOccurred(const QString &error);
    void downloadStateChanged();

signals:
    // Internal — queued across threads to TtsBackend
    void speakRequested(const QString &text, const QString &voiceId, double speed);

private:
    void onDownloadFinished(const QString &filePath);
    void startNextFileDownload();
    bool checkModelInstalled() const;
    QString modelDir() const;

    // Streaming audio pipeline
    void onAudioReady(const QByteArray &pcm, int sampleRate);
    void ensureAudioSink(int sampleRate);
    void stopAudioSink();
    void synthesizeNext();

    bool m_ttsAvailable = false;
    bool m_isSpeaking = false;
    bool m_isDownloadingModel = false;
    double m_modelDownloadProgress = 0.0;
    QString m_modelDownloadStatus;
    QStringList m_availableVoices;
    QString m_activeVoice = "af_heart";
    double m_speed = 1.0;
    int m_downloadFileIndex = 0;
    TtsBackend *m_ttsBackend = nullptr;
    ModelDownloader *m_downloader = nullptr;

    // Streaming audio pipeline — one sink per generation
    QAudioSink *m_audioSink = nullptr;
    StreamingPcmDevice *m_pcmDevice = nullptr;
    QQueue<QString> m_sentenceQueue;
    bool m_synthesizing = false;  // TTS worker is busy

    // LLM generation state
    bool m_generationActive = false;
};
