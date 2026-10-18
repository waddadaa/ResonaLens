#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

class FileProcessor : public QObject {
    Q_OBJECT

public:
    explicit FileProcessor(QObject *parent = nullptr);

    QString processFile(const QString &filePath);
    QStringList supportedFormats() const;

private:
    QString processPdf(const QString &filePath);
    QString processMarkdown(const QString &filePath);
    QString processPlainText(const QString &filePath);
};
