#include "SkillExecutor.h"
#include "WebSearchBackend.h"
#include "WebReaderBackend.h"

#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QJsonDocument>
#include <QJsonObject>
#include <QHash>
#include <QSet>
#include <QDate>
#include <QDebug>

// ─────────────────────────────────────────────────────────────────────
// Construction
// ─────────────────────────────────────────────────────────────────────

SkillExecutor::SkillExecutor(QObject *parent)
    : QObject(parent)
    , m_webSearch(new WebSearchBackend(this))
    , m_webReader(new WebReaderBackend(this))
{
}

// ─────────────────────────────────────────────────────────────────────
// Load Skill.md files
// ─────────────────────────────────────────────────────────────────────

void SkillExecutor::loadSkillDefinitions(const QString &skillsDir)
{
    QDir dir(skillsDir);
    if (!dir.exists()) {
        qWarning() << "Skills directory not found:" << skillsDir;
        return;
    }

    const QStringList entries = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        QString skillFile = dir.filePath(entry + "/Skill.md");
        QFile file(skillFile);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            continue;

        QTextStream stream(&file);
        QString content = stream.readAll();

        // ── Parse YAML frontmatter ──
        static QRegularExpression frontmatterRe(
            "^---\\n(.*?)\\n---",
            QRegularExpression::DotMatchesEverythingOption);
        auto fmMatch = frontmatterRe.match(content);
        if (!fmMatch.hasMatch())
            continue;

        SkillDef skill;
        skill.name = entry; // fallback to directory name

        QString yaml = fmMatch.captured(1);

        // name
        static QRegularExpression nameRe("name:\\s*(.+)");
        auto nameMatch = nameRe.match(yaml);
        if (nameMatch.hasMatch())
            skill.name = nameMatch.captured(1).trimmed();

        // description
        static QRegularExpression descRe("description:\\s*(.+)");
        auto descMatch = descRe.match(yaml);
        if (descMatch.hasMatch())
            skill.description = descMatch.captured(1).trimmed();

        // triggers (YAML list)
        static QRegularExpression triggersBlockRe(
            "triggers:\\s*\\n((?:\\s*-\\s*.+\\n?)+)");
        auto trigMatch = triggersBlockRe.match(yaml);
        if (trigMatch.hasMatch()) {
            static QRegularExpression trigItemRe("^\\s*-\\s*(.+)$",
                QRegularExpression::MultilineOption);
            auto it = trigItemRe.globalMatch(trigMatch.captured(1));
            while (it.hasNext())
                skill.triggers << it.next().captured(1).trimmed().toLower();
        }

        // ── Parse markdown body sections ──
        QString body = content.mid(fmMatch.capturedEnd()).trimmed();
        skill.fullBody = body;

        auto extractSection = [&body](const QString &heading) -> QString {
            QRegularExpression re(
                "##\\s+" + QRegularExpression::escape(heading) + "\\s*\\n(.*?)(?=\\n##\\s|$)",
                QRegularExpression::DotMatchesEverythingOption);
            auto m = re.match(body);
            return m.hasMatch() ? m.captured(1).trimmed() : QString();
        };

        skill.whenToUse    = extractSection("When to Use");
        skill.whenNotToUse = extractSection("When NOT to Use");
        skill.instructions = extractSection("Instructions");
        skill.examples     = extractSection("Example Invocations");

        m_skills[skill.name] = skill;
        qInfo() << "Loaded skill:" << skill.name
                << "triggers:" << skill.triggers;
    }
}

// ─────────────────────────────────────────────────────────────────────
// Build natural-language skill context for the system prompt
// ─────────────────────────────────────────────────────────────────────

QString SkillExecutor::buildSkillContext() const
{
    if (m_skills.isEmpty())
        return {};

    QString ctx = "IMPORTANT: Answer most questions directly from your training knowledge. "
                  "You are a knowledgeable AI assistant. Only use a skill when the user "
                  "EXPLICITLY asks to search online, or asks about something that happened "
                  "AFTER your training cutoff (e.g. very recent news, today's prices, live scores).\n\n"
                  "Do NOT use skills for: general knowledge, science, math, history, geography, "
                  "coding, explanations, opinions, creative writing, or any well-known facts.\n\n"
                  "Available skills (use ONLY when necessary):\n"
                  "To use one, write: USE_SKILL: skill_name | your query\n\n";

    for (auto it = m_skills.constBegin(); it != m_skills.constEnd(); ++it) {
        const SkillDef &s = it.value();
        ctx += "- " + s.name + ": " + s.description + "\n";
    }

    ctx += "\nFor most questions, just answer directly.\n";
    return ctx;
}

// ─────────────────────────────────────────────────────────────────────
// Skill intent detection — check multiple formats in priority order
// ─────────────────────────────────────────────────────────────────────

bool SkillExecutor::detectSkillIntent(const QString &llmOutput,
                                       QString &skillName,
                                       QString &input) const
{
    // Try each pattern in order of reliability
    if (detectKeywordFormat(llmOutput, skillName, input)) return true;  // USE_SKILL: format (primary)
    if (detectGemmaToolCall(llmOutput, skillName, input)) return true;  // Gemma native: <|tool_call>call:name{...}
    if (detectXmlTag(llmOutput, skillName, input))       return true;
    if (detectBracketFormat(llmOutput, skillName, input)) return true;
    if (detectJsonFormat(llmOutput, skillName, input))    return true;
    if (detectNaturalLanguage(llmOutput, skillName, input)) return true;
    return false;
}

// Pattern 1: <skill name="web_search">latest AI news</skill>
bool SkillExecutor::detectXmlTag(const QString &text,
                                  QString &skillName,
                                  QString &input) const
{
    static QRegularExpression re(
        R"RE(<skill\s+name\s*=\s*"([^"]+)"\s*>(.*?)</skill>)RE",
        QRegularExpression::DotMatchesEverythingOption);

    auto match = re.match(text);
    if (match.hasMatch()) {
        QString name = match.captured(1).trimmed();
        QString inp = match.captured(2).trimmed();
        // Guard against placeholder/example inputs
        if (inp == "skill_name" || inp == "your input here" || inp == "your query here")
            return false;
        if (isValidSkill(name)) {
            skillName = name;
            input = inp;
            return true;
        }
    }
    return false;
}

// Pattern 2: [web_search: latest AI news]
bool SkillExecutor::detectBracketFormat(const QString &text,
                                         QString &skillName,
                                         QString &input) const
{
    static QRegularExpression re(
        R"(\[([a-z_]+)\s*:\s*(.+?)\])",
        QRegularExpression::DotMatchesEverythingOption);

    auto match = re.match(text);
    if (match.hasMatch()) {
        QString name = match.captured(1).trimmed();
        if (isValidSkill(name)) {
            skillName = name;
            input = match.captured(2).trimmed();
            return true;
        }
    }
    return false;
}

// Pattern 3: SKILL: web_search INPUT: latest AI news
bool SkillExecutor::detectKeywordFormat(const QString &text,
                                         QString &skillName,
                                         QString &input) const
{
    // Primary format: USE_SKILL: name | input
    static QRegularExpression useSkillRe(
        R"(USE_SKILL:\s*([a-z_]+)\s*\|\s*(.+))",
        QRegularExpression::MultilineOption);

    auto match = useSkillRe.match(text);
    if (match.hasMatch()) {
        QString name = match.captured(1).trimmed();
        QString inp = match.captured(2).trimmed();
        // Guard: skip placeholder/example inputs
        if (inp == "your input here" || inp == "your query here" || inp == "skill_name")
            return false;
        // The model sometimes echoes the skill description before the actual
        // query, separated by extra '|' chars.  Take text after the last '|'.
        int lastPipe = inp.lastIndexOf('|');
        if (lastPipe >= 0)
            inp = inp.mid(lastPipe + 1).trimmed();
        if (isValidSkill(name)) {
            skillName = name;
            input = inp;
            return true;
        }
    }

    // Legacy format: SKILL: name INPUT: input
    static QRegularExpression legacyRe(
        R"(SKILL:\s*([a-z_]+)\s+INPUT:\s*(.+))",
        QRegularExpression::MultilineOption);

    auto legacyMatch = legacyRe.match(text);
    if (legacyMatch.hasMatch()) {
        QString name = legacyMatch.captured(1).trimmed();
        QString inp = legacyMatch.captured(2).trimmed();
        if (inp == "your input here" || inp == "your query here")
            return false;
        if (isValidSkill(name)) {
            skillName = name;
            input = inp;
            return true;
        }
    }
    return false;
}

// Pattern 4: {"action": "web_search", "input": "latest AI news"}
bool SkillExecutor::detectJsonFormat(const QString &text,
                                      QString &skillName,
                                      QString &input) const
{
    // Also accept legacy <tool_use> wrapped JSON
    static QRegularExpression toolUseRe(
        R"(<tool_use>\s*(\{.*?\})\s*</tool_use>)",
        QRegularExpression::DotMatchesEverythingOption);

    auto toolMatch = toolUseRe.match(text);
    QString jsonStr = toolMatch.hasMatch() ? toolMatch.captured(1) : QString();

    // Try raw JSON if no <tool_use> wrapper
    if (jsonStr.isEmpty()) {
        static QRegularExpression jsonRe(
            R"RE(\{\s*"(?:action|name)"\s*:\s*"([^"]+)"\s*,\s*"(?:input|query|parameters)"\s*:\s*"([^"]*?)"\s*\})RE");
        auto jm = jsonRe.match(text);
        if (jm.hasMatch()) {
            QString name = jm.captured(1).trimmed();
            if (isValidSkill(name)) {
                skillName = name;
                input = jm.captured(2).trimmed();
                return true;
            }
        }
        return false;
    }

    // Parse the JSON from <tool_use>
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    if (doc.isNull())
        return false;

    QJsonObject obj = doc.object();
    QString name = obj["name"].toString();
    if (name.isEmpty()) name = obj["action"].toString();

    if (!isValidSkill(name))
        return false;

    skillName = name;

    // Extract input from various JSON shapes
    if (obj.contains("input")) {
        input = obj["input"].toString();
    } else if (obj.contains("parameters")) {
        QJsonObject params = obj["parameters"].toObject();
        input = params["query"].toString();
        if (input.isEmpty()) input = params["url"].toString();
        if (input.isEmpty()) input = params["file_path"].toString();
        // Fallback: serialize the parameters
        if (input.isEmpty())
            input = QString::fromUtf8(
                QJsonDocument(params).toJson(QJsonDocument::Compact));
    }
    return true;
}

// Pattern 5: Gemma native tool calling — <|tool_call>call:web_search{query:<|">value<|">}<tool_call|>
// Gemma 4 models emit this format when they detect tool definitions in the prompt.
bool SkillExecutor::detectGemmaToolCall(const QString &text,
                                         QString &skillName,
                                         QString &input) const
{
    // Match: <|tool_call>call:SKILL_NAME{key:<|">VALUE<|">}<tool_call|>
    // Also handle variants without the <|"> delimiters: call:name{key:value}
    static QRegularExpression re(
        R"RE(<\|?\s*tool_call\s*>?\s*call:(\w+)\s*\{)RE");

    auto m = re.match(text);
    if (!m.hasMatch())
        return false;

    QString name = m.captured(1).trimmed();
    if (!isValidSkill(name))
        return false;

    skillName = name;

    // Extract the value from the first key-value pair inside {...}
    // Handles both: {query:<|">value<|">} and {query:value}
    int braceStart = m.capturedEnd() - 1; // position of '{'
    int braceEnd = text.indexOf('}', braceStart);
    if (braceEnd < 0) braceEnd = text.length();

    QString inside = text.mid(braceStart + 1, braceEnd - braceStart - 1);

    // Strip Gemma's <|"> delimiters and extract the value
    inside.remove(QRegularExpression(R"(<\|"?>)"));
    // Format is typically "key:value" — take everything after the first ':'
    int colonPos = inside.indexOf(':');
    if (colonPos >= 0)
        input = inside.mid(colonPos + 1).trimmed();
    else
        input = inside.trimmed();

    // Clean up Gemma markup artifacts from the extracted input
    input.remove(QRegularExpression("<\\|?\"?\\|?>"));  // <|"|>, <|>, etc.
    input.remove(QRegularExpression("<\\s*/?tool_call\\s*\\|?\\s*>"));

    // The model sometimes echoes the skill description before the actual query,
    // separated by "|". Strip the description prefix if present.
    auto skillIt = m_skills.constFind(name);
    if (skillIt != m_skills.constEnd() && !skillIt->description.isEmpty()) {
        int pipePos = input.indexOf('|');
        if (pipePos > 0) {
            QString before = input.left(pipePos).trimmed().toLower();
            if (skillIt->description.toLower().contains(before) || before.length() > 30)
                input = input.mid(pipePos + 1);
        }
    }

    input = input.trimmed();
    return !input.isEmpty();
}

// Pattern 6: Natural language — "I'll search for..." / "Let me look up..."
bool SkillExecutor::detectNaturalLanguage(const QString &text,
                                           QString &skillName,
                                           QString &input) const
{
    // Intent phrases mapped to implicit actions
    struct IntentPattern {
        QStringList phrases;
        QString impliedAction; // empty means check triggers
    };

    static const QList<IntentPattern> patterns = {
        {{"i'll search", "let me search", "i will search",
          "searching for", "let me look up", "i'll look up"},
         "web_search"},
        {{"let me read that page", "i'll fetch that url", "let me open that link",
          "i'll read the page", "let me fetch"},
         "web_reader"},
        {{"let me read that document", "i'll read the file",
          "let me open that file", "i'll extract the text"},
         "document_reader"},
        {{"let me check your knowledge", "i'll search your notes",
          "searching your knowledge", "let me look in your documents"},
         "knowledge_manager"},
        {{"let me find papers", "i'll search for papers",
          "searching academic", "let me look for research"},
         "paper_finder"},
    };

    QString lower = text.toLower();

    for (const auto &pattern : patterns) {
        for (const QString &phrase : pattern.phrases) {
            int idx = lower.indexOf(phrase);
            if (idx >= 0) {
                QString name = pattern.impliedAction;
                if (!isValidSkill(name))
                    continue;

                skillName = name;
                input = extractQueryFromContext(text, name);
                if (!input.isEmpty())
                    return true;
            }
        }
    }

    // Fallback: check each skill's trigger keywords
    for (auto it = m_skills.constBegin(); it != m_skills.constEnd(); ++it) {
        const SkillDef &skill = it.value();
        int triggerHits = 0;
        for (const QString &trigger : skill.triggers) {
            if (lower.contains(trigger))
                triggerHits++;
        }
        // Require at least 2 trigger matches to reduce false positives
        if (triggerHits >= 2) {
            skillName = skill.name;
            input = extractQueryFromContext(text, skill.name);
            if (!input.isEmpty())
                return true;
        }
    }

    return false;
}

// ─────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────

bool SkillExecutor::isValidSkill(const QString &name) const
{
    return m_skills.contains(name);
}

QString SkillExecutor::extractQueryFromContext(const QString &text,
                                                const QString & /*skillName*/) const
{
    // Try to extract a quoted string near the intent phrase
    static QRegularExpression quotedRe(R"("[^"]{3,}"|'[^']{3,}')");
    auto qm = quotedRe.match(text);
    if (qm.hasMatch()) {
        QString q = qm.captured(0);
        return q.mid(1, q.length() - 2); // strip quotes
    }

    // Try to extract text after "for", "about", "on" at end of sentence
    static QRegularExpression forRe(
        R"((?:for|about|on|regarding)\s+(.{5,80})(?:\.|$))",
        QRegularExpression::MultilineOption | QRegularExpression::CaseInsensitiveOption);
    auto fm = forRe.match(text);
    if (fm.hasMatch())
        return fm.captured(1).trimmed();

    return {};
}

void SkillExecutor::setSummarizer(std::function<QString(const QString &)> fn)
{
    m_summarizer = std::move(fn);
}

// ─────────────────────────────────────────────────────────────────────
// Skill execution — delegates to existing backends
// ─────────────────────────────────────────────────────────────────────

QString SkillExecutor::executeSkill(const QString &skillName, const QString &rawInput)
{
    emit skillStarted(skillName);

    // Strip surrounding quotes that small models sometimes add: "query" → query
    QString input = rawInput.trimmed();
    if (input.length() >= 2
        && ((input.startsWith('"') && input.endsWith('"'))
            || (input.startsWith('\'') && input.endsWith('\'')))) {
        input = input.mid(1, input.length() - 2).trimmed();
    }

    QString resultText;

    if (skillName == "web_search") {
        QVariantMap searchResult = m_webSearch->search(input);
        QVariantList results = searchResult["results"].toList();

        // Filter out stale results: check URL and snippet for old year patterns.
        // Keep results from the current year or undated results; drop anything
        // clearly from a previous year (e.g. "/2023/", "2024-03", "04262024").
        int currentYear = QDate::currentDate().year();
        QVariantList freshResults;
        QVariantList staleResults;
        static QRegularExpression yearRe(R"(20[12]\d)");

        for (const QVariant &r : results) {
            QVariantMap item = r.toMap();
            QString url = item["url"].toString();
            QString snippet = item["snippet"].toString();
            QString combined = url + " " + snippet;

            bool isStale = false;
            auto it = yearRe.globalMatch(combined);
            while (it.hasNext()) {
                int yr = it.next().captured(0).toInt();
                if (yr > 0 && yr < currentYear) { isStale = true; break; }
            }

            if (isStale)
                staleResults.append(r);
            else
                freshResults.append(r);
        }

        // Prefer fresh results; fall back to stale ones if we have nothing fresh
        if (!freshResults.isEmpty())
            results = freshResults + staleResults;

        for (int i = 0; i < results.size() && i < 5; ++i) {
            QVariantMap item = results[i].toMap();
            qInfo() << "  Result" << i << ":" << item["title"].toString().left(80)
                     << "|" << item["url"].toString().left(80);
        }

        // Fetch page content from up to 3 real results (skip search-engine result pages).
        // 350 chars per page × 3 = ~1050 chars total — safe for a 4096-token context.
        static const QStringList searchEngineDomains = {
            "yahoo.com/search", "google.com/search", "bing.com/search",
            "duckduckgo.com", "search.yahoo.com", "yandex."
        };
        auto isSearchEnginePage = [&](const QString &url) {
            for (const QString &d : searchEngineDomains)
                if (url.contains(d)) return true;
            return false;
        };

        if (m_compactResults) {
            // Compact mode for LiteRT (4096-token context).
            // Strategy: fetch top 5 pages, summarize in 3 batches using the
            // LLM, then combine the 3 summaries into the final result.
            //   Batch 1: source 1 alone  (most relevant)
            //   Batch 2: sources 2 & 3 together
            //   Batch 3: sources 4 & 5 together
            // This lets the LLM digest real page content instead of tiny snippets.
            static const int kMaxPerPage = 2000;

            // ── Step 1: Fetch up to 5 pages ──
            struct PageData { QString title; QString url; QString content; };
            QVector<PageData> pages;

            for (const QVariant &r : results) {
                if (pages.size() >= 5) break;
                QVariantMap item = r.toMap();
                QString url     = item["url"].toString();
                QString title   = item["title"].toString();
                QString snippet = item["snippet"].toString().trimmed();
                if (isSearchEnginePage(url))
                    continue;

                QString pageText;
                QVariantMap page = m_webReader->fetch(url);
                if (page["success"].toBool()) {
                    pageText = page["text"].toString().trimmed();
                    qInfo() << "  Fetched page:" << url.left(60) << pageText.length() << "chars";
                }

                QString content = pageText.isEmpty() ? snippet : pageText;
                if (content.isEmpty())
                    continue;
                if (content.length() > kMaxPerPage)
                    content = content.left(kMaxPerPage) + "...";

                pages.append({title, url, content});
            }

            if (pages.isEmpty()) {
                resultText = "No results found for \"" + input + "\".";
            } else if (!m_summarizer) {
                // No summarizer available — fall back to truncated content
                QStringList compiled;
                for (const auto &p : pages)
                    compiled.append("Source: " + p.title + "\n" + p.content.left(400));
                resultText = "Information for \"" + input + "\":\n\n"
                             + compiled.join("\n\n---\n\n");
            } else {
                // ── Step 2: Summarize in 3 batches ──
                auto summarizeBatch = [&](const QString &batchContent) -> QString {
                    QString prompt =
                        "<start_of_turn>user\n"
                        "Extract the key facts, numbers, and dates from this content. "
                        "Be concise and specific.\n\n"
                        + batchContent +
                        "<end_of_turn>\n"
                        "<start_of_turn>model\n";
                    return m_summarizer(prompt).trimmed();
                };

                QStringList summaries;

                // Batch 1: source 1 alone
                if (pages.size() >= 1) {
                    QString batch = "Source: " + pages[0].title + " (" + pages[0].url + ")\n" + pages[0].content;
                    QString s = summarizeBatch(batch);
                    if (!s.isEmpty()) summaries.append(s);
                    qInfo() << "  Summary 1:" << s.length() << "chars";
                }

                // Batch 2: sources 2 & 3 together
                if (pages.size() >= 2) {
                    QString batch = "Source: " + pages[1].title + " (" + pages[1].url + ")\n" + pages[1].content;
                    if (pages.size() >= 3)
                        batch += "\n\nSource: " + pages[2].title + " (" + pages[2].url + ")\n" + pages[2].content;
                    QString s = summarizeBatch(batch);
                    if (!s.isEmpty()) summaries.append(s);
                    qInfo() << "  Summary 2:" << s.length() << "chars";
                }

                // Batch 3: sources 4 & 5 together
                if (pages.size() >= 4) {
                    QString batch = "Source: " + pages[3].title + " (" + pages[3].url + ")\n" + pages[3].content;
                    if (pages.size() >= 5)
                        batch += "\n\nSource: " + pages[4].title + " (" + pages[4].url + ")\n" + pages[4].content;
                    QString s = summarizeBatch(batch);
                    if (!s.isEmpty()) summaries.append(s);
                    qInfo() << "  Summary 3:" << s.length() << "chars";
                }

                // ── Step 3: Combine summaries ──
                if (summaries.isEmpty()) {
                    // Summarizer failed — fall back to raw content
                    resultText = "Source: " + pages[0].title + "\n" + pages[0].content.left(2400);
                } else {
                    resultText = "Research findings for \"" + input + "\":\n\n"
                                 + summaries.join("\n\n");
                }
            }
        } else {
            // Full mode: fetch pages → summarize each → compile.
            struct ArticleResult {
                QString title;
                QString url;
                QString summary;
            };
            QVector<ArticleResult> articleResults;

            for (const QVariant &r : results) {
                QVariantMap item = r.toMap();
                QString url   = item["url"].toString();
                QString title = item["title"].toString();
                if (isSearchEnginePage(url))
                    continue;

                QVariantMap page = m_webReader->fetch(url);
                QString fullText;
                if (page["success"].toBool())
                    fullText = page["text"].toString().trimmed();
                else
                    fullText = item["snippet"].toString().trimmed();

                if (fullText.isEmpty())
                    continue;

                QString summary;
                if (m_summarizer) {
                    QString prompt =
                        "<start_of_turn>user\n"
                        "Article: " + title + "\nURL: " + url + "\n\n" +
                        fullText + "\n\n"
                        "Summarise this article."
                        "<end_of_turn>\n"
                        "<start_of_turn>model\n";
                    summary = m_summarizer(prompt).trimmed();
                }
                if (summary.isEmpty())
                    summary = fullText;

                articleResults.append({title, url, summary});
            }

            if (articleResults.isEmpty()) {
                resultText = "No results found for \"" + input + "\".";
            } else {
                QStringList compiled;
                for (const ArticleResult &a : articleResults)
                    compiled.append("### " + a.title + "\nURL: " + a.url + "\n\n" + a.summary);

                resultText = "Summarised articles for \"" + input + "\" (" +
                             QString::number(articleResults.size()) + " sources):\n\n" +
                             compiled.join("\n\n---\n\n");
            }
        }

    } else if (skillName == "web_reader") {
        QVariantMap page = m_webReader->fetch(input);
        if (page["success"].toBool()) {
            QString pageText = page["text"].toString().trimmed();
            QString title = page["title"].toString();
            resultText = "Content from: " + input + "\n";
            if (!title.isEmpty())
                resultText += "Title: " + title + "\n";
            resultText += "\n" + pageText;
        } else {
            resultText = "Failed to fetch URL: " + input + "\n"
                         "Error: " + page["error"].toString();
        }

    } else if (skillName == "document_reader") {
        // Delegated via ChatController / FileProcessor — return instruction
        resultText = "Document reading for: " + input + "\n"
                     "Note: Document reading is handled by the file processor. "
                     "The content should already be in the conversation context.";

    } else if (skillName == "knowledge_manager") {
        // Delegated via KnowledgeController
        resultText = "Knowledge query: " + input + "\n"
                     "Note: Knowledge search is handled by the knowledge controller.";

    } else if (skillName == "paper_finder") {
        QVariantMap result = m_webSearch->searchAcademic(input);
        QVariantList papers = result["results"].toList();

        QString summary;
        for (const QVariant &p : papers) {
            QVariantMap paper = p.toMap();
            summary += "- **" + paper["title"].toString() + "**";
            if (!paper["year"].toString().isEmpty())
                summary += " (" + paper["year"].toString() + ")";
            summary += "\n";
            if (!paper["authors"].toString().isEmpty())
                summary += "  Authors: " + paper["authors"].toString() + "\n";
            if (!paper["abstract"].toString().isEmpty()) {
                QString abstract = paper["abstract"].toString();
                if (abstract.length() > 300)
                    abstract = abstract.left(300) + "...";
                summary += "  " + abstract + "\n";
            }
            if (!paper["url"].toString().isEmpty())
                summary += "  URL: " + paper["url"].toString() + "\n";
            summary += "\n";
        }

        resultText = "Academic papers for: \"" + input + "\"\n"
                     "Found " + QString::number(papers.size()) + " papers.\n\n"
                     + summary;

    } else {
        QString error = "Unknown skill: " + skillName;
        emit skillFailed(skillName, error);
        return error;
    }

    QVariantMap resultMap;
    resultMap["content"] = resultText;
    emit skillCompleted(skillName, resultMap);
    return resultText;
}

// ─────────────────────────────────────────────────────────────────────
// Skill list (for QML / SkillController)
// ─────────────────────────────────────────────────────────────────────

QVariantList SkillExecutor::skillList() const
{
    QVariantList list;
    for (auto it = m_skills.constBegin(); it != m_skills.constEnd(); ++it) {
        QVariantMap skill;
        skill["name"] = it.value().name;
        skill["description"] = it.value().description;
        skill["triggers"] = QVariant(it.value().triggers);
        list.append(skill);
    }
    return list;
}
