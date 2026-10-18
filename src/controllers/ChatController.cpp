#include "ChatController.h"
#include "SkillController.h"
#include "KnowledgeController.h"
#include "database/Database.h"
#include "controllers/SettingsController.h"
#include "core/LlamaBackend.h"
#include "core/LiteRTBackend.h"
#include "core/FileProcessor.h"
#include "core/SkillExecutor.h"

#include <QSqlQuery>
#include <QSqlError>
#include <QUuid>
#include <QDateTime>
#include <QDebug>
#include <QFile>
#include <QRegularExpression>
#include <QTextStream>
#include <QFileInfo>
#include <QDate>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDir>
#include <QStandardPaths>
#include <QUrl>

ChatController::ChatController(QObject *parent)
    : QObject(parent)
    , m_llamaBackend(new LlamaBackend(this))
    , m_liteRTBackend(new LiteRTBackend(this))
{
    // llama.cpp backend signals
    connect(m_llamaBackend, &LlamaBackend::tokenGenerated,
            this, &ChatController::onTokenReceived);
    connect(m_llamaBackend, &LlamaBackend::generationComplete,
            this, &ChatController::onGenerationComplete);
    connect(m_llamaBackend, &LlamaBackend::errorOccurred,
            this, &ChatController::onBackendError);

    // LiteRT-LM backend signals
    connect(m_liteRTBackend, &LiteRTBackend::tokenGenerated,
            this, &ChatController::onTokenReceived);
    connect(m_liteRTBackend, &LiteRTBackend::generationComplete,
            this, &ChatController::onGenerationComplete);
    connect(m_liteRTBackend, &LiteRTBackend::errorOccurred,
            this, &ChatController::onBackendError);

    // LiteRT tool calling — when model requests a tool, execute it and send result back
    connect(m_liteRTBackend, &LiteRTBackend::toolCallRequested,
            this, [this](const QString &toolName, const QVariantMap &arguments) {
        qInfo() << "LiteRT tool call:" << toolName << arguments;

        m_isUsingSkill = true;
        m_activeSkillName = toolName;
        emit isUsingSkillChanged();
        emit activeSkillChanged();

        // Execute the tool
        QVariantMap result;
        if (m_skillController) {
            result = m_skillController->executeSkill(toolName, arguments);
        } else {
            result["error"] = "No skill controller available";
        }

        m_isUsingSkill = false;
        m_activeSkillName.clear();
        emit isUsingSkillChanged();
        emit activeSkillChanged();

        // Send result back to LiteRT
        m_liteRTBackend->sendToolResult(toolName, result);
    });

    loadConversations();
}

ChatController::~ChatController() = default;

QVariantList ChatController::conversations() const { return m_conversations; }
QVariantList ChatController::messages() const { return m_messages; }
bool ChatController::isGenerating() const { return m_isGenerating; }
bool ChatController::isUsingSkill() const { return m_isUsingSkill; }
bool ChatController::contextLimitReached() const { return m_contextLimitReached; }
QString ChatController::activeModelName() const { return m_activeModelName; }
QString ChatController::activeSkillName() const { return m_activeSkillName; }
QString ChatController::currentConversationId() const { return m_currentConversationId; }
QString ChatController::streamingText() const { return m_streamingText; }
QString ChatController::activeBackend() const {
    switch (m_activeBackendType) {
    case Backend::LlamaCpp: return "llama.cpp";
    case Backend::LiteRT: return "LiteRT-LM";
    default: return "none";
    }
}

QString ChatController::activeAccelerator() const {
    if (m_activeBackendType == Backend::LiteRT)
        return m_liteRTBackend->accelerator().toUpper();  // "NPU", "GPU", "CPU"
    if (m_activeBackendType == Backend::LlamaCpp)
        return "Vulkan";  // llama.cpp uses Vulkan on Android
    return "";
}

void ChatController::sendMessage(const QString &text, const QString &type, const QString &filePath)
{
    qInfo() << "sendMessage:" << text.left(50) << "type:" << type << "filePath:" << filePath.left(60);

    if (text.trimmed().isEmpty())
        return;

    // Create conversation if needed
    if (m_currentConversationId.isEmpty()) {
        QString title = text.left(50);
        if (text.length() > 50) title += "...";
        m_currentConversationId = createConversation(title);
        emit currentConversationChanged();
    }

    // Add user message
    addMessage(m_currentConversationId, "user", text, type, filePath);
    loadMessages(m_currentConversationId);

    // Start generation
    startGeneration(buildPrompt());
}

void ChatController::newChat()
{
    m_currentConversationId.clear();
    m_messages.clear();
    m_streamingText.clear();
    m_contextLimitReached = false;

    // Reset LiteRT's persistent conversation so context doesn't leak between chats
    if (m_activeBackendType == Backend::LiteRT)
        m_liteRTBackend->resetConversation();

    emit currentConversationChanged();
    emit messagesChanged();
    emit streamingTextChanged();
    emit contextLimitReachedChanged();
}

void ChatController::clearContextLimit()
{
    if (!m_contextLimitReached) return;
    m_contextLimitReached = false;
    emit contextLimitReachedChanged();
}

QString ChatController::resolveContentUri(const QString &contentUri)
{
    // On Android, content:// URIs can't be passed directly to native code.
    // Copy the file to our app's cache directory and return the local path.
    QUrl url(contentUri);
    if (url.scheme() != "content")
        return contentUri;  // already a file path

#ifdef Q_OS_ANDROID
    // Use Qt's built-in content URI handling — QFile can open content:// on Android
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/attachments";
    QDir().mkpath(cacheDir);

    // Generate a unique filename
    QString timestamp = QString::number(QDateTime::currentMSecsSinceEpoch());
    // Try to detect extension from the URI
    QString ext = ".jpg";  // default for images
    if (contentUri.contains("pdf")) ext = ".pdf";
    else if (contentUri.contains("png")) ext = ".png";
    else if (contentUri.contains("txt")) ext = ".txt";

    QString localPath = cacheDir + "/attach_" + timestamp + ext;

    QFile src(contentUri);
    if (!src.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open content URI:" << contentUri;
        return {};
    }

    QFile dst(localPath);
    if (!dst.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to create local file:" << localPath;
        src.close();
        return {};
    }

    const QByteArray payload = src.readAll();
    const qint64 written = dst.write(payload);
    src.close();
    dst.close();
    if (written != payload.size()) {
        qWarning() << "Short write copying content URI:" << contentUri
                   << "wrote" << written << "of" << payload.size();
        QFile::remove(localPath);
        return {};
    }

    qInfo() << "Resolved content URI to:" << localPath << "size:" << QFileInfo(localPath).size();
    return localPath;
#else
    return contentUri;
#endif
}

void ChatController::onBackendError(const QString &error)
{
    bool isContextError = error.contains("too long", Qt::CaseInsensitive)
                       || error.contains("maximum number of tokens", Qt::CaseInsensitive)
                       || (error.contains("context", Qt::CaseInsensitive)
                           && error.contains("exceed", Qt::CaseInsensitive));

    if (isContextError && !m_contextLimitReached) {
        m_isGenerating = false;
        emit isGeneratingChanged();
        m_streamingText.clear();
        emit streamingTextChanged();
        m_contextLimitReached = true;
        emit contextLimitReachedChanged();
    } else {
        emit errorOccurred(error);
    }
}

void ChatController::compactHistory()
{
    if (m_currentConversationId.isEmpty() || m_messages.isEmpty())
        return;

    QString summary = m_llamaBackend->generateSync(buildCompactPrompt());
    if (summary.trimmed().isEmpty())
        return;

    QSqlQuery del(Database::instance().db());
    del.prepare("DELETE FROM messages WHERE conversation_id = ?");
    del.addBindValue(m_currentConversationId);
    if (!del.exec()) {
        qWarning() << "compactHistory: DELETE failed:" << del.lastError().text();
        emit errorOccurred("Failed to compact history: " + del.lastError().text());
        return;
    }

    addMessage(m_currentConversationId, "system",
               "[Conversation summary: " + summary.trimmed() + "]",
               "text", "");

    loadMessages(m_currentConversationId);

    m_contextLimitReached = false;
    emit contextLimitReachedChanged();
}

QString ChatController::buildCompactPrompt() const
{
    QString history;
    for (const QVariant &v : m_messages) {
        QVariantMap msg = v.toMap();
        QString role = msg["role"].toString();
        QString content = msg["content"].toString();
        if (role == "user")
            history += "User: " + content + "\n";
        else if (role == "assistant")
            history += "Assistant: " + content + "\n";
    }

    return "<start_of_turn>user\n"
           "Summarize the following conversation in a compact paragraph that preserves "
           "all key facts, decisions, and context. Write only the summary, no preamble.\n\n"
           + history
           + "<end_of_turn>\n"
             "<start_of_turn>model\n";
}

void ChatController::loadChat(const QString &chatId)
{
    // Switching chats — reset LiteRT's persistent conversation so the model
    // doesn't carry context from the previous chat.
    if (chatId != m_currentConversationId && m_activeBackendType == Backend::LiteRT)
        m_liteRTBackend->resetConversation();

    m_currentConversationId = chatId;
    loadMessages(chatId);
    emit currentConversationChanged();
}

void ChatController::deleteChat(const QString &chatId)
{
    QSqlQuery query(Database::instance().db());
    query.prepare("DELETE FROM conversations WHERE id = ?");
    query.addBindValue(chatId);
    if (!query.exec()) {
        qWarning() << "deleteChat failed:" << query.lastError().text();
        emit errorOccurred("Failed to delete chat: " + query.lastError().text());
        return;
    }

    if (chatId == m_currentConversationId) {
        newChat();
    }
    loadConversations();
}

void ChatController::loadModel(const QString &filePath, const QString &modelName)
{
    m_activeModelName = modelName;

    if (filePath.isEmpty()) {
        qWarning() << "No model file path provided";
        m_activeBackendType = Backend::None;
        emit activeModelChanged();
        return;
    }

    // Auto-detect backend based on model file format
    if (LiteRTBackend::isLiteRTModel(filePath)) {
        qInfo() << "Loading LiteRT model:" << modelName << "from" << filePath;
        m_activeBackendType = Backend::LiteRT;

        // LiteRT models have a 4096-token context — use compact search results.
        if (m_skillController) {
            SkillExecutor *exec = m_skillController->findChild<SkillExecutor *>();
            if (exec) exec->setCompactResults(true);
        }

        // Auto-detect best accelerator (NPU > GPU > CPU)
        m_liteRTBackend->autoDetectAccelerator();

        // Pass tool definitions to LiteRT for function calling
        if (m_skillController) {
            SkillExecutor *executor = m_skillController->findChild<SkillExecutor *>();
            if (executor) {
                // Build tool definitions in Gemini-compatible JSON format
                QJsonArray tools;
                QVariantList skills = executor->skillList();
                for (const QVariant &s : skills) {
                    QVariantMap skill = s.toMap();
                    QJsonObject tool;
                    tool["name"] = skill["name"].toString();
                    tool["description"] = skill["description"].toString();
                    QJsonObject params;
                    params["type"] = "object";
                    params["properties"] = QJsonObject{
                        {QStringLiteral("query"), QJsonObject{
                            {"type", "string"},
                            {"description", "The search query or input"}
                        }}
                    };
                    params["required"] = QJsonArray{"query"};
                    tool["parameters"] = params;
                    tools.append(tool);
                }
                m_liteRTBackend->setToolDefinitions(
                    QString::fromUtf8(QJsonDocument(tools).toJson(QJsonDocument::Compact)));
            }
        }

        m_liteRTBackend->loadModel(filePath);
    } else {
        // Default: GGUF via llama.cpp
        qInfo() << "Loading GGUF model:" << modelName << "from" << filePath;
        m_activeBackendType = Backend::LlamaCpp;
        if (m_skillController) {
            SkillExecutor *exec = m_skillController->findChild<SkillExecutor *>();
            if (exec) exec->setCompactResults(false);  // llama.cpp has large context
        }
        m_llamaBackend->loadModel(filePath);
    }

    emit activeModelChanged();
}

void ChatController::setSkillController(SkillController *sc)
{
    m_skillController = sc;

    if (sc) {
        SkillExecutor *executor = sc->findChild<SkillExecutor *>();
        if (executor) {
            // Wire summarizer to whichever backend is active.
            // Called for each web search result page that needs summarizing.
            executor->setSummarizer([this](const QString &prompt) -> QString {
                if (m_activeBackendType == Backend::LiteRT)
                    return m_liteRTBackend->generateSync(prompt);
                return m_llamaBackend->generateSync(prompt);
            });
        }
    }
}

void ChatController::setKnowledgeController(KnowledgeController *kc)
{
    m_knowledgeController = kc;
}

void ChatController::setSettingsController(SettingsController *sc)
{
    m_settingsController = sc;
}

void ChatController::regenerateLastResponse()
{
    if (m_messages.isEmpty() || m_isGenerating)
        return;

    // Remove last assistant message
    QVariantMap lastMsg = m_messages.last().toMap();
    if (lastMsg["role"].toString() == "assistant") {
        QSqlQuery query(Database::instance().db());
        query.prepare("DELETE FROM messages WHERE id = ?");
        query.addBindValue(lastMsg["id"]);
        if (!query.exec()) {
            qWarning() << "regenerateLastResponse: DELETE failed:" << query.lastError().text();
            emit errorOccurred("Failed to regenerate: " + query.lastError().text());
            return;
        }

        m_messages.removeLast();
        emit messagesChanged();

        startGeneration(buildPrompt());
    }
}

void ChatController::clearChat()
{
    if (m_currentConversationId.isEmpty())
        return;

    QSqlQuery query(Database::instance().db());
    query.prepare("DELETE FROM messages WHERE conversation_id = ?");
    query.addBindValue(m_currentConversationId);
    if (!query.exec()) {
        qWarning() << "clearChat failed:" << query.lastError().text();
        emit errorOccurred("Failed to clear chat: " + query.lastError().text());
        return;
    }

    m_messages.clear();
    emit messagesChanged();
}

void ChatController::stopGeneration()
{
    if (m_activeBackendType == Backend::LiteRT) {
        m_liteRTBackend->stop();
    } else {
        m_llamaBackend->stop();
    }
}

void ChatController::loadConversations()
{
    m_conversations.clear();

    QSqlQuery query(Database::instance().db());
    if (!query.exec("SELECT id, title, model_id, is_pinned, created_at, updated_at "
                    "FROM conversations ORDER BY updated_at DESC LIMIT 50")) {
        qWarning() << "loadConversations failed:" << query.lastError().text();
        emit conversationsChanged();
        return;
    }

    while (query.next()) {
        QVariantMap conv;
        conv["id"] = query.value(0).toString();
        conv["title"] = query.value(1).toString();
        conv["modelId"] = query.value(2).toString();
        conv["isPinned"] = query.value(3).toBool();
        conv["createdAt"] = query.value(4).toString();
        conv["updatedAt"] = query.value(5).toString();
        m_conversations.append(conv);
    }

    emit conversationsChanged();
}

void ChatController::loadMessages(const QString &conversationId)
{
    m_messages.clear();

    QSqlQuery query(Database::instance().db());
    query.prepare("SELECT id, conversation_id, role, content, type, file_path, "
                  "token_count, generation_time_ms, created_at "
                  "FROM messages WHERE conversation_id = ? ORDER BY created_at ASC");
    query.addBindValue(conversationId);
    if (!query.exec()) {
        qWarning() << "loadMessages failed:" << query.lastError().text();
        emit messagesChanged();
        return;
    }

    while (query.next()) {
        QVariantMap msg;
        msg["id"] = query.value(0).toString();
        msg["conversationId"] = query.value(1).toString();
        msg["role"] = query.value(2).toString();
        msg["content"] = query.value(3).toString();
        msg["type"] = query.value(4).toString();
        msg["filePath"] = query.value(5).toString();
        msg["tokenCount"] = query.value(6).toInt();
        msg["generationTimeMs"] = query.value(7).toInt();
        msg["createdAt"] = query.value(8).toString();
        m_messages.append(msg);
    }

    emit messagesChanged();
}

QString ChatController::createConversation(const QString &title)
{
    QString id = generateId();
    QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    QSqlQuery query(Database::instance().db());
    query.prepare("INSERT INTO conversations (id, title, created_at, updated_at) VALUES (?, ?, ?, ?)");
    query.addBindValue(id);
    query.addBindValue(title);
    query.addBindValue(now);
    query.addBindValue(now);

    if (!query.exec()) {
        qWarning() << "Failed to create conversation:" << query.lastError().text();
        return {};
    }

    loadConversations();
    return id;
}

void ChatController::addMessage(const QString &conversationId, const QString &role,
                                 const QString &content, const QString &type,
                                 const QString &filePath, int tokenCount, int generationTimeMs)
{
    QString id = generateId();
    QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    QSqlQuery query(Database::instance().db());
    query.prepare("INSERT INTO messages (id, conversation_id, role, content, type, file_path, "
                  "token_count, generation_time_ms, created_at) "
                  "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
    query.addBindValue(id);
    query.addBindValue(conversationId);
    query.addBindValue(role);
    query.addBindValue(content);
    query.addBindValue(type);
    query.addBindValue(filePath);
    query.addBindValue(tokenCount);
    query.addBindValue(generationTimeMs);
    query.addBindValue(now);

    if (!query.exec()) {
        qWarning() << "Failed to add message:" << query.lastError().text();
        return;
    }

    // Update conversation timestamp
    QSqlQuery update(Database::instance().db());
    update.prepare("UPDATE conversations SET updated_at = ? WHERE id = ?");
    update.addBindValue(now);
    update.addBindValue(conversationId);
    if (!update.exec())
        qWarning() << "addMessage: conversation timestamp update failed:" << update.lastError().text();
}

QString ChatController::generateId() const
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

void ChatController::startGeneration(const QString &prompt)
{
    m_isGenerating = true;
    m_streamingText.clear();
    m_ttsSentenceBuffer.clear();
    if (!m_awaitingFinalAnswer)
        m_toolLoopCount = 0; // only reset on fresh user message, not mid-loop re-generates
    m_generationTimer.start();
    emit isGeneratingChanged();
    emit streamingTextChanged();

    // Check if the last user message has an image attachment
    QString imagePath;
    for (int i = m_messages.size() - 1; i >= 0; --i) {
        QVariantMap msg = m_messages[i].toMap();
        if (msg["role"].toString() == "user") {
            QString type = msg["type"].toString();
            if (type == "image")
                imagePath = msg["filePath"].toString();
            break;
        }
    }

    // Sync generation parameters from settings to backend
    if (m_settingsController) {
        m_llamaBackend->setGenerationParams(
            m_settingsController->temperature(),
            m_settingsController->topP(),
            m_settingsController->maxTokens());
    }

    // Dispatch to active backend
    qInfo() << "startGeneration: backend:" << (int)m_activeBackendType
            << "imagePath:" << imagePath.left(60)
            << "promptLen:" << prompt.length();
    if (m_activeBackendType == Backend::LiteRT) {
        if (!imagePath.isEmpty()) {
            qInfo() << "Dispatching generateWithImage";
            m_liteRTBackend->generateWithImage(prompt, imagePath);
        } else {
            m_liteRTBackend->generate(prompt);
        }
    } else {
        m_llamaBackend->generate(prompt);
    }
}

void ChatController::onTokenReceived(const QString &token)
{
    m_streamingText += token;
    emit streamingTextChanged();
    emit tokenReceived(token);

    // Streaming TTS: suppress during the first LLM pass when skills are available —
    // the model might output "USE_SKILL: ..." which shouldn't be spoken aloud.
    // Only stream to TTS during the final answer pass (m_awaitingFinalAnswer),
    // or when no skill controller is present (skills disabled).
    bool ttsAllowed = !m_skillController || m_awaitingFinalAnswer;
    if (!ttsAllowed)
        return;

    m_ttsSentenceBuffer += token;
    static QRegularExpression sentenceEnd("[.!?] ");
    if (m_ttsSentenceBuffer.length() >= 80 && sentenceEnd.match(m_ttsSentenceBuffer).hasMatch()) {
        // Split at the LAST sentence boundary to get the longest natural chunk
        int splitPos = -1;
        QRegularExpressionMatchIterator it = sentenceEnd.globalMatch(m_ttsSentenceBuffer);
        while (it.hasNext()) {
            QRegularExpressionMatch m = it.next();
            splitPos = m.capturedEnd();
        }
        if (splitPos > 0) {
            QString sentence = m_ttsSentenceBuffer.left(splitPos).trimmed();
            m_ttsSentenceBuffer = m_ttsSentenceBuffer.mid(splitPos);
            if (!sentence.isEmpty())
                emit sentenceReady(sentence);
        }
    }
}

void ChatController::onGenerationComplete()
{
    // Flush any remaining TTS buffer — but only if TTS was active this pass.
    // During the first pass with skills, TTS is suppressed (tool call text).
    bool ttsWasActive = !m_skillController || m_awaitingFinalAnswer;
    if (ttsWasActive) {
        QString remaining = m_ttsSentenceBuffer.trimmed();
        m_ttsSentenceBuffer.clear();
        if (!remaining.isEmpty())
            emit sentenceReady(remaining);
    } else {
        m_ttsSentenceBuffer.clear();
    }

    int elapsed = m_generationTimer.elapsed();

    qInfo() << "onGenerationComplete: streamingText length:" << m_streamingText.length()
            << "awaitingFinalAnswer:" << m_awaitingFinalAnswer;

    if (m_streamingText.isEmpty()) {
        m_isGenerating = false;
        emit isGeneratingChanged();
        emit generationFinished();
        return;
    }

    // ══════════════════════════════════════════════════════════
    // Skill Detection Loop (Anthropic Skills pattern)
    //
    // The LLM outputs natural language that may contain a skill
    // invocation in any of several formats (XML tag, bracket,
    // keyword, JSON, or even natural phrasing). The SkillExecutor
    // detects intent, executes the backend, and returns clean text.
    // We inject the result as an Observation and re-prompt.
    // Max 5 rounds to prevent infinite loops.
    // ══════════════════════════════════════════════════════════

    if (m_skillController && m_toolLoopCount < kMaxToolLoops && !m_awaitingFinalAnswer) {
        SkillExecutor *executor = m_skillController->findChild<SkillExecutor *>();
        QString skillName, skillInput;

        if (executor && executor->detectSkillIntent(m_streamingText, skillName, skillInput)) {
            m_toolLoopCount++;
            qInfo() << "Skill detected:" << skillName << "input:" << skillInput;

            // Don't save the raw tool call text to DB — it's not a user-facing message.
            // The UI would show raw "<|tool_call>..." or "USE_SKILL:..." otherwise.

            // Execute the skill
            m_isUsingSkill = true;
            m_activeSkillName = skillName;
            emit isUsingSkillChanged();
            emit activeSkillChanged();

            QString resultText = executor->executeSkill(skillName, skillInput);

            m_isUsingSkill = false;
            m_activeSkillName.clear();
            emit isUsingSkillChanged();
            emit activeSkillChanged();

            // Persist the observation to DB only (not to m_messages — keeps it off the UI
            // and out of buildPrompt, preventing small models from echoing the large context).
            addMessage(m_currentConversationId, "system",
                       "Observation: The skill \"" + skillName + "\" returned:\n" + resultText,
                       "text", "");

            // Find the original user query (last user message before skill invocation).
            QString userQuery;
            for (int i = m_messages.size() - 1; i >= 0; --i) {
                if (m_messages[i].toMap()["role"].toString() == "user") {
                    userQuery = m_messages[i].toMap()["content"].toString();
                    break;
                }
            }

            // Build a clean, focused prompt: skill results + question only.
            // This avoids the full conversation history being prepended, which causes
            // small models to echo back the large injected context instead of answering.
            m_awaitingFinalAnswer = true;
            m_streamingText.clear();
            m_generationTimer.start();
            emit streamingTextChanged();

            QString answerPrompt = buildSkillAnswerPrompt(userQuery, resultText);
            qInfo() << "Skill answer prompt length:" << answerPrompt.length()
                    << "userQuery:" << userQuery.left(60)
                    << "resultText length:" << resultText.length();
            startGeneration(answerPrompt);
            return;
        }
    }

    // ── Normal completion (no tool calls) ──
    // If TTS was suppressed during the first pass (skills were available but no skill
    // was invoked), send the full response to TTS now.
    if (m_skillController && !m_awaitingFinalAnswer && !m_streamingText.isEmpty()) {
        emit sentenceReady(m_streamingText.trimmed());
    }

    m_awaitingFinalAnswer = false;
    addMessage(m_currentConversationId, "assistant", m_streamingText, "text", "", 0, elapsed);

    QVariantMap msg;
    msg["role"] = "assistant";
    msg["content"] = m_streamingText;
    msg["type"] = "text";
    msg["createdAt"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    msg["tokenCount"] = 0;
    msg["generationTimeMs"] = elapsed;
    m_messages.append(msg);
    emit messagesChanged();

    // Update conversation timestamp in cached list
    for (int i = 0; i < m_conversations.size(); ++i) {
        QVariantMap conv = m_conversations[i].toMap();
        if (conv["id"].toString() == m_currentConversationId) {
            conv["updatedAt"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
            m_conversations[i] = conv;
            if (i > 0) {
                m_conversations.move(i, 0);
            }
            emit conversationsChanged();
            break;
        }
    }

    m_isGenerating = false;
    m_streamingText.clear();
    emit isGeneratingChanged();
    emit streamingTextChanged();
    emit generationFinished();
}

QString ChatController::buildPrompt() const
{
    QString prompt;

    // ── Inject skill context for ALL backends ──
    if (m_skillController) {
        SkillExecutor *executor = m_skillController->findChild<SkillExecutor *>();
        if (executor) {
            QString skillContext = executor->buildSkillContext();
            if (!skillContext.isEmpty()) {
                prompt += "<start_of_turn>user\n"
                          "You are ResonaLens. Today is "
                          + QDate::currentDate().toString("yyyy-MM-dd") + ".\n\n"
                          + skillContext
                          + "<end_of_turn>\n"
                          "<start_of_turn>model\n"
                          "Understood."
                          "<end_of_turn>\n";
            }
        }
    }

    // ── Inject pinned knowledge documents (query-aware) ──
    if (m_knowledgeController) {
        // Find the last user message to use as the retrieval query
        QString lastUserQuery;
        for (auto it = m_messages.crbegin(); it != m_messages.crend(); ++it) {
            QVariantMap msg = it->toMap();
            if (msg["role"].toString() == "user") {
                lastUserQuery = msg["content"].toString();
                break;
            }
        }

        QString knowledgeContext = m_knowledgeController->pinnedDocumentsContext(lastUserQuery);
        if (!knowledgeContext.isEmpty()) {
            prompt += "<start_of_turn>user\n"
                      "The following excerpts from your knowledge base are relevant to the conversation. "
                      "Use them to answer accurately and specifically.\n\n"
                      + knowledgeContext
                      + "<end_of_turn>\n"
                        "<start_of_turn>model\n"
                        "Understood. I have read the provided excerpts and will answer based on them.\n"
                        "<end_of_turn>\n";
        }
    }

    for (const QVariant &v : m_messages) {
        QVariantMap msg = v.toMap();
        QString role = msg["role"].toString();
        QString content = msg["content"].toString();
        QString type = msg["type"].toString();
        QString filePath = msg["filePath"].toString();

        if (role == "user") {
            QString userContent = content;

            // If a file was attached, extract text and include in prompt
            if (!filePath.isEmpty() && (type == "document" || type == "text")) {
                FileProcessor processor;
                QString fileName = QFileInfo(filePath).fileName();
                QString fileContent = processor.processFile(filePath);
                if (!fileContent.isEmpty()) {
                    // Truncate very large files
                    if (fileContent.length() > 6000)
                        fileContent = fileContent.left(6000) + "\n...(truncated)";
                    userContent = "User attached file: " + fileName + "\n\n"
                                  + "--- FILE CONTENT ---\n" + fileContent + "\n--- END FILE ---\n\n"
                                  + "Please read and analyze the attached file.";
                } else {
                    qWarning() << "File extraction returned empty for:" << filePath;
                    userContent = "User attached file: " + fileName
                                  + "\n\n(The file content could not be extracted. "
                                    "Please let the user know the file could not be read.)";
                }
            }

            prompt += "<start_of_turn>user\n" + userContent + "<end_of_turn>\n";
        } else if (role == "assistant") {
            prompt += "<start_of_turn>model\n" + content + "<end_of_turn>\n";
        } else if (role == "system") {
            // Compact summaries are injected as context; other system messages are skipped.
            if (content.startsWith("[Conversation summary:")) {
                prompt += "<start_of_turn>user\n"
                          "Here is a summary of our conversation so far:\n"
                          + content
                          + "<end_of_turn>\n"
                            "<start_of_turn>model\n"
                            "Understood, I have the context.\n"
                            "<end_of_turn>\n";
            }
        }
    }
    prompt += "<start_of_turn>model\n";
    return prompt;
}

QString ChatController::buildSkillAnswerPrompt(const QString &userQuery, const QString &skillResult) const
{
    QString prompt;

    // For LiteRT's small context (4096 tokens), skip the full skill catalogue —
    // the model already executed the skill and just needs to answer based on results.
    // For llama.cpp (large context), include the full skill context.
    bool isSmallContext = (m_activeBackendType == Backend::LiteRT);

    if (!isSmallContext && m_skillController) {
        SkillExecutor *executor = m_skillController->findChild<SkillExecutor *>();
        if (executor) {
            QString ctx = executor->buildSkillContext();
            if (!ctx.isEmpty()) {
                prompt += "<start_of_turn>user\n"
                          "You are ResonaLens. Today is "
                          + QDate::currentDate().toString("yyyy-MM-dd") + ".\n\n"
                          + ctx
                          + "<end_of_turn>\n"
                          "<start_of_turn>model\n"
                          "Understood."
                          "<end_of_turn>\n";
            }
        }
    }

    // Truncate skill results if they'd overflow a small context window.
    // Budget: ~3000 chars for results, leaving room for framing + generation.
    QString trimmedResult = skillResult;
    if (isSmallContext && trimmedResult.length() > 3000)
        trimmedResult = trimmedResult.left(3000) + "\n...(truncated)";

    // Single focused turn: search results + the question.
    QString datePrefix = isSmallContext
        ? ("You are ResonaLens. Today is " + QDate::currentDate().toString("yyyy-MM-dd") + ".\n\n")
        : QString();

    prompt += "<start_of_turn>user\n"
              + datePrefix
              + trimmedResult + "\n\n"
              "Based on the information above, answer this question directly and "
              "specifically. Include key numbers, dates, and facts. "
              "Do not just list sources — synthesize the information into a clear answer.\n\n"
              "Question: " + userQuery
              + "<end_of_turn>\n"
              "<start_of_turn>model\n";
    return prompt;
}
