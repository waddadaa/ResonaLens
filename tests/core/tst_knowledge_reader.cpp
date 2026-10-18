#include <QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QTextStream>
#include <functional>
#include "KnowledgeReader.h"

class TstKnowledgeReader : public QObject {
    Q_OBJECT

    QTemporaryDir m_dir;

    QString writeFile(const QString &name, const QString &content) {
        QString path = m_dir.filePath(name);
        QFile f(path);
        f.open(QIODevice::WriteOnly | QIODevice::Text);
        QTextStream(&f) << content;
        return path;
    }

private slots:
    void execute_structuredDoc_callsGeneratorForSectionSelection() {
        // Structured doc (has headings)
        QString md = "---\ntitle: Test\n---\n\n"
                     "# Introduction\n\nThis answers the query about dogs.\n\n"
                     "# Unrelated\n\nThis talks about cats.\n";
        QString path = writeFile("structured.md", md);

        int callCount = 0;
        // First call: section selection — LLM picks section 1
        KnowledgeReader reader([&callCount](const QString &, int) -> QString {
            ++callCount;
            return "1";
        });

        QString result = reader.execute({ path }, "dogs", 16000);
        QVERIFY(callCount >= 1); // at least one call for section selection
        QVERIFY(!result.isEmpty());
    }

    void execute_flatDoc_callsGeneratorPerWindow() {
        // Flat doc (no headings) with 2000 chars ≈ 500 tokens → ~2 windows at 400tok
        QString prose = QString("dog ").repeated(500); // 2000 chars
        QString path = writeFile("flat.md", prose);

        int callCount = 0;
        // Generator says YES for first window, NO for rest
        KnowledgeReader reader([&callCount](const QString &, int) -> QString {
            ++callCount;
            return callCount == 1 ? "dog is a domestic animal" : "NO";
        });

        QString result = reader.execute({ path }, "dog", 4090);
        QVERIFY(callCount >= 1);
        QVERIFY(result.contains("dog"));
    }

    void execute_smallContext_packsResultsWithoutSynthesis() {
        QString md = "# Facts\n\nThe sky is blue.\n";
        QString path = writeFile("facts.md", md);

        int callCount = 0;
        QStringList prompts;
        KnowledgeReader reader([&callCount, &prompts](const QString &p, int) -> QString {
            ++callCount;
            prompts.append(p.left(80));
            if (p.contains("select") || p.contains("Query"))
                return "1";
            return "The sky is blue.";
        });

        // contextBudget = 4090 (small context) — should pack, not synthesize
        QString result = reader.execute({ path }, "sky color", 4090);

        // Result should contain the extracted content formatted with filename header
        QVERIFY(result.contains("facts.md") || result.contains("sky"));

        // Should NOT have made a synthesis call (synthesis only for contextBudget > 8000)
        bool hasSynthesis = std::any_of(prompts.begin(), prompts.end(),
            [](const QString &p){ return p.contains("Given these sources"); });
        QVERIFY(!hasSynthesis);
    }

    void execute_tinyContextBudget_returnsNonCrashing();

    void execute_largeContext_makesExtraSynthesisCall() {
        QString md = "# Topic\n\nSome detailed answer.\n";
        QString path = writeFile("topic.md", md);

        int callCount = 0;
        QStringList calls;
        KnowledgeReader reader([&callCount, &calls](const QString &p, int) -> QString {
            ++callCount;
            calls.append(p.left(80));
            if (p.contains("select") || p.contains("Query"))
                return "1";
            if (p.contains("Given these sources"))
                return "Synthesized answer about the topic.";
            return "Some detailed answer.";
        });

        QString result = reader.execute({ path }, "topic", 16000);

        // Large context → synthesis call should have been made
        bool hasSynthesis = std::any_of(calls.begin(), calls.end(),
            [](const QString &c){ return c.contains("Given these sources"); });
        QVERIFY(hasSynthesis);
        QVERIFY(!result.isEmpty());
    }
};

void TstKnowledgeReader::execute_tinyContextBudget_returnsNonCrashing()
{
    QString md = "# Facts\n\nThe sky is blue.\n";
    QString path = writeFile("tiny_ctx.md", md);

    KnowledgeReader reader([](const QString &p, int) -> QString {
        if (p.contains("Query") || p.contains("select"))
            return "1";
        return "The sky is blue.";
    });

    // contextBudget = 100 (<= 1500) — budget - 1500 would be negative without guard
    QString result = reader.execute({ path }, "sky", 100);
    // Should not crash; result may be empty or contain content, but must not hang
    // (empty is acceptable when budget is exhausted)
    Q_UNUSED(result);
    QVERIFY(true); // just verify no crash/hang
}

QTEST_MAIN(TstKnowledgeReader)
#include "tst_knowledge_reader.moc"
