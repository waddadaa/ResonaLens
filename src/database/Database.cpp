#include "Database.h"

#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QFile>
#include <QDir>

Database& Database::instance()
{
    static Database instance;
    return instance;
}

bool Database::initialize(const QString &dbPath)
{
    if (m_initialized)
        return true;

    m_dbPath = dbPath;
    m_db = QSqlDatabase::addDatabase("QSQLITE");
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        qCritical() << "Failed to open database:" << m_db.lastError().text();
        return false;
    }

    // Enable WAL mode for better concurrent performance
    QSqlQuery query(m_db);
    if (!query.exec("PRAGMA journal_mode=WAL"))
        qWarning() << "PRAGMA journal_mode=WAL failed:" << query.lastError().text();
    if (!query.exec("PRAGMA foreign_keys=ON"))
        qWarning() << "PRAGMA foreign_keys=ON failed:" << query.lastError().text();

    if (!runMigrations()) {
        qCritical() << "Failed to run database migrations";
        return false;
    }

    m_initialized = true;
    qInfo() << "Database initialized at" << dbPath;
    return true;
}

QSqlDatabase Database::db()
{
    return m_db;
}

bool Database::runMigrations()
{
    // Create migration tracking table
    executeSql("CREATE TABLE IF NOT EXISTS migrations ("
               "id INTEGER PRIMARY KEY AUTOINCREMENT,"
               "name TEXT NOT NULL UNIQUE,"
               "applied_at TEXT NOT NULL DEFAULT (datetime('now'))"
               ")");

    // Check if initial migration has been applied
    QSqlQuery check(m_db);
    check.prepare("SELECT COUNT(*) FROM migrations WHERE name = ?");
    check.addBindValue("001_initial");
    if (!check.exec()) {
        qCritical() << "Migration lookup (001) failed:" << check.lastError().text();
        return false;
    }
    if (!check.next()) {
        qCritical() << "Migration lookup (001) produced no row";
        return false;
    }

    if (check.value(0).toInt() == 0) {
        qInfo() << "Applying migration: 001_initial";

        const QString sql = R"(
            CREATE TABLE IF NOT EXISTS conversations (
                id          TEXT PRIMARY KEY,
                title       TEXT NOT NULL,
                model_id    TEXT,
                is_pinned   INTEGER DEFAULT 0,
                created_at  TEXT NOT NULL,
                updated_at  TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS messages (
                id                TEXT PRIMARY KEY,
                conversation_id   TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
                role              TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
                content           TEXT NOT NULL,
                type              TEXT NOT NULL CHECK (type IN ('text', 'image', 'audio', 'document')),
                file_path         TEXT,
                token_count       INTEGER DEFAULT 0,
                generation_time_ms INTEGER DEFAULT 0,
                created_at        TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_messages_conversation
                ON messages(conversation_id);

            CREATE TABLE IF NOT EXISTS models (
                id            TEXT PRIMARY KEY,
                hf_repo_id    TEXT NOT NULL,
                name          TEXT NOT NULL,
                filename      TEXT NOT NULL,
                file_path     TEXT NOT NULL,
                size_bytes    INTEGER NOT NULL,
                model_type    TEXT NOT NULL DEFAULT 'llm' CHECK (model_type IN ('llm', 'tts', 'stt')),
                quantization  TEXT,
                capabilities  TEXT NOT NULL DEFAULT '["text"]',
                is_active     INTEGER DEFAULT 0,
                downloaded_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS knowledge_items (
                id          TEXT PRIMARY KEY,
                title       TEXT NOT NULL,
                source_type TEXT NOT NULL CHECK (source_type IN ('note', 'document', 'link', 'markdown', 'webpage', 'paper')),
                source_path TEXT,
                created_at  TEXT NOT NULL,
                updated_at  TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS knowledge_chunks (
                id          TEXT PRIMARY KEY,
                item_id     TEXT NOT NULL REFERENCES knowledge_items(id) ON DELETE CASCADE,
                content     TEXT NOT NULL,
                heading     TEXT,
                page_number INTEGER,
                chunk_index INTEGER NOT NULL,
                token_count INTEGER DEFAULT 0
            );

            CREATE INDEX IF NOT EXISTS idx_chunks_item
                ON knowledge_chunks(item_id);

            CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts USING fts5(
                content,
                heading,
                content='knowledge_chunks',
                content_rowid='rowid'
            );

            CREATE TABLE IF NOT EXISTS settings (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
        )";

        // Execute statements one by one (SQLite doesn't support multiple in one exec)
        const QStringList statements = sql.split(';', Qt::SkipEmptyParts);
        for (const QString &stmt : statements) {
            QString trimmed = stmt.trimmed();
            if (trimmed.isEmpty())
                continue;
            if (!executeSql(trimmed)) {
                return false;
            }
        }

        // Record migration
        QSqlQuery record(m_db);
        record.prepare("INSERT INTO migrations (name) VALUES (?)");
        record.addBindValue("001_initial");
        if (!record.exec()) {
            qCritical() << "Failed to record migration:" << record.lastError().text();
            return false;
        }

        // Insert default settings
        executeSql("INSERT OR IGNORE INTO settings (key, value) VALUES ('temperature', '0.7')");
        executeSql("INSERT OR IGNORE INTO settings (key, value) VALUES ('top_p', '0.9')");
        executeSql("INSERT OR IGNORE INTO settings (key, value) VALUES ('max_tokens', '2048')");
        executeSql("INSERT OR IGNORE INTO settings (key, value) VALUES ('theme', '\"light\"')");
        executeSql("INSERT OR IGNORE INTO settings (key, value) VALUES ('tts_speed', '1.0')");
        executeSql("INSERT OR IGNORE INTO settings (key, value) VALUES ('tts_auto_speak', 'false')");
        executeSql("INSERT OR IGNORE INTO settings (key, value) VALUES ('tts_voice', '\"af_heart\"')");
        executeSql("INSERT OR IGNORE INTO settings (key, value) VALUES ('hf_token', '\"\"')");
    }

    // Migration 002: drop chunk/FTS tables, add md_path to knowledge_items
    QSqlQuery check002(m_db);
    check002.prepare("SELECT COUNT(*) FROM migrations WHERE name = ?");
    check002.addBindValue("002_markdown_store");
    if (!check002.exec() || !check002.next()) {
        qCritical() << "Migration lookup (002) failed:" << check002.lastError().text();
        return false;
    }

    if (check002.value(0).toInt() == 0) {
        qInfo() << "Applying migration: 002_markdown_store";

        // Disable foreign keys while dropping tables that may be referenced by FTS5
        executeSql("PRAGMA foreign_keys=OFF");
        executeSql("DROP TABLE IF EXISTS knowledge_fts");
        executeSql("DROP TABLE IF EXISTS knowledge_chunks");
        executeSql("PRAGMA foreign_keys=ON");

        // Add md_path column — log but don't fail if it already exists (idempotent).
        QSqlQuery altQ(m_db);
        if (!altQ.exec("ALTER TABLE knowledge_items ADD COLUMN md_path TEXT DEFAULT ''"))
            qInfo() << "md_path column already present (expected on upgrade):"
                    << altQ.lastError().text();

        QSqlQuery record002(m_db);
        record002.prepare("INSERT INTO migrations (name) VALUES (?)");
        record002.addBindValue("002_markdown_store");
        if (!record002.exec()) {
            qCritical() << "Failed to record migration 002:" << record002.lastError().text();
            return false;
        }

        qInfo() << "Migration 002 applied: knowledge_chunks and knowledge_fts dropped, md_path added";
    }

    // Migration 003: add is_pinned to knowledge_items
    QSqlQuery check003(m_db);
    check003.prepare("SELECT COUNT(*) FROM migrations WHERE name = ?");
    check003.addBindValue("003_pinned_flag");
    if (!check003.exec() || !check003.next()) {
        qCritical() << "Migration lookup (003) failed:" << check003.lastError().text();
        return false;
    }

    if (check003.value(0).toInt() == 0) {
        qInfo() << "Applying migration: 003_pinned_flag";
        QSqlQuery altQ(m_db);
        if (!altQ.exec("ALTER TABLE knowledge_items ADD COLUMN is_pinned INTEGER DEFAULT 0"))
            qInfo() << "is_pinned column already present:" << altQ.lastError().text();

        QSqlQuery record003(m_db);
        record003.prepare("INSERT INTO migrations (name) VALUES (?)");
        record003.addBindValue("003_pinned_flag");
        if (!record003.exec()) {
            qCritical() << "Failed to record migration 003:" << record003.lastError().text();
            return false;
        }
        qInfo() << "Migration 003 applied: is_pinned added";
    }

    // Ensure md_path column exists even if migration 002 partially failed on older DBs
    {
        QSqlQuery colCheck(m_db);
        if (!colCheck.exec("PRAGMA table_info(knowledge_items)")) {
            qCritical() << "PRAGMA table_info failed:" << colCheck.lastError().text();
            return false;
        }
        bool hasMdPath = false;
        while (colCheck.next()) {
            if (colCheck.value(1).toString() == "md_path") { hasMdPath = true; break; }
        }
        if (!hasMdPath) {
            if (!executeSql("ALTER TABLE knowledge_items ADD COLUMN md_path TEXT DEFAULT ''"))
                return false;
            qInfo() << "Added missing md_path column to knowledge_items";
        }
    }

    return true;
}

bool Database::executeSql(const QString &sql)
{
    QSqlQuery query(m_db);
    if (!query.exec(sql)) {
        qCritical() << "SQL error:" << query.lastError().text() << "\nQuery:" << sql.left(200);
        return false;
    }
    return true;
}
