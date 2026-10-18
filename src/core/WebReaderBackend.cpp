#include "WebReaderBackend.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QTimer>
#include <QRegularExpression>
#include <QDebug>

WebReaderBackend::WebReaderBackend(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

QVariantMap WebReaderBackend::fetch(const QString &url)
{
    QVariantMap result;

    QUrl requestUrl(url);
    QNetworkRequest request(requestUrl);
    request.setRawHeader("User-Agent",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36");
    request.setRawHeader("Accept", "text/html,application/xhtml+xml");
    request.setRawHeader("Accept-Language", "en-US,en;q=0.9");
    request.setMaximumRedirectsAllowed(5);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(15 * 1000);

    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);
    timeout.start(20 * 1000);
    loop.exec();
    if (!reply->isFinished())
        reply->abort();

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray html = reply->readAll();
        QString text = extractText(html);

        // Detect blocked/error pages — silently fail so callers use the snippet fallback
        bool isBlocked = text.isEmpty()
            || text.contains("captcha", Qt::CaseInsensitive)
            || text.contains("Access Denied", Qt::CaseInsensitive)
            || text.contains("Just a moment", Qt::CaseInsensitive) // Cloudflare
            || text.contains("Enable JavaScript", Qt::CaseInsensitive)
            || text.contains("robot", Qt::CaseInsensitive);

        result["text"]    = isBlocked ? QString() : text;
        result["content"] = isBlocked ? QString() : text;
        result["url"]     = url;
        result["success"] = !isBlocked && !text.isEmpty();
    } else {
        result["error"]   = reply->errorString();
        result["success"] = false;
    }

    reply->deleteLater();
    return result;
}

QString WebReaderBackend::extractText(const QByteArray &html)
{
    QString full = QString::fromUtf8(html);

    // ── Step 1: strip noise elements entirely ────────────────────────────
    static QRegularExpression scriptRe("<script[^>]*>.*?</script>",
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static QRegularExpression styleRe("<style[^>]*>.*?</style>",
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static QRegularExpression svgRe("<svg[^>]*>.*?</svg>",
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static QRegularExpression noiseRe(
        "<(nav|header|footer|aside|form|button|noscript|iframe|figure|figcaption|"
        "dialog|menu|menuitem|template)[^>]*>.*?</\\1>",
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);

    full.remove(scriptRe);
    full.remove(styleRe);
    full.remove(svgRe);
    full.remove(noiseRe);

    // ── Step 2: prefer semantic content containers ────────────────────────
    // Try <main>, <article>, or <div role="main"> first — they hold the real content
    static QRegularExpression mainRe(
        "<main[^>]*>(.*?)</main>",
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static QRegularExpression articleRe(
        "<article[^>]*>(.*?)</article>",
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static QRegularExpression roleMainRe(
        "<[^>]+role\\s*=\\s*[\"']main[\"'][^>]*>(.*?)</[a-z]+>",
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);

    QString body;
    auto mainMatch = mainRe.match(full);
    if (mainMatch.hasMatch()) {
        body = mainMatch.captured(1);
    } else {
        auto articleMatch = articleRe.match(full);
        if (articleMatch.hasMatch()) {
            body = articleMatch.captured(1);
        } else {
            auto roleMatch = roleMainRe.match(full);
            body = roleMatch.hasMatch() ? roleMatch.captured(1) : full;
        }
    }

    // ── Step 3: strip remaining tags ─────────────────────────────────────
    static QRegularExpression tagRe("<[^>]+>");
    body.replace(tagRe, " ");

    // ── Step 4: decode common HTML entities ──────────────────────────────
    body.replace("&amp;",   "&");
    body.replace("&lt;",    "<");
    body.replace("&gt;",    ">");
    body.replace("&quot;",  "\"");
    body.replace("&#39;",   "'");
    body.replace("&#x27;",  "'");
    body.replace("&apos;",  "'");
    body.replace("&nbsp;",  " ");
    body.replace("&#x2F;",  "/");
    body.replace("&mdash;", "—");
    body.replace("&ndash;", "–");
    body.replace("&hellip;","...");

    // ── Step 5: collapse whitespace ───────────────────────────────────────
    static QRegularExpression wsRe("\\s+");
    body.replace(wsRe, " ");

    return body.trimmed();
}

QStringList WebReaderBackend::extractImages(const QByteArray &html, const QUrl &baseUrl)
{
    QStringList images;
    QString text = QString::fromUtf8(html);

    static QRegularExpression imgRe("<img[^>]+src=[\"']([^\"']+)[\"']",
                                     QRegularExpression::CaseInsensitiveOption);
    auto it = imgRe.globalMatch(text);
    while (it.hasNext()) {
        auto match = it.next();
        QUrl imgUrl = baseUrl.resolved(QUrl(match.captured(1)));
        images.append(imgUrl.toString());
    }

    return images;
}
