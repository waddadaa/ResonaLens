#include "ModelDownloader.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QSslError>
#include <QUrl>
#include <QFileInfo>
#include <QStorageInfo>
#include <QTimer>
#include <QDebug>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QCoreApplication>
#include <android/api-level.h>
#endif

ModelDownloader::ModelDownloader(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

ModelDownloader::~ModelDownloader()
{
    releaseWakeLock();
}

void ModelDownloader::acquireWakeLock()
{
#ifdef Q_OS_ANDROID
    if (m_wakeLockHeld) return;

    // Start foreground service — keeps the process alive with CPU + WiFi locks
    // even when the app is in the background or screen is off.
    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative", "activity",
        "()Landroid/app/Activity;");
    if (activity.isValid()) {
        QJniObject intent("android/content/Intent",
            "(Landroid/content/Context;Ljava/lang/Class;)V",
            activity.object(),
            QJniObject::callStaticObjectMethod(
                "java/lang/Class", "forName",
                "(Ljava/lang/String;)Ljava/lang/Class;",
                QJniObject::fromString("com.resonalens.app.DownloadService").object<jstring>()
            ).object());

        if (android_get_device_api_level() >= 26) {
            activity.callObjectMethod("startForegroundService",
                "(Landroid/content/Intent;)Landroid/content/ComponentName;",
                intent.object());
        } else {
            activity.callObjectMethod("startService",
                "(Landroid/content/Intent;)Landroid/content/ComponentName;",
                intent.object());
        }
    }

    m_wakeLockHeld = true;
    qInfo() << "Download foreground service started";
#endif
}

void ModelDownloader::releaseWakeLock()
{
#ifdef Q_OS_ANDROID
    if (!m_wakeLockHeld) return;

    // Stop foreground service
    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative", "activity",
        "()Landroid/app/Activity;");
    if (activity.isValid()) {
        QJniObject intent("android/content/Intent",
            "(Landroid/content/Context;Ljava/lang/Class;)V",
            activity.object(),
            QJniObject::callStaticObjectMethod(
                "java/lang/Class", "forName",
                "(Ljava/lang/String;)Ljava/lang/Class;",
                QJniObject::fromString("com.resonalens.app.DownloadService").object<jstring>()
            ).object());
        activity.callMethod<jboolean>("stopService",
            "(Landroid/content/Intent;)Z", intent.object());
    }

    m_wakeLockHeld = false;
    qInfo() << "Download foreground service stopped";
#endif
}

void ModelDownloader::setToken(const QString &token)
{
    m_token = token;
}

void ModelDownloader::download(const QString &repoId, const QString &filename,
                                const QString &destPath, const QString &token)
{
    // Abort any in-progress download before starting a new one
    if (m_reply) {
        m_reply->abort();
        m_reply->deleteLater();
        m_reply = nullptr;
    }
    if (m_file) {
        m_file->close();
        m_file->deleteLater();
        m_file = nullptr;
    }

    m_destPath = destPath;
    m_lastRepoId = repoId;
    m_lastFilename = filename;
    m_lastToken = token.isEmpty() ? m_token : token;
    if (m_retryCount <= 0) m_retryCount = 0; // Reset on fresh download, preserve on retry
    QString partPath = destPath + ".part";

    // Use provided token or stored token
    QString authToken = token.isEmpty() ? m_token : token;

    // Check for existing partial download (resume support). Clamp to a sane
    // range — a negative size (impossible on sane filesystems but we're
    // paranoid) or an absurdly huge value would produce an invalid Range
    // header like "bytes=-1-".
    qint64 existingSize = 0;
    QFileInfo partInfo(partPath);
    if (partInfo.exists()) {
        existingSize = partInfo.size();
        if (existingSize < 0)
            existingSize = 0;
    }

    // Build the actual HuggingFace download URL
    // Format: https://huggingface.co/{repoId}/resolve/main/{filename}
    // Percent-encode user-controlled segments so a crafted filename/repoId
    // cannot break out of the intended path.
    const QByteArray encRepo = QUrl::toPercentEncoding(repoId, "/");
    const QByteArray encFile = QUrl::toPercentEncoding(filename, "/");
    QUrl url(QStringLiteral("https://huggingface.co/") + QString::fromUtf8(encRepo)
             + QStringLiteral("/resolve/main/") + QString::fromUtf8(encFile));

    qInfo() << "Downloading:" << url.toString();

    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "ResonaLens/0.1");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setMaximumRedirectsAllowed(5);

    // Auth header for gated models
    if (!authToken.isEmpty())
        request.setRawHeader("Authorization", ("Bearer " + authToken).toUtf8());

    // Resume support via Range header
    if (existingSize > 0)
        request.setRawHeader("Range", ("bytes=" + QByteArray::number(existingSize) + "-"));

    // Model files can be gigabytes, so we don't cap total transfer time.
    // We DO set an initial-response timeout via transferTimeout so a dead
    // server can't stall the connection forever; stall detection on the
    // download-progress side handles mid-transfer hangs.
    request.setTransferTimeout(60 * 1000); // 60s to receive first bytes

    // Refuse to start if the target volume is clearly out of space. We
    // don't know the final file size yet, but a minimum headroom check
    // catches the common "phone is full" case before we open any handles.
    {
        const QFileInfo destInfo(QFileInfo(destPath).absolutePath());
        QStorageInfo storage(destInfo.absoluteFilePath());
        const qint64 kMinFreeBytes = 256LL * 1024 * 1024; // 256 MB safety margin
        if (storage.isValid() && storage.bytesAvailable() >= 0
            && storage.bytesAvailable() < kMinFreeBytes) {
            emit downloadError(QStringLiteral(
                "Not enough free space on device to download this model."));
            return;
        }
    }

    m_file = new QFile(partPath, this);
    QIODevice::OpenMode mode = existingSize > 0 ?
        QIODevice::WriteOnly | QIODevice::Append :
        QIODevice::WriteOnly;

    if (!m_file->open(mode)) {
        emit downloadError("Cannot open file for writing: " + partPath);
        return;
    }

    acquireWakeLock();

    m_reply = m_nam->get(request);
    m_speedTimer.start();
    m_lastBytesReceived = existingSize;

    // Never blanket-ignore SSL errors: a MITM can serve any binary as the
    // model. Log and let Qt abort the reply if the CA chain doesn't validate.
    connect(m_reply, &QNetworkReply::sslErrors, this, [](const QList<QSslError> &errors) {
        for (const auto &e : errors)
            qWarning() << "SSL error (aborting download):" << e.errorString();
    });

    connect(m_reply, &QNetworkReply::readyRead, this, [this]() {
        if (m_file)
            m_file->write(m_reply->readAll());
    });

    connect(m_reply, &QNetworkReply::downloadProgress,
            this, [this, existingSize](qint64 bytesReceived, qint64 bytesTotal) {
        qint64 totalReceived = existingSize + bytesReceived;
        qint64 totalSize = (bytesTotal > 0) ? existingSize + bytesTotal : 0;

        double percent = totalSize > 0 ? (totalReceived * 100.0 / totalSize) : 0;

        double elapsed = m_speedTimer.elapsed() / 1000.0;
        double speedMBps = 0;
        if (elapsed > 0.5) {
            qint64 delta = totalReceived - m_lastBytesReceived;
            speedMBps = delta / elapsed / (1024.0 * 1024.0);
            m_speedTimer.restart();
            m_lastBytesReceived = totalReceived;
        }

        emit progressChanged(percent, speedMBps, totalReceived, totalSize);
    });

    connect(m_reply, &QNetworkReply::finished, this, [this]() {
        if (m_file) {
            m_file->close();
            m_file->deleteLater();
            m_file = nullptr;
        }

        // Capture and clear m_reply BEFORE emitting any signal.
        // downloadFinished is a direct connection so onDownloadFinished runs
        // synchronously and may call download() creating a new m_reply.
        // Clearing first prevents the cleanup below from clobbering the new reply.
        QNetworkReply *reply = m_reply;
        m_reply = nullptr;

        // HTTP status is only meaningful if Qt actually reached the HTTP
        // layer — a DNS/TLS failure leaves the attribute invalid, which
        // toInt()'s silently to 0 and would false-match below.
        const QVariant statusAttr = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute);
        const int statusCode = statusAttr.isValid() ? statusAttr.toInt() : 0;
        qInfo() << "Download finished — HTTP" << statusCode << "error:" << reply->error() << reply->errorString();

        releaseWakeLock();

        auto error = reply->error();

        if (error == QNetworkReply::NoError) {
            m_retryCount = 0;
            const QString partPath = m_destPath + ".part";
            // If a file at destPath already exists (previous aborted run),
            // QFile::rename won't overwrite — remove it first.
            if (QFile::exists(m_destPath))
                QFile::remove(m_destPath);
            if (!QFile::rename(partPath, m_destPath)) {
                emit downloadError(QStringLiteral("Failed to finalize download: could not rename ")
                                   + partPath + QStringLiteral(" to ") + m_destPath);
                reply->deleteLater();
                return;
            }
            emit downloadFinished(m_destPath);
        } else if (error == QNetworkReply::OperationCanceledError && m_retryCount < 0) {
            // User explicitly cancelled via cancel() — m_retryCount set to -1
        } else if (statusCode == 401 || statusCode == 403) {
            m_retryCount = 0;
            QFile::remove(m_destPath + ".part");
            emit downloadError("Access denied. This is a gated model.\n\n"
                              "1. Go to the model page on HuggingFace\n"
                              "2. Accept the license agreement\n"
                              "3. Add your HuggingFace token in Settings\n\n"
                              "https://huggingface.co/settings/tokens");
        } else if (statusCode == 404) {
            m_retryCount = 0;
            QFile::remove(m_destPath + ".part");
            emit downloadError("File not found (404). The model file may have been moved or renamed.");
        } else if (m_retryCount < MAX_RETRIES) {
            // Transient error — auto-retry with resume
            m_retryCount++;
            int delaySec = m_retryCount * 2; // 2s, 4s, 6s, 8s, 10s
            qInfo() << "Download interrupted:" << reply->errorString()
                    << "— retrying in" << delaySec << "s (attempt" << m_retryCount << "/" << MAX_RETRIES << ")";
            QTimer::singleShot(delaySec * 1000, this, [this]() {
                download(m_lastRepoId, m_lastFilename, m_destPath, m_lastToken);
            });
            reply->deleteLater();
            return; // Don't release wake lock — we're retrying
        } else {
            m_retryCount = 0;
            emit downloadError("Download failed after " + QString::number(MAX_RETRIES) + " retries: " + reply->errorString());
        }

        reply->deleteLater();
    });
}

void ModelDownloader::cancel()
{
    m_retryCount = -1; // Signal explicit cancel — don't auto-retry
    if (m_reply) {
        m_reply->abort();
    }
}
