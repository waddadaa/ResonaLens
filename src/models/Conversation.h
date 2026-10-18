#pragma once

#include <QObject>
#include <QString>
#include <QDateTime>

struct Conversation {
    Q_GADGET
    Q_PROPERTY(QString id MEMBER id)
    Q_PROPERTY(QString title MEMBER title)
    Q_PROPERTY(QString modelId MEMBER modelId)
    Q_PROPERTY(bool isPinned MEMBER isPinned)
    Q_PROPERTY(QString createdAt MEMBER createdAt)
    Q_PROPERTY(QString updatedAt MEMBER updatedAt)

public:
    QString id;
    QString title;
    QString modelId;
    bool isPinned = false;
    QString createdAt;
    QString updatedAt;
};
Q_DECLARE_METATYPE(Conversation)
