#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

class HuggingFaceApi;
class ModelDownloader;

class ModelController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList availableModels READ availableModels NOTIFY availableModelsChanged)
    Q_PROPERTY(QVariantList installedModels READ installedModels NOTIFY installedModelsChanged)
    Q_PROPERTY(QVariantList modelFiles READ modelFiles NOTIFY modelFilesChanged)
    Q_PROPERTY(double downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)
    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY isDownloadingChanged)
    Q_PROPERTY(QString downloadingModelName READ downloadingModelName NOTIFY isDownloadingChanged)
    Q_PROPERTY(QString downloadSpeed READ downloadSpeed NOTIFY downloadProgressChanged)
    Q_PROPERTY(QString downloadSize READ downloadSize NOTIFY downloadProgressChanged)
    Q_PROPERTY(QString activeModelId READ activeModelId NOTIFY activeModelChanged)
    Q_PROPERTY(QString activeModelName READ activeModelName NOTIFY activeModelChanged)
    Q_PROPERTY(bool isFetchingFiles READ isFetchingFiles NOTIFY isFetchingFilesChanged)

public:
    explicit ModelController(QObject *parent = nullptr);
    ~ModelController();

    QVariantList availableModels() const;
    QVariantList installedModels() const;
    QVariantList modelFiles() const;
    double downloadProgress() const;
    bool isDownloading() const;
    QString downloadingModelName() const;
    QString downloadSpeed() const;
    QString downloadSize() const;
    QString activeModelId() const;
    QString activeModelName() const;
    bool isFetchingFiles() const;

public slots:
    void searchModels(const QString &query);
    void fetchModelFiles(const QString &repoId);
    void downloadModel(const QString &repoId, const QString &filename);
    void cancelDownload();
    void deleteModel(const QString &modelId);
    void setActiveModel(const QString &modelId);
    void refreshInstalledModels();
    void setHfToken(const QString &token);

signals:
    void downloadProgressChanged(double percent, double speedMBps, int etaSeconds);
    void downloadComplete(const QString &modelId);
    void downloadFailed(const QString &error);
    void gatedModelNeedsAuth(const QString &repoId, const QString &licenseUrl);
    void availableModelsChanged();
    void installedModelsChanged();
    void modelFilesChanged();
    void isFetchingFilesChanged();
    void isDownloadingChanged();
    void activeModelChanged();

private:
    void loadInstalledModels();

    QVariantList m_availableModels;
    QVariantList m_installedModels;
    QVariantList m_modelFiles;
    double m_downloadProgress = 0.0;
    bool m_isDownloading = false;
    bool m_isFetchingFiles = false;
    QString m_downloadingModelName;
    QString m_downloadSpeed;
    QString m_downloadSize;
    QString m_activeModelId;
    QString m_activeModelName;
    QString m_hfToken;

    HuggingFaceApi *m_api = nullptr;
    ModelDownloader *m_downloader = nullptr;
};
