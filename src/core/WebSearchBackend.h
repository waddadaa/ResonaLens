#pragma once

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QString>

class QNetworkAccessManager;

class WebSearchBackend : public QObject {
    Q_OBJECT

public:
    explicit WebSearchBackend(QObject *parent = nullptr);

    QVariantMap search(const QString &query, int maxResults = 5);
    QVariantMap searchAcademic(const QString &query, int maxResults = 5);
    // Returns real-time quote data for a stock ticker via Yahoo Finance JSON API.
    // Returns map with: symbol, price, currency, change, changePercent, marketState, name
    QVariantMap fetchStockQuote(const QString &ticker);

private:
    QNetworkAccessManager *m_nam = nullptr;
};
