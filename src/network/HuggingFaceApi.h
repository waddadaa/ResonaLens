#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

class QNetworkAccessManager;

class HuggingFaceApi : public QObject {
    Q_OBJECT

public:
    explicit HuggingFaceApi(QObject *parent = nullptr);

    void setToken(const QString &token);

public slots:
    void searchModels(const QString &query);
    void getModelInfo(const QString &repoId);
    void getModelFiles(const QString &repoId);
    void validateToken(const QString &token);

signals:
    void searchResultsReady(const QVariantList &results);
    void modelInfoReady(const QVariantMap &info);
    void modelFilesReady(const QVariantList &files);
    void tokenValidated(bool valid);

private:
    QNetworkAccessManager *m_nam = nullptr;
    QString m_token;
};
