// src/core/HttpClientQt.cpp
// Qt-based HTTP transport for Android where curl's mbedTLS cannot do TLS.
// Uses QNetworkAccessManager which leverages the device's native OpenSSL.
// Same HttpClient interface as the curl version — drop-in replacement.
#ifdef WEBSEARCH_USE_QT_HTTP

#include "core/HttpClient.h"
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QTimer>
#include <QUrl>
#include <QString>
#include <QByteArray>
#include <random>

namespace websearch {

struct HttpClient::Impl {
    // Each HttpClient instance (one per engine thread) gets its own QNAM.
    // QNAM is safe to use on any thread as long as it's created on that thread.
    QNetworkAccessManager *nam = nullptr;
};

HttpClient::HttpClient() : m_impl(std::make_unique<Impl>()) {
    m_impl->nam = new QNetworkAccessManager();
}

HttpClient::~HttpClient() {
    delete m_impl->nam;
}

HttpClient::Response HttpClient::execute(const HttpRequest& req, int timeout_ms) {
    Response resp;
    if (!m_impl->nam) { resp.error = "QNAM not initialized"; return resp; }

    QUrl url(QString::fromStdString(req.url));
    QNetworkRequest qreq(url);

    // User-Agent
    qreq.setRawHeader("User-Agent", randomUserAgent());
    qreq.setRawHeader("Accept",
        "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
    qreq.setRawHeader("Accept-Language", "en-US,en;q=0.5");
    qreq.setRawHeader("Accept-Encoding", "gzip, deflate");

    // Custom headers
    for (const auto& [k, v] : req.headers) {
        qreq.setRawHeader(QByteArray::fromStdString(k),
                          QByteArray::fromStdString(v));
    }

    // Cookies
    if (!req.cookies.empty()) {
        QByteArray cookieStr;
        for (const auto& [k, v] : req.cookies) {
            if (!cookieStr.isEmpty()) cookieStr += "; ";
            cookieStr += QByteArray::fromStdString(k) + "=" + QByteArray::fromStdString(v);
        }
        qreq.setRawHeader("Cookie", cookieStr);
    }

    // Execute request with event loop + timeout
    QEventLoop loop;
    QNetworkReply *reply = nullptr;

    if (req.method == "POST") {
        qreq.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
        reply = m_impl->nam->post(qreq, QByteArray::fromStdString(req.body));
    } else {
        reply = m_impl->nam->get(qreq);
    }

    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QTimer::singleShot(timeout_ms, &loop, &QEventLoop::quit);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort();
        resp.error = "timeout";
        reply->deleteLater();
        return resp;
    }

    if (reply->error() != QNetworkReply::NoError) {
        resp.error = reply->errorString().toStdString();
        reply->deleteLater();
        return resp;
    }

    resp.status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    // Handle redirects (QNAM follows them by default in Qt6, but check anyway)
    resp.body = reply->readAll().toStdString();
    reply->deleteLater();
    return resp;
}

const char* randomUserAgent() {
    static const char* agents[] = {
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0",
        "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36",
    };
    static constexpr size_t count = sizeof(agents) / sizeof(agents[0]);
    thread_local std::mt19937 rng(std::random_device{}());
    std::uniform_int_distribution<size_t> dist(0, count - 1);
    return agents[dist(rng)];
}

} // namespace websearch

#endif // WEBSEARCH_USE_QT_HTTP
