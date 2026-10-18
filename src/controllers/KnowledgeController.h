#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <QMutex>
#include <QFuture>
#include <QList>
#include <memory>

class MarkdownConverter;
class KnowledgeIndexFile;
class KnowledgeReader;
class LlamaBackend;
class WebReaderBackend;

class KnowledgeController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)
    Q_PROPERTY(bool isConverting READ isConverting NOTIFY isConvertingChanged)

public:
    explicit KnowledgeController(LlamaBackend *llama,
                                  WebReaderBackend *webReader,
                                  QObject *parent = nullptr);
    ~KnowledgeController();

    QVariantList items() const;
    bool isConverting() const;

    // Called by SkillExecutor to retrieve knowledge for a query.
    // Returns formatted context string for injection into prompt.
    QString executeKnowledgeQuery(const QStringList &filenames,
                                   const QString &query,
                                   int contextBudget);

    // Returns system prompt block with KNOWLEDGE_INDEX.md contents.
    QString knowledgeSystemPrompt() const;

public slots:
    void addNote(const QString &title, const QString &content);
    void addFile(const QString &filePath);
    void addLink(const QString &url, const QString &title = "");
    void deleteItem(const QString &itemId);
    void setPinned(const QString &itemId, bool pinned);
    QVariantList search(const QString &query, int topK = 5);
    void refresh();

    // Returns the most query-relevant sections from all pinned items.
    // Pass the user's last message so keyword scoring finds the right sections.
    QString pinnedDocumentsContext(const QString &query = {}) const;

signals:
    void conversionComplete();
    void itemsChanged();
    void isConvertingChanged();

private:
    void    loadItems();
    QString knowledgeDir() const;
    QString addItemRecord(const QString &title, const QString &sourceType,
                          const QString &mdPath, const QString &sourcePath = "");
    void    generateAndAddToIndex(const QString &filename, const QString &mdPath);
    void    reconcileOnStartup();

    QVariantList      m_items;
    int               m_activeConversions = 0;
    mutable QMutex    m_indexMutex;

    // Track outstanding background jobs so the destructor can wait for them,
    // otherwise the QtConcurrent lambdas (which capture `this`) can outlive
    // the controller and crash when they touch freed members.
    mutable QMutex    m_jobsMutex;
    QList<QFuture<void>> m_pendingJobs;

    MarkdownConverter                  *m_converter = nullptr;
    std::unique_ptr<KnowledgeIndexFile> m_indexFile;
    KnowledgeReader                    *m_reader    = nullptr;
    LlamaBackend                       *m_llama     = nullptr;
};
