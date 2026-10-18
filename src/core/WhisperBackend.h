#pragma once

#include <QObject>
#include <QThread>
#include <QString>
#include <atomic>

#ifdef RESONALENS_HAS_WHISPER
struct whisper_context;
#endif

class WhisperBackend : public QObject {
    Q_OBJECT

public:
    explicit WhisperBackend(QObject *parent = nullptr);
    ~WhisperBackend();

    void loadModel(const QString &modelPath);
    void unloadModel();
    bool isModelLoaded() const;

public slots:
    void transcribe(const QString &audioPath);
    void stop();

signals:
    void modelLoaded();
    void transcriptionReady(const QString &text);
    void errorOccurred(const QString &error);

private:
    bool doLoadModel(const QString &modelPath);
    void doTranscribe(const QString &audioPath);

    QThread m_workerThread;
    std::atomic<bool> m_stopRequested{false};
    bool m_modelLoaded = false;

#ifdef RESONALENS_HAS_WHISPER
    whisper_context *m_ctx = nullptr;
#endif
};
