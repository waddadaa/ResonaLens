#pragma once

#include <QObject>
#include <QVariantMap>
#include <QUrl>
#include <QString>

class QNetworkAccessManager;

class WebReaderBackend : public QObject {
    Q_OBJECT

public:
    explicit WebReaderBackend(QObject *parent = nullptr);

    QVariantMap fetch(const QString &url);
    QString extractText(const QByteArray &html);
    QStringList extractImages(const QByteArray &html, const QUrl &baseUrl);

private:
    QNetworkAccessManager *m_nam = nullptr;
};
