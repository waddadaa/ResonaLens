#include "KnowledgeController.h"
#include "database/Database.h"
#include "core/MarkdownConverter.h"
#include "core/KnowledgeIndexFile.h"
#include "core/KnowledgeReader.h"
#include "core/DocumentNavigator.h"
#include "core/LlamaBackend.h"
#include "core/WebReaderBackend.h"

#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QSqlQuery>
#include <QSqlError>
#include <QUuid>
#include <QDateTime>
#include <QFileInfo>
#include <QRegularExpression>
#include <QtConcurrent>
#include <QDebug>

KnowledgeController::KnowledgeController(LlamaBackend *llama,
                                           WebReaderBackend *webReader,
                                           QObject *parent)
    : QObject(parent)
    , m_llama(llama)
{
    QDir().mkpath(knowledgeDir());

    m_converter = new MarkdownConverter(webReader, this);
    m_indexFile = std::make_unique<KnowledgeIndexFile>(knowledgeDir() + "/KNOWLEDGE_INDEX.md");
    m_reader    = new KnowledgeReader(
        [this](const QString &prompt, int maxTokens) -> QString {
            return m_llama ? m_llama->generateSync(prompt, maxTokens) : QString();
        }, this);

    // Reconcile index against filesystem on startup (worker thread).
    // Track the future so the destructor can wait for it — otherwise an
    // in-flight lambda capturing `this` can outlive the controller.
    {
        QMutexLocker lock(&m_jobsMutex);
        m_pendingJobs.append(QtConcurrent::run([this]() { reconcileOnStartup(); }));
    }

    loadItems();
}

KnowledgeController::~KnowledgeController()
{
    // Wait for any QtConcurrent jobs that capture `this` to complete before
    // we let members be destroyed. Without this, a background conversion
    // will dereference freed state.
    QList<QFuture<void>> pending;
    {
        QMutexLocker lock(&m_jobsMutex);
        pending = std::move(m_pendingJobs);
    }
    for (auto &f : pending)
        f.waitForFinished();
}

QString KnowledgeController::knowledgeDir() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/knowledge";
}

QVariantList KnowledgeController::items() const { return m_items; }
bool KnowledgeController::isConverting() const   { return m_activeConversions > 0; }

QString KnowledgeController::knowledgeSystemPrompt() const
{
    QMutexLocker locker(&m_indexMutex);
    return m_indexFile->toSystemPromptBlock();
}

QString KnowledgeController::executeKnowledgeQuery(const QStringList &filenames,
                                                    const QString &query,
                                                    int contextBudget)
{
    QStringList fullPaths;
    for (const QString &name : filenames) {
        QString path = knowledgeDir() + "/" + name;
        if (QFile::exists(path))
            fullPaths.append(path);
        else
            qWarning() << "Knowledge file not found:" << path;
    }
    if (fullPaths.isEmpty())
        return "No matching knowledge files found.";

    return m_reader->execute(fullPaths, query, contextBudget);
}

void KnowledgeController::addNote(const QString &title, const QString &content)
{
    ++m_activeConversions;
    emit isConvertingChanged();

    auto f = QtConcurrent::run([this, title, content]() {
        QString slug = title.toLower()
                           .replace(QRegularExpression("[^a-z0-9]+"), "-")
                           .left(40);
        QString filename = slug + "-"
                         + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8)
                         + ".md";
        QString path = knowledgeDir() + "/" + filename;
        QFile f(path);
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream s(&f);
            s << "---\ntitle: " << title << "\nsource: note\nadded: "
              << QDateTime::currentDateTime().toString("yyyy-MM-dd") << "\n---\n\n"
              << "# " << title << "\n\n" << content;
        }

        addItemRecord(title, "note", path);
        generateAndAddToIndex(filename, path);

        QMetaObject::invokeMethod(this, [this]() {
            --m_activeConversions;
            emit isConvertingChanged();
            emit conversionComplete();
            loadItems();
        }, Qt::QueuedConnection);
    });
    {
        QMutexLocker lock(&m_jobsMutex);
        m_pendingJobs.append(f);
    }
}

void KnowledgeController::addFile(const QString &filePath)
{
    ++m_activeConversions;
    emit isConvertingChanged();

    auto f = QtConcurrent::run([this, filePath]() {
        QString mdPath = m_converter->convert(filePath, knowledgeDir());
        if (mdPath.isEmpty()) {
            QMetaObject::invokeMethod(this, [this]() {
                --m_activeConversions;
                emit isConvertingChanged();
            }, Qt::QueuedConnection);
            return;
        }

        QString filename = QFileInfo(mdPath).fileName();
        QString title    = QFileInfo(filePath).baseName();
        addItemRecord(title, "document", mdPath, filePath);
        generateAndAddToIndex(filename, mdPath);

        QMetaObject::invokeMethod(this, [this]() {
            --m_activeConversions;
            emit isConvertingChanged();
            emit conversionComplete();
            loadItems();
        }, Qt::QueuedConnection);
    });
    {
        QMutexLocker lock(&m_jobsMutex);
        m_pendingJobs.append(f);
    }
}

void KnowledgeController::addLink(const QString &url, const QString &title)
{
    ++m_activeConversions;
    emit isConvertingChanged();

    auto f = QtConcurrent::run([this, url, title]() {
        QString mdPath = m_converter->convertUrl(url, knowledgeDir());
        if (mdPath.isEmpty()) {
            QMetaObject::invokeMethod(this, [this]() {
                --m_activeConversions;
                emit isConvertingChanged();
            }, Qt::QueuedConnection);
            return;
        }

        QString filename     = QFileInfo(mdPath).fileName();
        QString displayTitle = title.isEmpty() ? url : title;
        addItemRecord(displayTitle, "webpage", mdPath, url);
        generateAndAddToIndex(filename, mdPath);

        QMetaObject::invokeMethod(this, [this]() {
            --m_activeConversions;
            emit isConvertingChanged();
            emit conversionComplete();
            loadItems();
        }, Qt::QueuedConnection);
    });
    {
        QMutexLocker lock(&m_jobsMutex);
        m_pendingJobs.append(f);
    }
}

void KnowledgeController::deleteItem(const QString &itemId)
{
    QSqlQuery q(Database::instance().db());
    q.prepare("SELECT md_path FROM knowledge_items WHERE id = ?");
    q.addBindValue(itemId);
    if (!q.exec()) {
        qWarning() << "deleteItem: lookup failed:" << q.lastError().text();
        return;
    }
    if (q.next()) {
        QString mdPath   = q.value(0).toString();
        QString filename = QFileInfo(mdPath).fileName();
        QFile::remove(mdPath);
        {
            QMutexLocker locker(&m_indexMutex);
            m_indexFile->removeEntry(filename);
        }
    }

    QSqlQuery del(Database::instance().db());
    del.prepare("DELETE FROM knowledge_items WHERE id = ?");
    del.addBindValue(itemId);
    if (!del.exec()) {
        qWarning() << "deleteItem: DELETE failed:" << del.lastError().text();
        return;
    }
    loadItems();
}

QVariantList KnowledgeController::search(const QString &query, int /*topK*/)
{
    QStringList entries;
    {
        QMutexLocker locker(&m_indexMutex);
        entries = m_indexFile->entries();
    }
    QVariantList results;
    for (const QString &line : entries) {
        if (line.contains(query, Qt::CaseInsensitive)) {
            QVariantMap r;
            r["entry"] = line;
            results.append(r);
        }
    }
    return results;
}

void KnowledgeController::refresh()
{
    loadItems();
}

void KnowledgeController::loadItems()
{
    m_items.clear();
    QSqlQuery query(Database::instance().db());
    if (!query.exec("SELECT id, title, source_type, source_path, md_path, created_at, updated_at, is_pinned "
                    "FROM knowledge_items ORDER BY is_pinned DESC, updated_at DESC")) {
        qWarning() << "loadItems failed:" << query.lastError().text();
        emit itemsChanged();
        return;
    }
    while (query.next()) {
        QVariantMap item;
        item["id"]         = query.value(0).toString();
        item["title"]      = query.value(1).toString();
        item["sourceType"] = query.value(2).toString();
        item["sourcePath"] = query.value(3).toString();
        item["mdPath"]     = query.value(4).toString();
        item["createdAt"]  = query.value(5).toString();
        item["updatedAt"]  = query.value(6).toString();
        item["isPinned"]   = query.value(7).toBool();
        item["chunkCount"] = 0;  // chunks table removed in migration 002
        m_items.append(item);
    }
    emit itemsChanged();
}

void KnowledgeController::setPinned(const QString &itemId, bool pinned)
{
    QSqlQuery q(Database::instance().db());
    q.prepare("UPDATE knowledge_items SET is_pinned = ? WHERE id = ?");
    q.addBindValue(pinned ? 1 : 0);
    q.addBindValue(itemId);
    if (!q.exec())
        qWarning() << "setPinned failed:" << q.lastError().text();
    loadItems();
}

QString KnowledgeController::pinnedDocumentsContext(const QString &query) const
{
    QSqlQuery q(Database::instance().db());
    if (!q.exec("SELECT title, md_path FROM knowledge_items WHERE is_pinned = 1 ORDER BY updated_at DESC")) {
        qWarning() << "pinnedDocumentsContext: SELECT failed:" << q.lastError().text();
        return QString();
    }

    // Extract meaningful query keywords (4+ chars, no stopwords)
    static const QSet<QString> stopwords = {
        "what", "when", "where", "which", "that", "this", "with", "from",
        "have", "will", "would", "could", "should", "about", "there", "their",
        "does", "into", "than", "then", "they", "been", "were", "some"
    };
    QStringList keywords;
    if (!query.isEmpty()) {
        for (const QString &word : query.toLower().split(QRegularExpression("[^a-z]+"))) {
            if (word.length() >= 4 && !stopwords.contains(word))
                keywords.append(word);
        }
    }

    DocumentNavigator nav;
    QString context;
    const int kWindowTokens  = 500;   // ~2000 chars per window
    const int kOverlapTokens = 80;
    const int kBudgetPerDoc  = 3000;  // token budget per document

    while (q.next()) {
        QString title  = q.value(0).toString();
        QString mdPath = q.value(1).toString();

        if (mdPath.isEmpty() || !QFile::exists(mdPath))
            continue;

        int total = nav.windowCount(mdPath, kWindowTokens);
        if (total == 0)
            continue;

        // Score every window by keyword hit count
        struct ScoredWindow { int score; int index; };
        QVector<ScoredWindow> scored;
        scored.reserve(total);

        for (int i = 0; i < total; ++i) {
            auto window = nav.fetchWindow(mdPath, i, kWindowTokens, kOverlapTokens);
            int score = 0;
            if (keywords.isEmpty()) {
                // No query — use document order (score = -index so first windows rank highest)
                score = -i;
            } else {
                QString lower = window.content.toLower();
                for (const QString &kw : keywords)
                    score += lower.count(kw);
            }
            scored.append({score, i});
        }

        // Sort descending by score; preserve document order for ties
        std::stable_sort(scored.begin(), scored.end(),
                         [](const ScoredWindow &a, const ScoredWindow &b) {
                             return a.score > b.score;
                         });

        // Collect top windows up to budget, then re-sort by index for coherence
        QVector<int> picked;
        int usedTokens = 0;
        for (const ScoredWindow &sw : scored) {
            if (sw.score <= 0 && !keywords.isEmpty())
                break;  // stop at zero-hit windows when we have a real query
            if (usedTokens >= kBudgetPerDoc)
                break;
            picked.append(sw.index);
            usedTokens += kWindowTokens;
        }
        std::sort(picked.begin(), picked.end());

        if (picked.isEmpty())
            continue;

        QString docContent;
        int prev = -1;
        for (int idx : picked) {
            if (prev != -1 && idx > prev + 1)
                docContent += "\n[...]\n\n";
            auto window = nav.fetchWindow(mdPath, idx, kWindowTokens, kOverlapTokens);
            docContent += window.content;
            prev = idx;
        }

        context += "### " + title + "\n\n" + docContent.trimmed() + "\n\n---\n\n";
    }
    return context;
}

QString KnowledgeController::addItemRecord(const QString &title, const QString &sourceType,
                                            const QString &mdPath, const QString &sourcePath)
{
    QString id  = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    QSqlQuery q(Database::instance().db());
    q.prepare("INSERT INTO knowledge_items (id, title, source_type, source_path, md_path, "
              "created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)");
    q.addBindValue(id);
    q.addBindValue(title);
    q.addBindValue(sourceType);
    q.addBindValue(sourcePath);
    q.addBindValue(mdPath);
    q.addBindValue(now);
    q.addBindValue(now);

    if (!q.exec()) {
        qWarning() << "Failed to add knowledge item:" << q.lastError().text();
        return {};
    }
    return id;
}

void KnowledgeController::generateAndAddToIndex(const QString &filename, const QString &mdPath)
{
    QString description;
    if (m_llama && m_llama->isModelLoaded()) {
        QFile f(mdPath);
        QString preview;
        if (f.open(QIODevice::ReadOnly | QIODevice::Text))
            preview = QTextStream(&f).read(500);

        QString prompt = QString(
            "In one sentence (max 120 characters), describe what this document is about:\n%1"
        ).arg(preview);

        description = m_llama->generateSync(prompt, 60).trimmed();
        if (description.size() > 120)
            description = description.left(117) + "...";
    }

    if (description.isEmpty())
        description = filename;

    {
        QMutexLocker locker(&m_indexMutex);
        m_indexFile->addEntry(filename, description);
    }
}

void KnowledgeController::reconcileOnStartup()
{
    QStringList added, removed;
    {
        QMutexLocker locker(&m_indexMutex);
        m_indexFile->reconcile(knowledgeDir(), added, removed);
    }
    if (!added.isEmpty() || !removed.isEmpty()) {
        qInfo() << "Knowledge index reconciled — added:" << added.size()
                << "removed:" << removed.size();
        QMetaObject::invokeMethod(this, &KnowledgeController::loadItems,
                                  Qt::QueuedConnection);
    }
}
