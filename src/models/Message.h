#pragma once

#include <QObject>
#include <QString>

struct Message {
    Q_GADGET
    Q_PROPERTY(QString id MEMBER id)
    Q_PROPERTY(QString conversationId MEMBER conversationId)
    Q_PROPERTY(QString role MEMBER role)
    Q_PROPERTY(QString content MEMBER content)
    Q_PROPERTY(QString type MEMBER type)
    Q_PROPERTY(QString filePath MEMBER filePath)
    Q_PROPERTY(int tokenCount MEMBER tokenCount)
    Q_PROPERTY(int generationTimeMs MEMBER generationTimeMs)
    Q_PROPERTY(QString createdAt MEMBER createdAt)

public:
    QString id;
    QString conversationId;
    QString role;       // "user", "assistant", "system"
    QString content;
    QString type;       // "text", "image", "audio", "document"
    QString filePath;
    int tokenCount = 0;
    int generationTimeMs = 0;
    QString createdAt;
};
Q_DECLARE_METATYPE(Message)
