#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <QMap>
#include <QStringList>
#include <functional>

class WebSearchBackend;
class WebReaderBackend;

class SkillExecutor : public QObject {
    Q_OBJECT

public:
    explicit SkillExecutor(QObject *parent = nullptr);

    /// Load all Skill.md files from the given directory (each subdirectory = one skill).
    void loadSkillDefinitions(const QString &skillsDir);

    /// Build a natural-language skill context to inject into the system prompt.
    /// Returns human-readable descriptions, not JSON schema.
    QString buildSkillContext() const;

    /// Detect if the LLM output contains a skill invocation.
    /// Checks multiple formats (XML tag, bracket, keyword, JSON, natural language).
    /// Returns true if a skill was detected; fills @p skillName and @p input.
    bool detectSkillIntent(const QString &llmOutput, QString &skillName, QString &input) const;

    /// Execute a detected skill and return the result as clean text.
    QString executeSkill(const QString &skillName, const QString &input);

    /// Provide the silent LLM call used to summarize each fetched article.
    void setSummarizer(std::function<QString(const QString &prompt)> fn);

    /// When true, search results use only snippets (no page fetch/summarize).
    /// Use for models with small context windows (e.g. LiteRT CLI with 4096 tokens).
    void setCompactResults(bool compact) { m_compactResults = compact; }

    /// Return metadata for all loaded skills (for QML / SkillController).
    QVariantList skillList() const;

signals:
    void skillStarted(const QString &skillName);
    void skillCompleted(const QString &skillName, const QVariantMap &result);
    void skillFailed(const QString &skillName, const QString &error);

private:
    struct SkillDef {
        QString name;
        QString description;
        QStringList triggers;    ///< keywords that help detect intent from natural language
        QString whenToUse;       ///< markdown section
        QString whenNotToUse;    ///< markdown section
        QString instructions;    ///< markdown section
        QString examples;        ///< example invocations
        QString fullBody;        ///< complete markdown body after frontmatter
    };

    /// Try each detection pattern in priority order.
    bool detectXmlTag(const QString &text, QString &skillName, QString &input) const;
    bool detectBracketFormat(const QString &text, QString &skillName, QString &input) const;
    bool detectKeywordFormat(const QString &text, QString &skillName, QString &input) const;
    bool detectJsonFormat(const QString &text, QString &skillName, QString &input) const;
    bool detectGemmaToolCall(const QString &text, QString &skillName, QString &input) const;
    bool detectNaturalLanguage(const QString &text, QString &skillName, QString &input) const;

    /// Check if a detected skill name actually exists.
    bool isValidSkill(const QString &name) const;

    /// Extract a query/input from surrounding natural language text.
    QString extractQueryFromContext(const QString &text, const QString &skillName) const;

    QMap<QString, SkillDef> m_skills;
    WebSearchBackend *m_webSearch = nullptr;
    WebReaderBackend *m_webReader = nullptr;
    std::function<QString(const QString &)> m_summarizer;
    bool m_compactResults = false;
};
