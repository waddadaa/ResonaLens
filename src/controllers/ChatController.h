#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <QElapsedTimer>

class LlamaBackend;
class LiteRTBackend;
class SkillController;
class KnowledgeController;
class SettingsController;

class ChatController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList conversations READ conversations NOTIFY conversationsChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(bool isGenerating READ isGenerating NOTIFY isGeneratingChanged)
    Q_PROPERTY(bool isUsingSkill READ isUsingSkill NOTIFY isUsingSkillChanged)
    Q_PROPERTY(bool contextLimitReached READ contextLimitReached NOTIFY contextLimitReachedChanged)
    Q_PROPERTY(QString activeModelName READ activeModelName NOTIFY activeModelChanged)
    Q_PROPERTY(QString activeSkillName READ activeSkillName NOTIFY activeSkillChanged)
    Q_PROPERTY(QString currentConversationId READ currentConversationId NOTIFY currentConversationChanged)
    Q_PROPERTY(QString streamingText READ streamingText NOTIFY streamingTextChanged)
    Q_PROPERTY(QString activeBackend READ activeBackend NOTIFY activeModelChanged)
    Q_PROPERTY(QString activeAccelerator READ activeAccelerator NOTIFY activeModelChanged)

public:
    explicit ChatController(QObject *parent = nullptr);
    ~ChatController();

    QVariantList conversations() const;
    QVariantList messages() const;
    bool isGenerating() const;
    bool isUsingSkill() const;
    bool contextLimitReached() const;
    QString activeModelName() const;
    QString activeSkillName() const;
    QString currentConversationId() const;
    QString streamingText() const;
    QString activeBackend() const;
    QString activeAccelerator() const;

public slots:
    void sendMessage(const QString &text, const QString &type = "text", const QString &filePath = "");
    void newChat();
    void loadChat(const QString &chatId);
    void deleteChat(const QString &chatId);
    void regenerateLastResponse();
    void clearChat();
    void stopGeneration();
    void loadModel(const QString &filePath, const QString &modelName);
    void setSkillController(SkillController *sc);
    void setKnowledgeController(KnowledgeController *kc);
    void setSettingsController(SettingsController *sc);
    void compactHistory();
    void clearContextLimit();
    QString resolveContentUri(const QString &contentUri);

signals:
    void tokenReceived(const QString &token);
    void sentenceReady(const QString &sentence);
    void generationFinished();
    void skillInvoked(const QString &skillName);
    void skillCompleted(const QString &skillName);
    void errorOccurred(const QString &error);
    void conversationsChanged();
    void messagesChanged();
    void isGeneratingChanged();
    void isUsingSkillChanged();
    void contextLimitReachedChanged();
    void activeModelChanged();
    void activeSkillChanged();
    void currentConversationChanged();
    void streamingTextChanged();

private:
    void loadConversations();
    void loadMessages(const QString &conversationId);
    QString createConversation(const QString &title);
    void addMessage(const QString &conversationId, const QString &role,
                    const QString &content, const QString &type = "text",
                    const QString &filePath = "", int tokenCount = 0,
                    int generationTimeMs = 0);
    QString generateId() const;
    void startGeneration(const QString &prompt);
    void onTokenReceived(const QString &token);
    void onGenerationComplete();
    void onBackendError(const QString &error);
    QString buildPrompt() const;
    QString buildSkillAnswerPrompt(const QString &userQuery, const QString &skillResult) const;
    QString buildCompactPrompt() const;

    enum class Backend { None, LlamaCpp, LiteRT };

    QVariantList m_conversations;
    QVariantList m_messages;
    QString m_currentConversationId;
    QString m_activeModelName = "No model loaded";
    QString m_activeSkillName;
    QString m_streamingText;
    bool m_isGenerating = false;
    bool m_isUsingSkill = false;
    bool m_contextLimitReached = false;
    QElapsedTimer m_generationTimer;

    Backend m_activeBackendType = Backend::None;
    LlamaBackend *m_llamaBackend = nullptr;
    LiteRTBackend *m_liteRTBackend = nullptr;
    SkillController *m_skillController = nullptr;
    KnowledgeController *m_knowledgeController = nullptr;
    SettingsController *m_settingsController = nullptr;
    int m_toolLoopCount = 0;
    bool m_awaitingFinalAnswer = false;
    QString m_ttsSentenceBuffer;  // accumulates tokens until sentence boundary
    static constexpr int kMaxToolLoops = 5;
};
