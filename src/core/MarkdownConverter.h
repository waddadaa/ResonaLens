#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

class WebReaderBackend;

class MarkdownConverter : public QObject {
    Q_OBJECT
public:
    explicit MarkdownConverter(WebReaderBackend *webReader = nullptr,
                               QObject *parent = nullptr);

    QString     convert(const QString &inputPath, const QString &outputDir);
    QString     convertUrl(const QString &url, const QString &outputDir);
    QStringList supportedExtensions() const;

signals:
    void conversionProgress(int percent);
    void conversionFailed(const QString &reason);

private:
    QString convertTxt(const QString &path, const QString &outDir);
    QString convertMd(const QString &path, const QString &outDir);
    QString convertCsv(const QString &path, const QString &outDir);
    QString convertHtml(const QString &path, const QString &outDir);
    QString convertPdf(const QString &path, const QString &outDir);
    QString convertDocx(const QString &path, const QString &outDir);
    QString convertXlsx(const QString &path, const QString &outDir);

    QString writeMd(const QString &outDir, const QString &slug,
                    const QString &title, const QString &source,
                    const QString &body);
    QString slugify(const QString &title);

    WebReaderBackend *m_webReader = nullptr;
};
