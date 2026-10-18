#include <QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QTextStream>
#include "DocumentNavigator.h"

class TstDocumentNavigator : public QObject {
    Q_OBJECT

    QTemporaryDir m_dir;

    QString writeFile(const QString &name, const QString &content) {
        QString path = m_dir.filePath(name);
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
            return {};
        QTextStream s(&f);
        s << content;
        return path;
    }

private slots:
    void isStructured_withManyHeadings_returnsTrue() {
        // ~200 tokens of content with 1 heading → structured (1 * 500 >= 200)
        QString md = "# Introduction\n\nThis is a short section.\n\n"
                     "## Background\n\nMore content here.\n";
        QString path = writeFile("structured.md", md);
        DocumentNavigator nav;
        QVERIFY(nav.isStructured(path));
    }

    void isStructured_flatProse_returnsFalse() {
        // 800 tokens of prose, 0 headings → not structured (0 * 500 < 3200)
        QString prose = QString("word ").repeated(800); // ~800 tokens
        QString path = writeFile("flat.md", prose);
        DocumentNavigator nav;
        QVERIFY(!nav.isStructured(path));
    }

    void headingTree_returnsCompactString() {
        QString md = "---\ntitle: Test\n---\n\n"
                     "# Introduction\n\nSome text here about things.\n\n"
                     "# Background\n\nMore text in this section.\n\n"
                     "## Sub-section\n\nEven more text.\n";
        QString path = writeFile("tree.md", md);
        DocumentNavigator nav;
        QStringList tree = nav.headingTree(path);
        // Should have 3 entries: Introduction, Background, Sub-section
        QCOMPARE(tree.size(), 3);
        QVERIFY(tree[0].contains("Introduction"));
        QVERIFY(tree[1].contains("Background"));
        QVERIFY(tree[2].contains("Sub-section"));
        // Each entry should contain token estimate in parens
        QVERIFY(tree[0].contains("tok)"));
    }

    void headingTree_ignoresFrontMatter() {
        QString md = "---\ntitle: Foo\nadded: 2026-01-01\n---\n\n# Only Heading\n\nContent.\n";
        QString path = writeFile("frontmatter.md", md);
        DocumentNavigator nav;
        QStringList tree = nav.headingTree(path);
        QCOMPARE(tree.size(), 1);
        QVERIFY(tree[0].startsWith("[1]"));
    }

    void fetchSection_returnsCorrectContent() {
        QString md = "# First\n\nContent of first section.\n\n"
                     "# Second\n\nContent of second section.\n";
        QString path = writeFile("sections.md", md);
        DocumentNavigator nav;

        auto s1 = nav.fetchSection(path, 1);
        QCOMPARE(s1.index, 1);
        QCOMPARE(s1.heading, QString("First"));
        QVERIFY(s1.content.contains("Content of first section"));
        QVERIFY(!s1.content.contains("Content of second section"));

        auto s2 = nav.fetchSection(path, 2);
        QCOMPARE(s2.index, 2);
        QVERIFY(s2.content.contains("Content of second section"));
    }

    void fetchSection_invalidIndex_returnsEmpty() {
        QString md = "# Only\n\nOne section.\n";
        QString path = writeFile("one.md", md);
        DocumentNavigator nav;
        auto s = nav.fetchSection(path, 99);
        QVERIFY(s.content.isEmpty());
    }

    void windowCount_shortDocument_returnsOne() {
        // 100 chars ≈ 25 tokens — fits in a 400-token window → 1 window
        QString text = QString("x").repeated(100);
        QString path = writeFile("short.md", text);
        DocumentNavigator nav;
        QCOMPARE(nav.windowCount(path, 400), 1);
    }

    void windowCount_longDocument_returnsMultiple() {
        // 8000 chars ≈ 2000 tokens, window=400, overlap=50, step=350
        // count = (8000 - 1600) / 1400 + 1 = 4 + 1 = 5 (approximately)
        QString text = QString("word ").repeated(1600); // 8000 chars
        QString path = writeFile("long.md", text);
        DocumentNavigator nav;
        int count = nav.windowCount(path, 400);
        QVERIFY(count > 1);
    }

    void fetchWindow_firstWindowStartsAtBeginning() {
        // Create text with distinct first 1600 chars
        QString text = QString("A").repeated(1600) + QString("B").repeated(1600) +
                       QString("C").repeated(1600) + QString("D").repeated(1600);
        QString path = writeFile("windows.md", text);
        DocumentNavigator nav;

        auto w0 = nav.fetchWindow(path, 0, 400, 50);
        QCOMPARE(w0.index, 0);
        // Window 0: chars 0..1599 → all A's (1600 chars = 400 tokens)
        QVERIFY(w0.content.startsWith("A"));
        QVERIFY(!w0.content.contains("B"));

        auto w1 = nav.fetchWindow(path, 1, 400, 50);
        QCOMPARE(w1.index, 1);
        // Window 1 starts at step*1 = 350*4 = 1400 chars in
        // So it starts in the A region but extends into B
        QVERIFY(!w1.content.isEmpty());
    }
};

QTEST_MAIN(TstDocumentNavigator)
#include "tst_document_navigator.moc"
