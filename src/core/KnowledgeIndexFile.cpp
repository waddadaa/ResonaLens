#include "KnowledgeIndexFile.h"

#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QFileInfo>

KnowledgeIndexFile::KnowledgeIndexFile(const QString &indexPath)
    : m_path(indexPath)
{
    load();
}

void KnowledgeIndexFile::load()
{
    m_lines.clear();
    QFile f(m_path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return;
    QTextStream s(&f);
    while (!s.atEnd()) {
        QString line = s.readLine();
        if (line.startsWith("- "))
            m_lines.append(line);
    }
}

void KnowledgeIndexFile::save() const
{
    QFile f(m_path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
        return;
    QTextStream s(&f);
    s << "# Knowledge Base\n\n";
    for (const QString &line : m_lines)
        s << line << '\n';
}

QStringList KnowledgeIndexFile::entries() const
{
    return m_lines;
}

QString KnowledgeIndexFile::descriptionFor(const QString &filename) const
{
    for (const QString &line : m_lines) {
        // Format: "- filename.md — Description"  (em-dash U+2014)
        QString prefix = "- " + filename + " \u2014 ";
        if (line.startsWith(prefix))
            return line.mid(prefix.size()).trimmed();
    }
    return {};
}

void KnowledgeIndexFile::addEntry(const QString &filename, const QString &description)
{
    // Don't add duplicates
    QString prefix = "- " + filename + " ";
    for (const QString &line : m_lines) {
        if (line.startsWith(prefix))
            return;
    }
    m_lines.append(QString("- %1 \u2014 %2").arg(filename, description));
    save();
}

void KnowledgeIndexFile::removeEntry(const QString &filename)
{
    QString prefix = "- " + filename + " ";
    m_lines.removeIf([&](const QString &line){
        return line.startsWith(prefix) || line == "- " + filename;
    });
    save();
}

void KnowledgeIndexFile::updateDescription(const QString &filename, const QString &newDescription)
{
    QString prefix = "- " + filename + " ";
    for (QString &line : m_lines) {
        if (line.startsWith(prefix)) {
            line = QString("- %1 \u2014 %2").arg(filename, newDescription);
            save();
            return;
        }
    }
}

void KnowledgeIndexFile::reconcile(const QString &knowledgeDir,
                                    QStringList &added, QStringList &removed)
{
    added.clear();
    removed.clear();

    // Files on disk
    QDir dir(knowledgeDir);
    QStringList diskFiles = dir.entryList({"*.md"}, QDir::Files);
    diskFiles.removeAll("KNOWLEDGE_INDEX.md");

    // Files in index — extract filename from "- filename.md — desc"
    QStringList indexedFiles;
    for (const QString &line : m_lines) {
        if (!line.startsWith("- ")) continue;
        QString rest = line.mid(2);
        int spacePos = rest.indexOf(' ');
        QString name = (spacePos >= 0) ? rest.left(spacePos) : rest;
        if (!name.isEmpty())
            indexedFiles.append(name);
    }

    // Add missing (on disk but not in index)
    for (const QString &f : diskFiles) {
        if (!indexedFiles.contains(f)) {
            addEntry(f, "");
            added.append(f);
        }
    }

    // Remove stale (in index but not on disk)
    for (const QString &f : indexedFiles) {
        if (!diskFiles.contains(f)) {
            removeEntry(f);
            removed.append(f);
        }
    }
}

QString KnowledgeIndexFile::toSystemPromptBlock() const
{
    QString result = "# Knowledge Base\n\n";
    for (const QString &line : m_lines)
        result += line + '\n';
    return result;
}
