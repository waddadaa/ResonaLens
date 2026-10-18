#pragma once

#include <QString>
#include <QStringList>

class DocumentNavigator {
public:
    struct Section {
        int     index;          // 1-based
        int     level;          // heading level 1/2/3
        QString heading;        // heading text without # markers
        QString content;        // full text of this section including heading line
        int     tokenEstimate;
    };

    struct Window {
        int     index;          // 0-based
        QString content;
    };

    // Returns true if heading density indicates structured document.
    // Rule: headingCount * 500 >= estimatedTokens
    bool        isStructured(const QString &mdPath);

    // Returns one line per heading: "[N] Heading (XYZ tok)"
    // Skips YAML front-matter. Index is 1-based.
    QStringList headingTree(const QString &mdPath);

    // Returns the Nth section (1-based) including its heading line and body.
    Section     fetchSection(const QString &mdPath, int sectionIndex);

    // Returns the Nth sliding window (0-based). windowTokens ≈ chars/4.
    Window      fetchWindow(const QString &mdPath, int windowIndex,
                            int windowTokens = 400, int overlapTokens = 50);

    // Total number of windows for a file.
    int         windowCount(const QString &mdPath, int windowTokens = 400);

private:
    QString        readFile(const QString &path);
    QString        stripFrontMatter(const QString &text);
    QList<Section> buildSections(const QString &text);
    static int     estimateTokens(const QString &text) { return text.size() / 4; }
};
