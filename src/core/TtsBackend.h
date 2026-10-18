#pragma once

#include <QByteArray>
#include <QObject>
#include <QThread>
#include <QStringList>
#include <QString>
#include <atomic>

#ifdef RESONALENS_HAS_SHERPA_ONNX
#include "sherpa-onnx/c-api/c-api.h"
#endif

class TtsBackend : public QObject {
    Q_OBJECT

public:
    explicit TtsBackend(QObject *parent = nullptr);
    ~TtsBackend();

    // modelDir must contain: model.onnx, voices.bin, tokens.txt
    // espeak-ng-data is located automatically (build tree or system install).
    bool loadModel(const QString &modelDir);
    void unloadModel();
    bool isModelLoaded() const;
    QStringList availableVoices() const;

public slots:
    void speak(const QString &text, const QString &voiceId, double speed);
    void stop();

signals:
    void audioReady(const QByteArray &pcm, int sampleRate);
    void errorOccurred(const QString &error);

private:
    static int voiceToSid(const QString &voiceId);

    QThread m_workerThread;
    bool m_modelLoaded = false;
    std::atomic<bool> m_stopRequested{false};

#ifdef RESONALENS_HAS_SHERPA_ONNX
    const SherpaOnnxOfflineTts *m_tts = nullptr;
#else
    void *m_tts = nullptr;
#endif
};
