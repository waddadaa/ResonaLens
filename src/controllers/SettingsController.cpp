#include "SettingsController.h"
#include "database/Database.h"

#include <QSqlQuery>
#include <QSqlError>
#include <QJsonDocument>
#include <QJsonValue>
#include <QDir>
#include <QDirIterator>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QPointer>
#include <QRegularExpression>
#include <QtConcurrent>
#include <QDebug>

SettingsController::SettingsController(QObject *parent)
    : QObject(parent)
{
    // Load settings from database
    m_temperature = getSetting("temperature", 0.7).toDouble();
    m_topP = getSetting("top_p", 0.9).toDouble();
    m_maxTokens = getSetting("max_tokens", 2048).toInt();
    m_theme = getSetting("theme", "light").toString();
    m_ttsSpeed = getSetting("tts_speed", 1.0).toDouble();
    m_ttsAutoSpeak = getSetting("tts_auto_speak", false).toBool();
    m_ttsVoice = getSetting("tts_voice", "af_heart").toString();
    m_ttsEnabled = getSetting("tts_enabled", false).toBool();
    m_hfToken = getSetting("hf_token", "").toString();

    refreshStorage();
}

double SettingsController::temperature() const { return m_temperature; }
double SettingsController::topP() const { return m_topP; }
int SettingsController::maxTokens() const { return m_maxTokens; }
QString SettingsController::theme() const { return m_theme; }
qint64 SettingsController::modelsStorageUsed() const { return m_modelsStorage; }
qint64 SettingsController::chatStorageUsed() const { return m_chatStorage; }
qint64 SettingsController::knowledgeStorageUsed() const { return m_knowledgeStorage; }
bool SettingsController::hasHfToken() const { return !m_hfToken.isEmpty(); }
QString SettingsController::hfToken() const { return m_hfToken; }
bool SettingsController::hfTokenValid() const { return m_hfTokenValid; }
double SettingsController::ttsSpeed() const { return m_ttsSpeed; }
bool SettingsController::ttsAutoSpeak() const { return m_ttsAutoSpeak; }
QString SettingsController::ttsVoice() const { return m_ttsVoice; }
bool SettingsController::ttsEnabled() const { return m_ttsEnabled; }

void SettingsController::setSetting(const QString &key, const QVariant &value)
{
    if (key == "temperature") {
        m_temperature = value.toDouble();
    } else if (key == "top_p") {
        m_topP = value.toDouble();
    } else if (key == "max_tokens") {
        m_maxTokens = value.toInt();
    } else if (key == "theme") {
        m_theme = value.toString();
    } else if (key == "tts_speed") {
        m_ttsSpeed = value.toDouble();
    } else if (key == "tts_auto_speak") {
        m_ttsAutoSpeak = value.toBool();
    } else if (key == "tts_voice") {
        m_ttsVoice = value.toString();
    } else if (key == "tts_enabled") {
        m_ttsEnabled = value.toBool();
    }

    storeSetting(key, value);
    emit settingsChanged();
}

void SettingsController::setHfToken(const QString &token)
{
    m_hfToken = token;
    storeSetting("hf_token", token);
    emit hfTokenChanged();
}

void SettingsController::validateHfToken()
{
    // Format-only validation. A real roundtrip (HTTP whoami-v2) lives on
    // HuggingFaceApi::validateToken — wire that in if/when we want network
    // confirmation from Settings. A valid HF token is `hf_` followed by
    // ~37 characters of base-62.
    static const QRegularExpression re(QStringLiteral("^hf_[A-Za-z0-9]{20,}$"));
    m_hfTokenValid = re.match(m_hfToken).hasMatch();
    emit hfTokenChanged();
    emit hfTokenValidated(m_hfTokenValid);
}

void SettingsController::clearCache()
{
    QString dataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir cacheDir(dataPath + "/cache");
    if (cacheDir.exists()) {
        cacheDir.removeRecursively();
    }
    refreshStorage();
}

void SettingsController::clearHistory()
{
    QSqlQuery query(Database::instance().db());
    if (!query.exec("DELETE FROM messages"))
        qWarning() << "clearHistory: DELETE messages failed:" << query.lastError().text();
    if (!query.exec("DELETE FROM conversations"))
        qWarning() << "clearHistory: DELETE conversations failed:" << query.lastError().text();
    refreshStorage();
}

void SettingsController::refreshStorage()
{
    // QSqlDatabase is not safe to share across threads — the connection
    // belongs to the thread that opened it (the main/GUI thread). Pull the
    // row counts *here* on that thread, then hand only plain ints and the
    // directory path to the worker thread for the disk walk.
    qint64 dbMessagesCount = 0;
    qint64 dbChunksCount = 0;
    qint64 dbSize = 0;

    const QString dataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QFileInfo dbInfo(dataPath + "/resonalens.db");
    if (dbInfo.exists()) {
        dbSize = dbInfo.size();
        QSqlQuery query(Database::instance().db());
        if (query.exec("SELECT COUNT(*) FROM messages") && query.next())
            dbMessagesCount = query.value(0).toLongLong();
        else if (query.lastError().isValid())
            qWarning() << "refreshStorage: messages count failed:" << query.lastError().text();

        if (query.exec("SELECT COUNT(*) FROM knowledge_chunks") && query.next())
            dbChunksCount = query.value(0).toLongLong();
        else if (query.lastError().isValid())
            qWarning() << "refreshStorage: knowledge_chunks count failed:" << query.lastError().text();
    }

    // Run expensive disk iteration off the main thread (no DB access here).
    QPointer<SettingsController> self(this);
    QtConcurrent::run([self, dataPath, dbMessagesCount, dbChunksCount, dbSize]() {
        qint64 modelsStorage = 0;
        QDirIterator modelsIt(dataPath + "/models", QDirIterator::Subdirectories);
        while (modelsIt.hasNext()) {
            modelsIt.next();
            modelsStorage += modelsIt.fileInfo().size();
        }

        qint64 chatStorage = 0;
        qint64 knowledgeStorage = 0;
        const qint64 total = dbMessagesCount + dbChunksCount;
        if (total > 0 && dbSize > 0) {
            chatStorage = dbSize * dbMessagesCount / total;
            knowledgeStorage = dbSize * dbChunksCount / total;
        }

        QMetaObject::invokeMethod(qApp, [self, modelsStorage, chatStorage, knowledgeStorage]() {
            if (!self) return;  // controller was destroyed before we returned
            self->m_modelsStorage = modelsStorage;
            self->m_chatStorage = chatStorage;
            self->m_knowledgeStorage = knowledgeStorage;
            emit self->storageChanged();
        }, Qt::QueuedConnection);
    });
}

QVariant SettingsController::getSetting(const QString &key, const QVariant &defaultValue) const
{
    QSqlQuery query(Database::instance().db());
    query.prepare("SELECT value FROM settings WHERE key = ?");
    query.addBindValue(key);

    if (query.exec() && query.next()) {
        QString jsonStr = query.value(0).toString();
        QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
        if (!doc.isNull()) {
            return doc.toVariant();
        }
        return QVariant(jsonStr);
    }
    return defaultValue;
}

void SettingsController::storeSetting(const QString &key, const QVariant &value)
{
    QJsonDocument doc = QJsonDocument::fromVariant(value);
    QString jsonStr = doc.isNull() ? value.toString() : QString::fromUtf8(doc.toJson(QJsonDocument::Compact));

    QSqlQuery query(Database::instance().db());
    query.prepare("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)");
    query.addBindValue(key);
    query.addBindValue(jsonStr);

    if (!query.exec()) {
        qWarning() << "Failed to store setting" << key << ":" << query.lastError().text();
    }
}
