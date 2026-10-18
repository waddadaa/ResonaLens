#pragma once

#include <QObject>
#include <QThread>
#include <QString>
#include <atomic>

#ifdef RESONALENS_HAS_LLAMA
#include "llama.h"
#endif

class LlamaBackend : public QObject {
    Q_OBJECT

public:
    explicit LlamaBackend(QObject *parent = nullptr);
    ~LlamaBackend();

    void loadModel(const QString &ggufPath);
    void unloadModel();
    bool isModelLoaded() const;

    // Set generation parameters (read from SettingsController before each generation)
    void setGenerationParams(double temperature, double topP, int maxTokens);

public slots:
    void generate(const QString &prompt);
    void stop();

    /// Silent synchronous inference — no signals emitted, returns full response string.
    /// Call only from the main thread when the worker thread is idle (i.e. after generation completes).
    QString generateSync(const QString &prompt, int maxTokens = 1024);

signals:
    void modelLoaded(const QString &modelName);
    void modelUnloaded();
    void tokenGenerated(const QString &token);
    void generationComplete();
    void errorOccurred(const QString &error);

private:
    bool doLoadModel(const QString &ggufPath);
    void doGenerate(const QString &prompt);

    QThread m_workerThread;
    std::atomic<bool> m_stopRequested{false};
    bool m_modelLoaded = false;

    // Generation parameters (synced from SettingsController)
    float m_temperature = 0.7f;
    float m_topP = 0.9f;
    int m_maxGenTokens = 2048;

#ifdef RESONALENS_HAS_LLAMA
    llama_model *m_model = nullptr;
    llama_context *m_context = nullptr;
    const llama_vocab *m_vocab = nullptr;
#endif
};
