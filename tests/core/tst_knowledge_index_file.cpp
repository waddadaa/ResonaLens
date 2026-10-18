#include <QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include "KnowledgeIndexFile.h"

class TstKnowledgeIndexFile : public QObject {
    Q_OBJECT

    QTemporaryDir m_dir;

private slots:
    void addEntry_appearsInIndex() {
        KnowledgeIndexFile idx(m_dir.filePath("KNOWLEDGE_INDEX.md"));
        idx.addEntry("notes.md", "Personal notes on React hooks");
        QStringList entries = idx.entries();
        QCOMPARE(entries.size(), 1);
        QVERIFY(entries[0].contains("notes.md"));
        QVERIFY(entries[0].contains("Personal notes on React hooks"));
    }

    void addEntry_persistsToDisk() {
        QString path = m_dir.filePath("KNOWLEDGE_INDEX_persist.md");
        {
            KnowledgeIndexFile idx(path);
            idx.addEntry("paper.md", "Transformer paper");
        }
        // Reload from disk
        KnowledgeIndexFile idx2(path);
        QCOMPARE(idx2.entries().size(), 1);
    }

    void removeEntry_disappearsFromIndex() {
        KnowledgeIndexFile idx(m_dir.filePath("KNOWLEDGE_INDEX2.md"));
        idx.addEntry("a.md", "File A");
        idx.addEntry("b.md", "File B");
        idx.removeEntry("a.md");
        QStringList entries = idx.entries();
        QCOMPARE(entries.size(), 1);
        QVERIFY(entries[0].contains("b.md"));
    }

    void updateDescription_changesExistingEntry() {
        KnowledgeIndexFile idx(m_dir.filePath("KNOWLEDGE_INDEX3.md"));
        idx.addEntry("doc.md", "Old description");
        idx.updateDescription("doc.md", "New description");
        QVERIFY(idx.entries()[0].contains("New description"));
        QVERIFY(!idx.entries()[0].contains("Old description"));
    }

    void reconcile_addsNewFilesAndRemovesStale() {
        QString knowledgeDir = m_dir.filePath("knowledge");
        QDir().mkpath(knowledgeDir);

        // Create two .md files on disk
        QFile f1(knowledgeDir + "/alpha.md");
        f1.open(QIODevice::WriteOnly);
        QFile f2(knowledgeDir + "/beta.md");
        f2.open(QIODevice::WriteOnly);

        QString indexPath = knowledgeDir + "/KNOWLEDGE_INDEX.md";
        KnowledgeIndexFile idx(indexPath);

        // Add only alpha to index, and a stale entry
        idx.addEntry("alpha.md", "Alpha doc");
        idx.addEntry("stale.md", "Stale doc");

        // beta.md is on disk but not in index; stale.md is in index but not on disk
        QStringList added, removed;
        idx.reconcile(knowledgeDir, added, removed);

        QVERIFY(added.contains("beta.md"));
        QVERIFY(removed.contains("stale.md"));
        // Index should now have alpha + beta, not stale
        QStringList final = idx.entries();
        bool hasBeta  = std::any_of(final.begin(), final.end(), [](const QString &e){ return e.contains("beta.md"); });
        bool hasStale = std::any_of(final.begin(), final.end(), [](const QString &e){ return e.contains("stale.md"); });
        QVERIFY(hasBeta);
        QVERIFY(!hasStale);
    }

    void descriptionFor_returnsDescription() {
        KnowledgeIndexFile idx(m_dir.filePath("KNOWLEDGE_INDEX4.md"));
        idx.addEntry("x.md", "The description of X");
        QCOMPARE(idx.descriptionFor("x.md"), QString("The description of X"));
    }
};

QTEST_MAIN(TstKnowledgeIndexFile)
#include "tst_knowledge_index_file.moc"
