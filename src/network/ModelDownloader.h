#pragma once

#include <QObject>
#include <QString>
#include <QFile>
#include <QElapsedTimer>

class QNetworkAccessManager;
class QNetworkReply;

class ModelDownloader : public QObject {
    Q_OBJECT

public:
    explicit ModelDownloader(QObject *parent = nullptr);
    ~ModelDownloader() override;

    void setToken(const QString &token);

public slots:
    void download(const QString &repoId, const QString &filename,
                  const QString &destPath, const QString &token = "");
    void cancel();

signals:
    void progressChanged(double percent, double speedMBps, qint64 bytesReceived, qint64 bytesTotal);
    void downloadFinished(const QString &filePath);
    void downloadError(const QString &error);

private:
    void acquireWakeLock();
    void releaseWakeLock();

    QNetworkAccessManager *m_nam = nullptr;
    QNetworkReply *m_reply = nullptr;
    QFile *m_file = nullptr;
    QString m_destPath;
    QString m_token;
    QElapsedTimer m_speedTimer;
    qint64 m_lastBytesReceived = 0;
    bool m_wakeLockHeld = false;

    // Auto-retry state
    QString m_lastRepoId;
    QString m_lastFilename;
    QString m_lastToken;
    int m_retryCount = 0;
    static constexpr int MAX_RETRIES = 5;
};
