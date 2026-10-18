#pragma once

#include <QObject>
#include <QThread>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <atomic>

#ifdef RESONALENS_HAS_LITERT
// Forward declarations — actual headers included in .cpp
namespace litert { namespace lm { class Engine; class Conversation; } }
#else
class QProcess;
#endif

// LiteRT-LM backend with full C++ API integration
// Supports: text chat, multimodal (image/audio), tool calling
// Model format: .litertlm from litert-community / google on HuggingFace
class LiteRTBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString accelerator READ accelerator NOTIFY acceleratorChanged)

public:
    explicit LiteRTBackend(QObject *parent = nullptr);
    ~LiteRTBackend();

    bool loadModel(const QString &modelPath);
    void unloadModel();
    bool isModelLoaded() const;

    static bool isLiteRTModel(const QString &path);
    static QString findBinary();

    // Tool definitions (JSON array of function schemas)
    void setToolDefinitions(const QString &toolsJson);

    // Auto-detect best accelerator: tries NPU → GPU → CPU.
    // Call before loadModel(). The detected backend is used for engine creation.
    void autoDetectAccelerator();
    QString accelerator() const;

    // Reset the conversation context (e.g. on new chat)
    void resetConversation();

    /// Synchronous generation — blocks until complete, returns full response.
    /// Used for summarization passes during web search.
    QString generateSync(const QString &prompt, int maxTokens = 512);

public slots:
    void generate(const QString &prompt);
    void generateWithImage(const QString &prompt, const QString &imagePath);
    void generateWithAudio(const QString &prompt, const QString &audioPath);
    void stop();

signals:
    void modelLoaded(const QString &modelName);
    void modelUnloaded();
    void tokenGenerated(const QString &token);
    void generationComplete();
    void errorOccurred(const QString &error);
    void acceleratorChanged();
    // Tool calling: model wants to call a tool
    void toolCallRequested(const QString &toolName, const QVariantMap &arguments);
    // When the full response is ready (after tool results are processed)
    void responseReady(const QString &fullResponse);

public slots:
    // Called by ChatController after executing the tool
    void sendToolResult(const QString &toolName, const QVariantMap &result);

private:
    void doGenerate(const QString &userMessage, const QString &imagePath = "",
                    const QString &audioPath = "");
    void doGenerateWithCLI(const QString &userMessage, const QString &imagePath = "");

    // CLI persistent process management
    bool startPersistentProcess();
    void stopPersistentProcess();
    bool isPersistentProcessRunning() const;

    // NPU detection helpers
    static bool isNpuAvailable();

    QThread m_workerThread;
    std::atomic<bool> m_stopRequested{false};
    bool m_modelLoaded = false;
    QString m_modelPath;
    QString m_binaryPath;
    QString m_toolsJson;
    QString m_accelerator = "gpu";  // auto-detected: npu, gpu, or cpu

    // CLI echo/noise detection
    bool m_echoFinished = false;
    QString m_lastPromptSent;
    QString m_echoBuffer;

    // Turn tracking
    int m_turnCount = 0;
    bool m_waitingForResponse = false;

#ifdef RESONALENS_HAS_LITERT
    std::unique_ptr<litert::lm::Engine> m_engine;
    std::unique_ptr<litert::lm::Conversation> m_conversation;
#else
    QProcess *m_process = nullptr;
#endif
};
