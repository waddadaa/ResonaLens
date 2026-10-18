#include "FileProcessor.h"

#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QProcess>
#include <QDebug>

FileProcessor::FileProcessor(QObject *parent)
    : QObject(parent)
{
}

QString FileProcessor::processFile(const QString &filePath)
{
    QFileInfo fi(filePath);
    if (!fi.exists()) {
        qWarning() << "FileProcessor: file does not exist:" << filePath;
        return {};
    }

    QString suffix = fi.suffix().toLower();

    if (suffix == "pdf")
        return processPdf(filePath);
    else if (suffix == "md" || suffix == "markdown")
        return processMarkdown(filePath);
    else
        return processPlainText(filePath);
}

QStringList FileProcessor::supportedFormats() const
{
    return {"pdf", "md", "markdown", "txt", "text", "html", "htm"};
}

QString FileProcessor::processPdf(const QString &filePath)
{
    // Use pdftotext (poppler-utils) for text extraction
    QProcess process;
    process.start("pdftotext", {"-layout", "-enc", "UTF-8", filePath, "-"});

    if (!process.waitForStarted(5000)) {
        // It may not have launched OR may still be starting — kill it so we
        // don't leave an orphan if the binary is slow to appear.
        process.kill();
        process.waitForFinished(500);
        qWarning() << "pdftotext not found. Install poppler-utils.";
        // Fallback: try reading as raw text (won't work well for PDFs)
        return processPlainText(filePath);
    }

    if (!process.waitForFinished(30000)) {
        process.kill();
        process.waitForFinished(1000);
        qWarning() << "pdftotext timed out for:" << filePath;
        return "Error: PDF text extraction timed out.";
    }

    if (process.exitCode() != 0) {
        QString err = QString::fromUtf8(process.readAllStandardError());
        qWarning() << "pdftotext error:" << err;
        return "Error extracting PDF text: " + err;
    }

    QString text = QString::fromUtf8(process.readAllStandardOutput());

    // Clean up excessive whitespace
    text = text.trimmed();

    qInfo() << "Extracted" << text.length() << "chars from PDF:" << filePath;
    return text;
}

QString FileProcessor::processMarkdown(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Cannot open file:" << filePath;
        return {};
    }
    QTextStream stream(&file);
    return stream.readAll();
}

QString FileProcessor::processPlainText(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Cannot open file:" << filePath;
        return {};
    }
    QTextStream stream(&file);
    return stream.readAll();
}
