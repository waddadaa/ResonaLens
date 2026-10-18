#include "KnowledgeReader.h"
#include "DocumentNavigator.h"

#include <QFileInfo>
#include <QtGlobal>

KnowledgeReader::KnowledgeReader(Generator generator, QObject *parent)
    : QObject(parent)
    , m_generator(std::move(generator))
{}

QString KnowledgeReader::execute(const QStringList &filePaths,
                                  const QString     &query,
                                  int                contextBudget)
{
    QList<ResultItem> results;

    // Process files sequentially (generateSync is not thread-safe with llama.cpp)
    int processed = 0;
    for (const QString &path : filePaths) {
        ResultItem item = m_navigator.isStructured(path)
                        ? processStructured(path, query)
                        : processFlat(path, query);
        if (!item.content.isEmpty())
            results.append(item);
        emit progress(++processed, filePaths.size());
    }

    if (results.isEmpty())
        return QString("No relevant content found for: %1").arg(query);

    if (contextBudget > 8000)
        return synthesize(results, query);
    else
        return pack(results, qMax(0, contextBudget - 1500)); // leave 1500 tokens for LLM answer
}

KnowledgeReader::ResultItem KnowledgeReader::processStructured(const QString &filePath,
                                                                const QString &query)
{
    QStringList tree = m_navigator.headingTree(filePath);
    if (tree.isEmpty())
        return {};

    QString treeStr = tree.join('\n');
    QString selectionPrompt = QString(
        "You are selecting document sections to answer a query.\n"
        "Query: %1\n\n"
        "Document sections:\n%2\n\n"
        "Reply with only the section numbers (e.g. '1,3,5') that are relevant. "
        "If none are relevant, reply 'NONE'."
    ).arg(query, treeStr);

    QString selection = m_generator(selectionPrompt, 64);
    if (selection.trimmed().toUpper() == "NONE" || selection.trimmed().isEmpty())
        return {};

    // Parse selected indices
    QString content;
    for (const QString &part : selection.split(',')) {
        bool ok;
        int idx = part.trimmed().toInt(&ok);
        if (!ok) continue;
        auto section = m_navigator.fetchSection(filePath, idx);
        if (!section.content.isEmpty())
            content += section.content + "\n\n";
        if (estimateTokens(content) > 1500) break; // cap per-file budget
    }

    if (content.trimmed().isEmpty()) return {};

    ResultItem item;
    item.source     = QFileInfo(filePath).fileName();
    item.content    = content.trimmed();
    item.confidence = 1.0;
    item.tokenCount = estimateTokens(item.content);
    return item;
}

KnowledgeReader::ResultItem KnowledgeReader::processFlat(const QString &filePath,
                                                          const QString &query)
{
    int total   = m_navigator.windowCount(filePath, 400);
    QString accumulated;

    for (int i = 0; i < total; ++i) {
        auto window = m_navigator.fetchWindow(filePath, i, 400, 50);
        if (window.content.trimmed().isEmpty()) continue;

        QString prompt = QString(
            "Does this passage answer the query: \"%1\"?\n"
            "If yes, extract the relevant part verbatim.\n"
            "If no, respond exactly: NO\n\n"
            "Passage:\n%2"
        ).arg(query, window.content);

        QString response = m_generator(prompt, 512);
        if (response.trimmed().toUpper() == "NO" || response.trimmed().isEmpty())
            continue;

        accumulated += response.trimmed() + "\n\n";
        if (estimateTokens(accumulated) > 1500) break; // stop early
    }

    if (accumulated.trimmed().isEmpty()) return {};

    ResultItem item;
    item.source     = QFileInfo(filePath).fileName();
    item.content    = accumulated.trimmed();
    item.confidence = 1.0;
    item.tokenCount = estimateTokens(item.content);
    return item;
}

QString KnowledgeReader::synthesize(const QList<ResultItem> &results, const QString &query)
{
    QString sources;
    for (const ResultItem &r : results)
        sources += QString("[%1]\n%2\n\n").arg(r.source, r.content);

    QString prompt = QString(
        "Given these sources, answer the query: \"%1\"\n\n%2"
    ).arg(query, sources);

    return m_generator(prompt, 1024);
}

QString KnowledgeReader::pack(const QList<ResultItem> &results, int tokenBudget)
{
    QString packed;
    int used = 0;
    for (const ResultItem &r : results) {
        if (used + r.tokenCount > tokenBudget) break;
        packed += QString("[%1]\n%2\n\n").arg(r.source, r.content);
        used += r.tokenCount;
    }
    return packed.trimmed();
}
