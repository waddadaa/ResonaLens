#pragma once

#include <QString>
#include <QStringList>

// Manages KNOWLEDGE_INDEX.md — the table-of-contents injected into every chat system prompt.
// Format: one line per file "- filename.md — Description"
// Source of truth is the file on disk; all mutating methods write immediately.
class KnowledgeIndexFile {
public:
    explicit KnowledgeIndexFile(const QString &indexPath);

    // Returns all index lines (raw "- file.md — desc" strings)
    QStringList entries() const;

    // Returns just the description for a given filename, or empty string
    QString     descriptionFor(const QString &filename) const;

    void        addEntry(const QString &filename, const QString &description);
    void        removeEntry(const QString &filename);
    void        updateDescription(const QString &filename, const QString &newDescription);

    // Compares index against files in knowledgeDir (*.md, excluding KNOWLEDGE_INDEX.md).
    // Adds entries for new files (with empty description), removes stale entries.
    // Populates added/removed with the filenames that changed.
    void        reconcile(const QString &knowledgeDir,
                          QStringList &added, QStringList &removed);

    // Returns full contents suitable for injection into system prompt
    QString     toSystemPromptBlock() const;

private:
    void        load();
    void        save() const;

    QString     m_path;
    QStringList m_lines; // raw entry lines, e.g. "- notes.md — Personal notes"
};
