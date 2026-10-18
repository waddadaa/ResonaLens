#pragma once

#include <QObject>
#include <QString>

struct KnowledgeItem {
    Q_GADGET
    Q_PROPERTY(QString id MEMBER id)
    Q_PROPERTY(QString title MEMBER title)
    Q_PROPERTY(QString sourceType MEMBER sourceType)
    Q_PROPERTY(QString sourcePath MEMBER sourcePath)
    Q_PROPERTY(QString mdPath MEMBER mdPath)
    Q_PROPERTY(bool isPinned MEMBER isPinned)
    Q_PROPERTY(QString createdAt MEMBER createdAt)
    Q_PROPERTY(QString updatedAt MEMBER updatedAt)

public:
    QString id;
    QString title;
    QString sourceType;  // "note", "document", "link", "markdown", "webpage", "paper"
    QString sourcePath;
    QString mdPath;      // added by migration 002 — path to the converted .md
    bool    isPinned = false;  // added by migration 003
    QString createdAt;
    QString updatedAt;
};
Q_DECLARE_METATYPE(KnowledgeItem)
