#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QString>

class Database {
public:
    static Database& instance();

    bool initialize(const QString &dbPath);
    // NOTE: QSqlDatabase is a lightweight handle — returned by value, but
    // multiple copies share one underlying connection. The connection is
    // owned by the thread that called initialize(); callers on other
    // threads must use QSqlDatabase::cloneDatabase for that thread.
    QSqlDatabase db();

private:
    Database() = default;
    Database(const Database&) = delete;
    Database& operator=(const Database&) = delete;

    bool runMigrations();
    bool executeSql(const QString &sql);

    QSqlDatabase m_db;
    QString m_dbPath;
    bool m_initialized = false;
};
