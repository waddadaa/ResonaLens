#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <functional>

#include "DocumentNavigator.h"

class KnowledgeReader : public QObject {
    Q_OBJECT
public:
    struct ResultItem {
        QString source;       // filename (not full path)
        QString content;      // extracted text
        double  confidence;   // 1.0 for any accepted result
        int     tokenCount;
    };

    // generator: callable that wraps LlamaBackend::generateSync or a test stub.
    // Signature: (prompt, maxTokens) -> response string
    using Generator = std::function<QString(const QString&, int)>;

    explicit KnowledgeReader(Generator generator, QObject *parent = nullptr);

    // Execute per-file extraction for the given files and query.
    // contextBudget: available tokens (from SettingsController::contextSize()).
    // Returns formatted string ready to inject as skill result.
    QString execute(const QStringList &filePaths,
                    const QString     &query,
                    int                contextBudget);

signals:
    void progress(int filesProcessed, int filesTotal);

private:
    ResultItem processStructured(const QString &filePath, const QString &query);
    ResultItem processFlat(const QString &filePath, const QString &query);
    QString    synthesize(const QList<ResultItem> &results, const QString &query);
    QString    pack(const QList<ResultItem> &results, int tokenBudget);
    static int estimateTokens(const QString &text) { return text.size() / 4; }

    Generator          m_generator;
    DocumentNavigator  m_navigator;
};
