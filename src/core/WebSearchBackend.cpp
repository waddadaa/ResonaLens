#include "WebSearchBackend.h"

#include <websearch/websearch.h>

#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QRegularExpression>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSet>
#include <QDebug>

WebSearchBackend::WebSearchBackend(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

QVariantMap WebSearchBackend::search(const QString &query, int maxResults)
{
    qInfo() << "WebSearch: starting search for:" << query << "maxResults:" << maxResults;

    QVariantList list;

    // ── Phase 1: Google News RSS — always fresh, reputable sources ──
    // This is a free RSS feed that returns current news from Reuters, CNBC,
    // WSJ, BBC, etc. No API key needed. Runs first to guarantee freshness.
    {
        QUrl rssUrl("https://news.google.com/rss/search");
        QUrlQuery rssQuery;
        rssQuery.addQueryItem("q", query);
        rssQuery.addQueryItem("hl", "en-US");
        rssQuery.addQueryItem("gl", "US");
        rssQuery.addQueryItem("ceid", "US:en");
        rssUrl.setQuery(rssQuery);

        QNetworkRequest req(rssUrl);
        req.setRawHeader("User-Agent", "Mozilla/5.0 (compatible; ResonaLens/0.1)");

        QEventLoop loop;
        QTimer timeout;
        timeout.setSingleShot(true);
        QNetworkReply *reply = m_nam->get(req);
        connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
        connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);
        timeout.start(6000);
        loop.exec();

        if (reply->isFinished() && reply->error() == QNetworkReply::NoError) {
            QString xml = QString::fromUtf8(reply->readAll());

            // Parse RSS items: <item><title>...</title><link>...</link><description>...</description></item>
            static QRegularExpression itemRe(
                R"(<item>.*?<title>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>.*?<link>(.*?)</link>(?:.*?<description>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</description>)?.*?</item>)",
                QRegularExpression::DotMatchesEverythingOption);

            auto it = itemRe.globalMatch(xml);
            int newsCount = 0;
            while (it.hasNext() && newsCount < maxResults) {
                auto m = it.next();
                QVariantMap item;
                item["title"]   = m.captured(1).trimmed();
                item["url"]     = m.captured(2).trimmed();
                QString desc    = m.captured(3).trimmed();
                // Strip HTML tags from description
                desc.remove(QRegularExpression("<[^>]*>"));
                item["snippet"] = desc;
                list.append(item);
                newsCount++;
            }
            qInfo() << "WebSearch: Google News RSS returned" << newsCount << "results";
        } else {
            qWarning() << "WebSearch: Google News RSS failed";
        }
        reply->deleteLater();
    }

    // ── Phase 2: websearchlib (14 engines) — supplement if news didn't cover it ──
    if (list.size() < maxResults) {
        int remaining = maxResults - list.size();
        auto mgr = websearch::createDefaultSearchManager();
        auto results = mgr.search(query.toStdString(),
                                  {.max_results = remaining, .timeout_ms = 10000});

        qInfo() << "WebSearch: websearchlib returned" << results.size() << "additional results";

        // Deduplicate against Google News results
        QSet<QString> existingUrls;
        for (const QVariant &v : list)
            existingUrls.insert(v.toMap()["url"].toString());

        for (const auto &r : results) {
            QString url = QString::fromStdString(r.url);
            if (existingUrls.contains(url)) continue;
            QVariantMap item;
            item["title"]   = QString::fromStdString(r.title);
            item["url"]     = url;
            item["snippet"] = QString::fromStdString(r.snippet);
            list.append(item);
            if (list.size() >= maxResults) break;
        }
    }

    qInfo() << "WebSearch: total" << list.size() << "results";

    QVariantMap out;
    out["results"] = list;
    out["query"]   = query;
    out["count"]   = list.size();
    return out;
}

QVariantMap WebSearchBackend::searchAcademic(const QString &query, int maxResults)
{
    QVariantMap result;
    QVariantList results;

    // Semantic Scholar API
    QUrl url("https://api.semanticscholar.org/graph/v1/paper/search");
    QUrlQuery urlQuery;
    urlQuery.addQueryItem("query", query);
    urlQuery.addQueryItem("limit", QString::number(maxResults));
    urlQuery.addQueryItem("fields", "title,authors,year,abstract,citationCount,externalIds,openAccessPdf");
    url.setQuery(urlQuery);

    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "ResonaLens/0.1");
    request.setTransferTimeout(10 * 1000);

    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);
    timeout.start(12 * 1000);
    loop.exec();
    if (!reply->isFinished())
        reply->abort();

    if (reply->error() == QNetworkReply::NoError) {
        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        QJsonArray data = doc.object()["data"].toArray();

        for (const QJsonValue &v : data) {
            QJsonObject paper = v.toObject();
            QVariantMap item;
            item["title"] = paper["title"].toString();
            item["year"] = paper["year"].toInt();
            item["abstract"] = paper["abstract"].toString();
            item["citationCount"] = paper["citationCount"].toInt();

            // Authors
            QStringList authors;
            for (const QJsonValue &a : paper["authors"].toArray()) {
                authors.append(a.toObject()["name"].toString());
            }
            item["authors"] = authors.join(", ");

            // DOI
            QJsonObject externalIds = paper["externalIds"].toObject();
            item["doi"] = externalIds["DOI"].toString();

            // Open access PDF
            QJsonObject pdf = paper["openAccessPdf"].toObject();
            item["pdfUrl"] = pdf["url"].toString();

            results.append(item);
        }
    }

    reply->deleteLater();

    result["results"] = results;
    result["query"] = query;
    result["count"] = results.size();
    return result;
}

QVariantMap WebSearchBackend::fetchStockQuote(const QString &ticker)
{
    QVariantMap result;

    // Yahoo Finance v8 chart API — free, no key, returns real-time quote JSON.
    QString urlStr = "https://query1.finance.yahoo.com/v8/finance/chart/"
                     + ticker.toUpper().trimmed()
                     + "?interval=1d&range=1d";
    QUrl url(urlStr);
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "Mozilla/5.0 (compatible; ResonaLens/0.1)");
    request.setRawHeader("Accept", "application/json");
    request.setTransferTimeout(10 * 1000);

    QEventLoop loop;
    QTimer timeout;
    timeout.setSingleShot(true);
    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    connect(&timeout, &QTimer::timeout, &loop, &QEventLoop::quit);
    timeout.start(12 * 1000);
    loop.exec();
    if (!reply->isFinished())
        reply->abort();

    if (reply->error() == QNetworkReply::NoError) {
        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        QJsonObject chart = doc.object()["chart"].toObject();
        QJsonArray resultArr = chart["result"].toArray();

        if (!resultArr.isEmpty()) {
            QJsonObject meta = resultArr[0].toObject()["meta"].toObject();
            result["symbol"]        = meta["symbol"].toString();
            result["name"]          = meta["longName"].toString();
            result["price"]         = meta["regularMarketPrice"].toDouble();
            result["previousClose"] = meta["chartPreviousClose"].toDouble();
            result["currency"]      = meta["currency"].toString();
            result["marketState"]   = meta["marketState"].toString();
            result["exchange"]      = meta["exchangeName"].toString();

            double price = result["price"].toDouble();
            double prev  = result["previousClose"].toDouble();
            if (prev > 0) {
                result["change"]        = price - prev;
                result["changePercent"] = ((price - prev) / prev) * 100.0;
            }
            result["success"] = true;
        } else {
            result["error"]   = chart["error"].toObject()["description"].toString();
            result["success"] = false;
        }
    } else {
        result["error"]   = reply->errorString();
        result["success"] = false;
    }

    reply->deleteLater();
    return result;
}
