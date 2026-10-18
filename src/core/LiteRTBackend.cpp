#include "LiteRTBackend.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QMetaObject>
#include <QDebug>

#ifdef RESONALENS_HAS_LITERT
#include "runtime/engine/engine.h"
#include "runtime/conversation/conversation.h"
#include <nlohmann/json.hpp>
using json = nlohmann::ordered_json;
#else
#include <QProcess>
#endif

LiteRTBackend::LiteRTBackend(QObject *parent)
    : QObject(nullptr)
{
    Q_UNUSED(parent)

    m_binaryPath = findBinary();

#ifndef RESONALENS_HAS_LITERT
    if (m_binaryPath.isEmpty()) {
        qWarning() << "litert_lm_main binary not found (CLI fallback mode)";
    } else {
        qInfo() << "LiteRT-LM CLI binary found:" << m_binaryPath;
    }
#else
    qInfo() << "LiteRT-LM C++ API mode enabled";
#endif

    this->moveToThread(&m_workerThread);
    m_workerThread.start();
}

LiteRTBackend::~LiteRTBackend()
{
    m_stopRequested = true;
    QMetaObject::invokeMethod(this, [this]() {
        unloadModel();
    }, Qt::BlockingQueuedConnection);
    m_workerThread.quit();
    m_workerThread.wait();
}

bool LiteRTBackend::isLiteRTModel(const QString &path)
{
    return path.endsWith(".litertlm", Qt::CaseInsensitive)
        || path.endsWith(".task", Qt::CaseInsensitive);
}

QString LiteRTBackend::accelerator() const
{
    return m_accelerator;
}

// ─────────────────────────────────────────────────────────────────────
// NPU auto-detection
// ─────────────────────────────────────────────────────────────────────

bool LiteRTBackend::isNpuAvailable()
{
#ifdef Q_OS_ANDROID
    // Qualcomm Hexagon NPU (Snapdragon 8 Gen 2+)
    if (QFileInfo::exists("/dev/cdsp") || QFileInfo::exists("/vendor/lib64/libQnnHtp.so")) {
        qInfo() << "Qualcomm NPU detected (Hexagon cDSP)";
        return true;
    }
    // Google Tensor NPU (Pixel 8+)
    if (QFileInfo::exists("/dev/tpu0") || QFileInfo::exists("/vendor/lib64/libtpu_client.so")) {
        qInfo() << "Google Tensor NPU detected";
        return true;
    }
    // MediaTek APU (Dimensity 9000+)
    if (QFileInfo::exists("/dev/apusys") || QFileInfo::exists("/vendor/lib64/libneuronruntime.so")) {
        qInfo() << "MediaTek APU detected";
        return true;
    }
    // Samsung Exynos NPU
    if (QFileInfo::exists("/dev/npu0") || QFileInfo::exists("/vendor/lib64/libnpuc_backend.so")) {
        qInfo() << "Samsung Exynos NPU detected";
        return true;
    }
#endif
    return false;
}

void LiteRTBackend::autoDetectAccelerator()
{
    QString previous = m_accelerator;

    if (isNpuAvailable()) {
        m_accelerator = "npu";
        qInfo() << "Auto-detected accelerator: NPU";
    } else {
        m_accelerator = "gpu";
        qInfo() << "Auto-detected accelerator: GPU (NPU not available)";
    }

    if (m_accelerator != previous)
        emit acceleratorChanged();
}

// ─────────────────────────────────────────────────────────────────────
// Binary discovery (CLI fallback)
// ─────────────────────────────────────────────────────────────────────

QString LiteRTBackend::findBinary()
{
    QStringList searchPaths = {
        QCoreApplication::applicationDirPath() + "/litert_lm_main",
        QCoreApplication::applicationDirPath() + "/third_party/litert_lm_main",
        QCoreApplication::applicationDirPath() + "/../../third_party/litert_lm_main",
        QCoreApplication::applicationDirPath() + "/../lib/litert_lm_main",
    };

#ifdef Q_OS_ANDROID
    QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QString liteRTDir = dataDir + "/litert";
    QString executablePath = liteRTDir + "/litert_lm_main";

    if (!QFileInfo::exists(executablePath)) {
        QDir().mkpath(liteRTDir);
        QDir assetsDir("assets:/litert");
        for (const QString &name : assetsDir.entryList(QDir::Files)) {
            QString src = "assets:/litert/" + name;
            QString dst = liteRTDir + "/" + name;
            if (!QFileInfo::exists(dst)) {
                QFile::copy(src, dst);
                QFile::setPermissions(dst,
                    QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
            }
        }
        qInfo() << "LiteRT-LM extracted to:" << liteRTDir;
    }
    searchPaths.prepend(executablePath);
#endif

    QString fromPath = QStandardPaths::findExecutable("litert_lm_main");
    if (!fromPath.isEmpty())
        searchPaths.prepend(fromPath);

    for (const QString &path : searchPaths) {
        if (QFileInfo::exists(path))
            return QFileInfo(path).absoluteFilePath();
    }
    return {};
}

// ─────────────────────────────────────────────────────────────────────
// Model Loading — with NPU support and warmup
// ─────────────────────────────────────────────────────────────────────

bool LiteRTBackend::loadModel(const QString &modelPath)
{
    bool result = false;
    QMetaObject::invokeMethod(this, [this, modelPath, &result]() {
#ifdef RESONALENS_HAS_LITERT
        qInfo() << "Loading LiteRT model via C++ API:" << modelPath
                << "accelerator:" << m_accelerator;

        auto model_assets = litert::lm::ModelAssets::Create(modelPath.toStdString());
        if (!model_assets.ok()) {
            emit errorOccurred("Failed to load model assets: " + modelPath);
            return;
        }

        // ── Select accelerator backend (NPU > GPU > CPU) ──
        litert::lm::Backend backend = litert::lm::Backend::GPU;
        if (m_accelerator == "cpu")
            backend = litert::lm::Backend::CPU;
        else if (m_accelerator == "npu")
            backend = litert::lm::Backend::NPU;

        auto engine_settings = litert::lm::EngineSettings::CreateDefault(
            *model_assets, backend);

        auto engine = litert::lm::Engine::CreateEngine(engine_settings);
        if (!engine.ok() && m_accelerator == "npu") {
            qWarning() << "NPU engine failed, falling back to GPU";
            m_accelerator = "gpu";
            emit acceleratorChanged();
            engine_settings = litert::lm::EngineSettings::CreateDefault(
                *model_assets, litert::lm::Backend::GPU);
            engine = litert::lm::Engine::CreateEngine(engine_settings);
        }
        if (!engine.ok() && m_accelerator == "gpu") {
            qWarning() << "GPU engine failed, falling back to CPU";
            m_accelerator = "cpu";
            emit acceleratorChanged();
            engine_settings = litert::lm::EngineSettings::CreateDefault(
                *model_assets, litert::lm::Backend::CPU);
            engine = litert::lm::Engine::CreateEngine(engine_settings);
        }
        if (!engine.ok()) {
            emit errorOccurred("Failed to create LiteRT engine on all backends");
            return;
        }
        m_engine = std::move(*engine);

        // ── Engine warmup ──
        qInfo() << "Warming up LiteRT engine (" << m_accelerator << ")...";
        auto warmup_status = m_engine->WarmUp();
        if (!warmup_status.ok()) {
            qWarning() << "Engine warmup failed (non-fatal):"
                       << QString::fromStdString(warmup_status.ToString());
        }

        // ── Create persistent conversation ──
        litert::lm::JsonPreface preface;
        if (!m_toolsJson.isEmpty()) {
            auto tools = json::parse(m_toolsJson.toStdString(), nullptr, false);
            if (!tools.is_discarded())
                preface.tools = tools;
        }

        auto session_config = litert::lm::SessionConfig::CreateDefault();
        auto conv_config = litert::lm::ConversationConfig::Builder()
            .SetSessionConfig(session_config)
            .SetPreface(preface)
            .Build(*m_engine);

        if (!conv_config.ok()) {
            emit errorOccurred("Failed to create conversation config");
            return;
        }

        auto conversation = litert::lm::Conversation::Create(*m_engine, *conv_config);
        if (!conversation.ok()) {
            emit errorOccurred("Failed to create conversation");
            return;
        }
        m_conversation = std::move(*conversation);

        m_modelLoaded = true;
        m_modelPath = modelPath;
        result = true;
        qInfo() << "LiteRT model loaded (C++ API, backend:" << m_accelerator << ")";
        emit modelLoaded(modelPath);
#else
        // CLI fallback
        if (m_binaryPath.isEmpty()) {
            emit errorOccurred("LiteRT-LM binary not found");
            return;
        }
        if (!QFileInfo::exists(modelPath)) {
            emit errorOccurred("Model file not found: " + modelPath);
            return;
        }
        m_modelPath = modelPath;
        m_modelLoaded = true;
        result = true;
        qInfo() << "LiteRT model registered (CLI mode, backend:" << m_accelerator << ")";
        emit modelLoaded(modelPath);
#endif
    }, Qt::BlockingQueuedConnection);
    return result;
}

void LiteRTBackend::unloadModel()
{
#ifdef RESONALENS_HAS_LITERT
    m_conversation.reset();
    m_engine.reset();
#else
    if (m_process && m_process->state() != QProcess::NotRunning) {
        m_process->kill();
        m_process->waitForFinished(3000);
    }
#endif
    m_modelPath.clear();
    m_modelLoaded = false;
    m_turnCount = 0;
    emit modelUnloaded();
}

void LiteRTBackend::resetConversation()
{
#ifdef RESONALENS_HAS_LITERT
    QMetaObject::invokeMethod(this, [this]() {
        if (!m_engine) return;

        m_conversation.reset();

        litert::lm::JsonPreface preface;
        if (!m_toolsJson.isEmpty()) {
            auto tools = json::parse(m_toolsJson.toStdString(), nullptr, false);
            if (!tools.is_discarded())
                preface.tools = tools;
        }

        auto session_config = litert::lm::SessionConfig::CreateDefault();
        auto conv_config = litert::lm::ConversationConfig::Builder()
            .SetSessionConfig(session_config)
            .SetPreface(preface)
            .Build(*m_engine);

        if (conv_config.ok()) {
            auto conversation = litert::lm::Conversation::Create(*m_engine, *conv_config);
            if (conversation.ok())
                m_conversation = std::move(*conversation);
        }
        m_turnCount = 0;
        qInfo() << "LiteRT conversation reset";
    }, Qt::QueuedConnection);
#else
    m_turnCount = 0;
#endif
}

bool LiteRTBackend::isModelLoaded() const
{
    return m_modelLoaded;
}

void LiteRTBackend::setToolDefinitions(const QString &toolsJson)
{
    m_toolsJson = toolsJson;
}

// ─────────────────────────────────────────────────────────────────────
// Generation dispatch
// ─────────────────────────────────────────────────────────────────────

void LiteRTBackend::generate(const QString &prompt)
{
    m_stopRequested = false;

#ifdef RESONALENS_HAS_LITERT
    // C++ API: extract only the latest user message — conversation object has history.
    QString userMessage;
    int lastUserStart = prompt.lastIndexOf("<start_of_turn>user\n");
    if (lastUserStart >= 0) {
        int contentStart = lastUserStart + QString("<start_of_turn>user\n").length();
        int contentEnd = prompt.indexOf("<end_of_turn>", contentStart);
        if (contentEnd > contentStart)
            userMessage = prompt.mid(contentStart, contentEnd - contentStart).trimmed();
    }
    if (userMessage.isEmpty())
        userMessage = prompt;

    QMetaObject::invokeMethod(this, [this, userMessage]() {
        doGenerate(userMessage);
    }, Qt::QueuedConnection);
#else
    // CLI fallback: convert Gemma tags to plain text (CLI wraps its own template).
    QString plainPrompt;
    int searchFrom = 0;
    while (true) {
        int userStart = prompt.indexOf("<start_of_turn>user\n", searchFrom);
        int modelStart = prompt.indexOf("<start_of_turn>model\n", searchFrom);

        int turnStart = -1;
        bool isUser = false;
        if (userStart >= 0 && (modelStart < 0 || userStart < modelStart)) {
            turnStart = userStart;
            isUser = true;
        } else if (modelStart >= 0) {
            turnStart = modelStart;
            isUser = false;
        } else {
            break;
        }

        QString tag = isUser ? "<start_of_turn>user\n" : "<start_of_turn>model\n";
        int contentStart = turnStart + tag.length();
        int contentEnd = prompt.indexOf("<end_of_turn>", contentStart);

        if (contentEnd > contentStart) {
            QString content = prompt.mid(contentStart, contentEnd - contentStart).trimmed();
            if (!content.isEmpty()) {
                if (isUser)
                    plainPrompt += "User: " + content + "\n\n";
                else
                    plainPrompt += "Assistant: " + content + "\n\n";
            }
            searchFrom = contentEnd + QString("<end_of_turn>").length();
        } else {
            break;
        }
    }

    if (plainPrompt.isEmpty())
        plainPrompt = prompt;

    QMetaObject::invokeMethod(this, [this, plainPrompt]() {
        doGenerate(plainPrompt);
    }, Qt::QueuedConnection);
#endif
}

QString LiteRTBackend::generateSync(const QString &prompt, int maxTokens)
{
    Q_UNUSED(maxTokens)
    if (!m_modelLoaded) return {};

    // Extract just the user message content from Gemma-format prompt
    QString userMessage = prompt;
    int lastUserStart = prompt.lastIndexOf("<start_of_turn>user\n");
    if (lastUserStart >= 0) {
        int contentStart = lastUserStart + QString("<start_of_turn>user\n").length();
        int contentEnd = prompt.indexOf("<end_of_turn>", contentStart);
        if (contentEnd > contentStart)
            userMessage = prompt.mid(contentStart, contentEnd - contentStart).trimmed();
    }

#ifdef RESONALENS_HAS_LITERT
    if (!m_engine) return {};

    // Use a temporary conversation so we don't pollute the main chat history
    auto session_config = litert::lm::SessionConfig::CreateDefault();
    auto conv_config = litert::lm::ConversationConfig::Builder()
        .SetSessionConfig(session_config)
        .Build(*m_engine);
    if (!conv_config.ok()) return {};

    auto conv = litert::lm::Conversation::Create(*m_engine, *conv_config);
    if (!conv.ok()) return {};

    json content = json::array();
    content.push_back({{"type", "text"}, {"text", userMessage.toStdString()}});
    json inputMessage = {{"role", "user"}, {"content", content}};

    // Share result via shared_ptr so a late-firing callback (e.g. after the
    // WaitUntilDone timeout) can't write into a stack slot that no longer
    // exists. Capture by value in the callback.
    auto result = std::make_shared<QString>();
    auto callback = [result](absl::StatusOr<litert::lm::Message> message) {
        if (!message.ok()) return;
        if (!std::holds_alternative<json>(*message)) return;
        json msgJson = std::get<json>(*message);
        if (msgJson.is_null()) return;
        if (msgJson.contains("content") && msgJson["content"].is_array()) {
            for (auto &item : msgJson["content"]) {
                if (item.contains("text"))
                    *result += QString::fromStdString(item["text"].get<std::string>());
            }
        }
    };

    auto status = conv->get()->SendMessageAsync(inputMessage, std::move(callback));
    if (status.ok())
        m_engine->WaitUntilDone(absl::Seconds(60));

    return *result;
#else
    // CLI: spawn a one-shot process and block until it finishes
    if (m_binaryPath.isEmpty()) return {};

    QProcess proc;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QString libDir = QFileInfo(m_binaryPath).absolutePath();
    QString existingLdPath = env.value("LD_LIBRARY_PATH");
    env.insert("LD_LIBRARY_PATH", libDir + (existingLdPath.isEmpty() ? "" : ":" + existingLdPath));
    proc.setProcessEnvironment(env);
    proc.setProcessChannelMode(QProcess::SeparateChannels);

    // Truncate prompt to fit context
    QString truncated = userMessage;
    if (truncated.length() > 8000)
        truncated = truncated.left(8000);

    QStringList args;
    QString program;
#ifdef Q_OS_ANDROID
    program = "/system/bin/linker64";
    args << m_binaryPath;
#else
    program = m_binaryPath;
#endif
    args << "--backend=" + m_accelerator
         << "--model_path=" + m_modelPath
         << "--input_prompt=" + truncated;

    proc.start(program, args);
    if (!proc.waitForStarted(10000)) return {};
    if (!proc.waitForFinished(60000)) {
        proc.kill();
        return {};
    }

    QString output = QString::fromUtf8(proc.readAllStandardOutput());

    // Strip the echoed prompt — find the last line of our input
    QStringList promptLines = truncated.split('\n', Qt::SkipEmptyParts);
    if (!promptLines.isEmpty()) {
        QString marker = promptLines.last().trimmed();
        int echoEnd = output.lastIndexOf(marker);
        if (echoEnd >= 0) {
            echoEnd += marker.length();
            int nl = output.indexOf('\n', echoEnd);
            output = (nl >= 0) ? output.mid(nl + 1) : output.mid(echoEnd);
        }
    }

    // Filter noise lines
    QStringList clean;
    for (const QString &line : output.split('\n')) {
        QString t = line.trimmed();
        if (t.isEmpty()) continue;
        if (t.startsWith("BenchmarkInfo:") || t.startsWith("Init ")
            || t.startsWith("Prefill ") || t.startsWith("Decode ")
            || t.startsWith("TextToTokenIds") || t.startsWith("Time to first")
            || t.contains("tokens/sec") || t.startsWith("Turn ")
            || (t.startsWith("--") && t.count('-') > 5)
            || t.contains("dlopen") || t.startsWith("INFO:")
            || t.startsWith("WARNING:") || t.startsWith("I ")
            || t.startsWith("W ") || t.contains("OpenCL"))
            continue;
        clean.append(line);
    }
    return clean.join("\n").trimmed();
#endif
}

void LiteRTBackend::generateWithImage(const QString &prompt, const QString &imagePath)
{
    m_stopRequested = false;
    QString userMessage = prompt;
    int lastUserStart = prompt.lastIndexOf("<start_of_turn>user\n");
    if (lastUserStart >= 0) {
        int contentStart = lastUserStart + QString("<start_of_turn>user\n").length();
        int contentEnd = prompt.indexOf("<end_of_turn>", contentStart);
        if (contentEnd > contentStart)
            userMessage = prompt.mid(contentStart, contentEnd - contentStart).trimmed();
    }

    QMetaObject::invokeMethod(this, [this, userMessage, imagePath]() {
        doGenerate(userMessage, imagePath);
    }, Qt::QueuedConnection);
}

void LiteRTBackend::generateWithAudio(const QString &prompt, const QString &audioPath)
{
    m_stopRequested = false;
    QString userMessage = prompt;
    int lastUserStart = prompt.lastIndexOf("<start_of_turn>user\n");
    if (lastUserStart >= 0) {
        int contentStart = lastUserStart + QString("<start_of_turn>user\n").length();
        int contentEnd = prompt.indexOf("<end_of_turn>", contentStart);
        if (contentEnd > contentStart)
            userMessage = prompt.mid(contentStart, contentEnd - contentStart).trimmed();
    }

    QMetaObject::invokeMethod(this, [this, userMessage, audioPath]() {
        doGenerate(userMessage, "", audioPath);
    }, Qt::QueuedConnection);
}

void LiteRTBackend::stop()
{
    m_stopRequested = true;
#ifndef RESONALENS_HAS_LITERT
    if (m_process && m_process->state() != QProcess::NotRunning)
        m_process->kill();
#endif
}

// ─────────────────────────────────────────────────────────────────────
// Tool calling (C++ API only)
// ─────────────────────────────────────────────────────────────────────

void LiteRTBackend::sendToolResult(const QString &toolName, const QVariantMap &result)
{
#ifdef RESONALENS_HAS_LITERT
    QMetaObject::invokeMethod(this, [this, toolName, result]() {
        if (!m_conversation) {
            emit errorOccurred("No active conversation for tool result");
            emit generationComplete();
            return;
        }

        QJsonDocument doc = QJsonDocument::fromVariant(QVariant(result));
        auto content = json::parse(doc.toJson().toStdString(), nullptr, false);
        json toolMessage = {{"role", "tool"}, {"content", content}};

        auto response = m_conversation->SendMessage(toolMessage);
        if (!response.ok()) {
            emit errorOccurred("Failed to send tool result");
            emit generationComplete();
            return;
        }

        auto &msg = *response;
        if (std::holds_alternative<json>(msg)) {
            json responseJson = std::get<json>(msg);

            if (responseJson.contains("tool_calls") &&
                responseJson["tool_calls"].is_array() &&
                !responseJson["tool_calls"].empty()) {
                auto &tc = responseJson["tool_calls"][0]["function"];
                QString name = QString::fromStdString(tc["name"].get<std::string>());
                QJsonDocument argsDoc = QJsonDocument::fromJson(
                    QByteArray::fromStdString(tc["arguments"].dump()));
                emit toolCallRequested(name, argsDoc.toVariant().toMap());
                return;
            }

            if (responseJson.contains("content") && responseJson["content"].is_array()) {
                for (auto &item : responseJson["content"]) {
                    if (item.contains("text")) {
                        QString text = QString::fromStdString(item["text"].get<std::string>());
                        emit tokenGenerated(text);
                    }
                }
            }
        }

        emit generationComplete();
    }, Qt::QueuedConnection);
#else
    Q_UNUSED(toolName)
    Q_UNUSED(result)
    emit generationComplete();
#endif
}

// ─────────────────────────────────────────────────────────────────────
// C++ API generation — persistent conversation, only sends new message
// ─────────────────────────────────────────────────────────────────────

void LiteRTBackend::doGenerate(const QString &userMessage, const QString &imagePath,
                                const QString &audioPath)
{
    if (!m_modelLoaded) {
        emit errorOccurred("No model loaded");
        emit generationComplete();
        return;
    }

#ifdef RESONALENS_HAS_LITERT
    if (!m_conversation) {
        emit errorOccurred("No active conversation");
        emit generationComplete();
        return;
    }

    qInfo() << "LiteRT generating (C++ API," << m_accelerator << "):" << userMessage.left(80);

    json content = json::array();

    if (!imagePath.isEmpty())
        content.push_back({{"type", "image"}, {"path", imagePath.toStdString()}});
    if (!audioPath.isEmpty())
        content.push_back({{"type", "audio"}, {"path", audioPath.toStdString()}});
    content.push_back({{"type", "text"}, {"text", userMessage.toStdString()}});

    json inputMessage = {{"role", "user"}, {"content", content}};

    std::atomic<bool> done{false};
    json toolCalls;

    auto callback = [this, &done, &toolCalls](absl::StatusOr<litert::lm::Message> message) {
        if (!message.ok()) { done = true; return; }
        if (!std::holds_alternative<json>(*message)) return;
        json msgJson = std::get<json>(*message);
        if (msgJson.is_null()) { done = true; return; }

        if (msgJson.contains("content") && msgJson["content"].is_array()) {
            for (auto &item : msgJson["content"]) {
                if (item.contains("text")) {
                    QString text = QString::fromStdString(item["text"].get<std::string>());
                    emit tokenGenerated(text);
                }
            }
        }

        if (msgJson.contains("tool_calls") &&
            msgJson["tool_calls"].is_array() &&
            !msgJson["tool_calls"].empty()) {
            for (auto &tc : msgJson["tool_calls"])
                toolCalls.push_back(tc);
        }
    };

    auto status = m_conversation->SendMessageAsync(inputMessage, std::move(callback));
    if (!status.ok()) {
        emit errorOccurred("Failed to send message");
        emit generationComplete();
        return;
    }

    m_engine->WaitUntilDone(absl::Seconds(120));
    m_turnCount++;

    if (!toolCalls.empty() && !m_stopRequested) {
        auto &tc = toolCalls[0]["function"];
        QString name = QString::fromStdString(tc["name"].get<std::string>());
        QJsonDocument argsDoc = QJsonDocument::fromJson(
            QByteArray::fromStdString(tc["arguments"].dump()));
        emit toolCallRequested(name, argsDoc.toVariant().toMap());
        return;
    }

    emit generationComplete();

#else
    doGenerateWithCLI(userMessage, imagePath);
#endif
}

// ─────────────────────────────────────────────────────────────────────
// CLI fallback — spawns process per message (litert_lm_main doesn't
// support interactive stdin mode). NPU auto-detect still applies.
// ─────────────────────────────────────────────────────────────────────

void LiteRTBackend::doGenerateWithCLI(const QString &userMessage, const QString &imagePath)
{
#ifndef RESONALENS_HAS_LITERT
    if (m_binaryPath.isEmpty()) {
        emit errorOccurred("LiteRT-LM binary not found");
        emit generationComplete();
        return;
    }


    // Clean up previous process
    if (m_process) {
        if (m_process->state() != QProcess::NotRunning) {
            m_process->kill();
            m_process->waitForFinished(3000);
        }
        m_process->deleteLater();
        m_process = nullptr;
    }

    m_process = new QProcess(this);

    // Set LD_LIBRARY_PATH
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QString libDir = QFileInfo(m_binaryPath).absolutePath();
    QString existingLdPath = env.value("LD_LIBRARY_PATH");
    env.insert("LD_LIBRARY_PATH", libDir + (existingLdPath.isEmpty() ? "" : ":" + existingLdPath));
    m_process->setProcessEnvironment(env);
    m_process->setProcessChannelMode(QProcess::SeparateChannels);

    connect(m_process, &QProcess::readyReadStandardOutput, this, [this]() {
        if (!m_process || m_stopRequested)
            return;
        QByteArray data = m_process->readAllStandardOutput();
        QString text = QString::fromUtf8(data);

        if (!m_echoFinished) {
            m_echoBuffer += text;

            QString lastPromptLine;
            QStringList promptLines = m_lastPromptSent.split('\n', Qt::SkipEmptyParts);
            if (!promptLines.isEmpty())
                lastPromptLine = promptLines.last().trimmed();

            if (lastPromptLine.isEmpty()) {
                m_echoFinished = true;
                text = m_echoBuffer;
                m_echoBuffer.clear();
            } else {
                int echoEnd = m_echoBuffer.lastIndexOf(lastPromptLine);
                if (echoEnd < 0)
                    return;

                echoEnd += lastPromptLine.length();
                int nl = m_echoBuffer.indexOf('\n', echoEnd);
                if (nl >= 0)
                    text = m_echoBuffer.mid(nl + 1);
                else
                    text = m_echoBuffer.mid(echoEnd);
                m_echoBuffer.clear();
                m_echoFinished = true;
            }

            if (text.isEmpty())
                return;
        }

        QStringList lines = text.split('\n');
        for (const QString &line : lines) {
            QString trimmed = line.trimmed();
            if (trimmed.isEmpty()) continue;
            if (trimmed.startsWith("BenchmarkInfo:")) continue;
            if (trimmed.startsWith("Init ") || trimmed.startsWith("- Init")) continue;
            if (trimmed.startsWith("Prefill ") || trimmed.startsWith("Decode ")) continue;
            if (trimmed.startsWith("TextToTokenIds")) continue;
            if (trimmed.startsWith("Time to first")) continue;
            if (trimmed.contains("tokens/sec")) continue;
            if (trimmed.startsWith("Turn ")) continue;
            if (trimmed.startsWith("--") && trimmed.count('-') > 5) continue;
            if (trimmed.contains("dlopen")) continue;
            if (trimmed.contains("OpenCL") || trimmed.contains("OpenCl")) continue;
            if (trimmed.contains("loaded") && trimmed.contains("library")) continue;
            if (trimmed.startsWith("INFO:") || trimmed.startsWith("WARNING:")) continue;
            if (trimmed.startsWith("I ") && trimmed.contains(".cc:")) continue;
            if (trimmed.startsWith("W ") && trimmed.contains(".cc:")) continue;
            if (trimmed.contains("accelerator") && trimmed.contains("plugin")) continue;
            if (trimmed.contains("GPU") && (trimmed.contains("init") || trimmed.contains("found"))) continue;
            if (trimmed.contains("NPU") && (trimmed.contains("init") || trimmed.contains("found"))) continue;
            if (trimmed.contains("WebGpu") || trimmed.contains("Vulkan")) continue;
            emit tokenGenerated(line);
        }
    });

    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus status) {
        Q_UNUSED(exitCode)
        if (m_process) {
            QByteArray remaining = m_process->readAllStandardOutput();
            if (!remaining.isEmpty() && m_echoFinished) {
                QString text = QString::fromUtf8(remaining).trimmed();
                QStringList lines = text.split('\n');
                for (const QString &line : lines) {
                    QString t = line.trimmed();
                    if (t.isEmpty()) continue;
                    if (t.startsWith("BenchmarkInfo:") || t.startsWith("Init ")
                        || t.startsWith("- Init") || t.startsWith("Prefill ")
                        || t.startsWith("Decode ") || t.startsWith("TextToTokenIds")
                        || t.startsWith("Time to first") || t.contains("tokens/sec")
                        || t.startsWith("Turn ") || (t.startsWith("--") && t.count('-') > 5)
                        || t.contains("dlopen") || t.contains("OpenCL") || t.contains("OpenCl")
                        || (t.contains("loaded") && t.contains("library"))
                        || t.startsWith("INFO:") || t.startsWith("WARNING:")
                        || (t.startsWith("I ") && t.contains(".cc:"))
                        || (t.startsWith("W ") && t.contains(".cc:"))
                        || (t.contains("accelerator") && t.contains("plugin"))
                        || (t.contains("GPU") && (t.contains("init") || t.contains("found")))
                        || (t.contains("NPU") && (t.contains("init") || t.contains("found")))
                        || t.contains("WebGpu") || t.contains("Vulkan"))
                        continue;
                    emit tokenGenerated(line);
                }
            }
        }
        if (!m_stopRequested && (status == QProcess::CrashExit || exitCode != 0)) {
            QString stderrMsg;
            if (m_process) {
                QString stderrText = QString::fromUtf8(m_process->readAllStandardError());
                qWarning() << "LiteRT CLI stderr:" << stderrText.left(500);
                for (const QString &line : stderrText.split('\n')) {
                    if (line.contains("Check failed:") || line.contains("INVALID_ARGUMENT")
                        || line.contains("NOT_FOUND") || line.contains("UNIMPLEMENTED")
                        || line.contains("vision") || line.contains("image")
                        || line.contains("preprocessor")) {
                        stderrMsg = line.trimmed();
                        int bracket = stderrMsg.lastIndexOf("] ");
                        if (bracket >= 0)
                            stderrMsg = stderrMsg.mid(bracket + 2);
                        break;
                    }
                }
            }
            QString reason = stderrMsg.isEmpty() ? "LiteRT-LM process crashed" : stderrMsg;
            emit errorOccurred("Model failed to load: " + reason);
        }
        emit generationComplete();
    });

    m_echoFinished = false;
    m_echoBuffer.clear();

    QStringList args;
    QString program;

#ifdef Q_OS_ANDROID
    program = "/system/bin/linker64";
    args << m_binaryPath;
#else
    program = m_binaryPath;
#endif

    // LiteRT models have a 4096-token context window.
    // Reserve ~512 tokens for response, leaving ~3584 for prompt.
    static const int kModelContextTokens = 4096;
    static const int kReservedForGeneration = 512;
    static const int kMaxPromptTokens = kModelContextTokens - kReservedForGeneration;
    static const int kMaxPromptChars = kMaxPromptTokens * 3;
    QString truncatedPrompt = userMessage;
    if (truncatedPrompt.length() > kMaxPromptChars) {
        truncatedPrompt = truncatedPrompt.right(kMaxPromptChars);
        int firstUser = truncatedPrompt.indexOf("User:");
        if (firstUser > 0)
            truncatedPrompt = truncatedPrompt.mid(firstUser);
    }

    m_lastPromptSent = truncatedPrompt;

    args << "--backend=" + m_accelerator
         << "--model_path=" + m_modelPath
         << "--input_prompt=" + truncatedPrompt;

    if (!imagePath.isEmpty())
        args << "--image_path=" + imagePath;

    qInfo() << "Starting LiteRT CLI:" << userMessage.left(80)
            << "backend:" << m_accelerator;
    m_process->start(program, args);

    if (!m_process->waitForStarted(10000)) {
        emit errorOccurred("Failed to start LiteRT-LM: " + m_process->errorString());
        emit generationComplete();
    }
#else
    Q_UNUSED(userMessage)
    Q_UNUSED(imagePath)
#endif
}

// Stubs for persistent process methods (not used in current implementation)
bool LiteRTBackend::startPersistentProcess() { return false; }
void LiteRTBackend::stopPersistentProcess() {}
bool LiteRTBackend::isPersistentProcessRunning() const { return false; }
