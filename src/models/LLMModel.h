#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

struct LLMModel {
    Q_GADGET
    Q_PROPERTY(QString id MEMBER id)
    Q_PROPERTY(QString hfRepoId MEMBER hfRepoId)
    Q_PROPERTY(QString name MEMBER name)
    Q_PROPERTY(QString filename MEMBER filename)
    Q_PROPERTY(QString filePath MEMBER filePath)
    Q_PROPERTY(qint64 sizeBytes MEMBER sizeBytes)
    Q_PROPERTY(QString modelType MEMBER modelType)
    Q_PROPERTY(QString quantization MEMBER quantization)
    Q_PROPERTY(QString capabilities MEMBER capabilities)
    Q_PROPERTY(bool isActive MEMBER isActive)
    Q_PROPERTY(QString downloadedAt MEMBER downloadedAt)

public:
    QString id;
    QString hfRepoId;
    QString name;
    QString filename;
    QString filePath;
    qint64 sizeBytes = 0;
    QString modelType = "llm";  // "llm", "tts", "stt"
    QString quantization;
    QString capabilities = "[\"text\"]";
    bool isActive = false;
    QString downloadedAt;
};
Q_DECLARE_METATYPE(LLMModel)
