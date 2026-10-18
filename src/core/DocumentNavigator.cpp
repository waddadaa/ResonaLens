#include "DocumentNavigator.h"

#include <QFile>
#include <QTextStream>
#include <QRegularExpression>

QString DocumentNavigator::readFile(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    QTextStream s(&f);
    return s.readAll();
}

QString DocumentNavigator::stripFrontMatter(const QString &text)
{
    if (!text.startsWith("---"))
        return text;
    int end = text.indexOf("\n---\n", 3);
    if (end == -1)
        return text;
    return text.mid(end + 5).trimmed();
}

QList<DocumentNavigator::Section> DocumentNavigator::buildSections(const QString &text)
{
    QList<Section> sections;
    const QStringList lines = text.split('\n');
    static QRegularExpression headingRe(R"(^(#{1,3})\s+(.+)$)");

    struct HeadingPos { int lineIndex; int level; QString text; };
    QList<HeadingPos> headings;
    for (int i = 0; i < lines.size(); ++i) {
        auto m = headingRe.match(lines[i]);
        if (m.hasMatch())
            headings.append({ i, (int)m.captured(1).size(), m.captured(2).trimmed() });
    }

    for (int h = 0; h < headings.size(); ++h) {
        int startLine = headings[h].lineIndex;
        int endLine   = (h + 1 < headings.size()) ? headings[h + 1].lineIndex : lines.size();

        QStringList sectionLines = lines.mid(startLine, endLine - startLine);
        while (!sectionLines.isEmpty() && sectionLines.last().trimmed().isEmpty())
            sectionLines.removeLast();

        Section s;
        s.index         = h + 1;
        s.level         = headings[h].level;
        s.heading       = headings[h].text;
        s.content       = sectionLines.join('\n');
        s.tokenEstimate = estimateTokens(s.content);
        sections.append(s);
    }
    return sections;
}

bool DocumentNavigator::isStructured(const QString &mdPath)
{
    QString text = stripFrontMatter(readFile(mdPath));
    auto sections = buildSections(text);
    int tokens = estimateTokens(text);
    return sections.size() * 500 >= tokens;
}

QStringList DocumentNavigator::headingTree(const QString &mdPath)
{
    QString text = stripFrontMatter(readFile(mdPath));
    auto sections = buildSections(text);

    QStringList result;
    for (const Section &s : sections) {
        QString label = QString("[%1] %2 (%3 tok)").arg(s.index).arg(s.heading).arg(s.tokenEstimate);
        result.append(label);
    }
    return result;
}

DocumentNavigator::Section DocumentNavigator::fetchSection(const QString &mdPath, int sectionIndex)
{
    QString text = stripFrontMatter(readFile(mdPath));
    auto sections = buildSections(text);
    for (const Section &s : sections) {
        if (s.index == sectionIndex)
            return s;
    }
    return {};
}

DocumentNavigator::Window DocumentNavigator::fetchWindow(const QString &mdPath,
                                                          int windowIndex,
                                                          int windowTokens,
                                                          int overlapTokens)
{
    QString text = stripFrontMatter(readFile(mdPath));
    int charsPerWindow = windowTokens * 4;
    int charsPerStep   = (windowTokens - overlapTokens) * 4;
    int startChar      = windowIndex * charsPerStep;

    Window w;
    w.index   = windowIndex;
    w.content = text.mid(startChar, charsPerWindow);
    return w;
}

int DocumentNavigator::windowCount(const QString &mdPath, int windowTokens)
{
    QString text = stripFrontMatter(readFile(mdPath));
    if (text.isEmpty()) return 0;
    int overlapTokens  = 50;
    int charsPerStep   = (windowTokens - overlapTokens) * 4;
    int totalChars     = text.size();
    int charsPerWindow = windowTokens * 4;
    if (totalChars <= charsPerWindow) return 1;
    return (totalChars - charsPerWindow) / charsPerStep + 1;
}
