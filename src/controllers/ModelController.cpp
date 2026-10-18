#include "ModelController.h"
#include "database/Database.h"
#include "network/HuggingFaceApi.h"
#include "network/ModelDownloader.h"

#include <QSqlQuery>
#include <QSqlError>
#include <QUuid>
#include <QDateTime>
#include <QStandardPaths>
#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QDebug>

ModelController::ModelController(QObject *parent)
    : QObject(parent)
    , m_api(new HuggingFaceApi(this))
    , m_downloader(new ModelDownloader(this))
{
    connect(m_api, &HuggingFaceApi::searchResultsReady, this, [this](const QVariantList &results) {
        m_availableModels = results;
        emit availableModelsChanged();
    });

    connect(m_api, &HuggingFaceApi::modelFilesReady, this, [this](const QVariantList &files) {
        m_modelFiles = files;
        m_isFetchingFiles = false;
        emit modelFilesChanged();
        emit isFetchingFilesChanged();
    });

    connect(m_downloader, &ModelDownloader::progressChanged,
            this, [this](double percent, double speedMBps, qint64 received, qint64 total) {
        m_downloadProgress = percent;
        m_downloadSpeed = QString::number(speedMBps, 'f', 1) + " MB/s";
        if (total > 1024LL * 1024 * 1024) {
            QString recv = QString::number(received / (1024.0 * 1024 * 1024), 'f', 1);
            QString tot = QString::number(total / (1024.0 * 1024 * 1024), 'f', 1);
            m_downloadSize = recv + " GB / " + tot + " GB";
        } else {
            QString recv = QString::number(received / (1024.0 * 1024), 'f', 0);
            QString tot = QString::number(total / (1024.0 * 1024), 'f', 0);
            m_downloadSize = recv + " MB / " + tot + " MB";
        }
        emit downloadProgressChanged(percent, speedMBps, 0);
    });

    connect(m_downloader, &ModelDownloader::downloadFinished,
            this, [this](const QString &filePath) {
        m_isDownloading = false;
        emit isDownloadingChanged();

        QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
        QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
        QFileInfo fi(filePath);

        // Extract quantization from filename
        QString quant = "unknown";
        static QRegularExpression quantRe("(Q[0-9]_[A-Z_]+|F16|F32|IQ[0-9]_[A-Z]+)",
                                           QRegularExpression::CaseInsensitiveOption);
        auto match = quantRe.match(fi.fileName());
        if (match.hasMatch())
            quant = match.captured(1);

        QSqlQuery query(Database::instance().db());
        query.prepare("INSERT INTO models (id, hf_repo_id, name, filename, file_path, "
                      "size_bytes, quantization, downloaded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
        query.addBindValue(id);
        query.addBindValue(m_downloadingModelName);
        query.addBindValue(fi.baseName());
        query.addBindValue(fi.fileName());
        query.addBindValue(filePath);
        query.addBindValue(fi.size());
        query.addBindValue(quant);
        query.addBindValue(now);
        if (!query.exec()) {
            qWarning() << "Model INSERT failed:" << query.lastError().text();
            emit downloadFailed("Downloaded file is on disk but could not be recorded: "
                                + query.lastError().text());
            return;
        }

        loadInstalledModels();
        emit downloadComplete(id);
    });

    connect(m_downloader, &ModelDownloader::downloadError,
            this, [this](const QString &error) {
        m_isDownloading = false;
        emit isDownloadingChanged();
        emit downloadFailed(error);
    });

    loadInstalledModels();

    // Set active model from DB
    QSqlQuery activeQuery(Database::instance().db());
    if (!activeQuery.exec("SELECT id, name FROM models WHERE is_active = 1 LIMIT 1"))
        qWarning() << "active model lookup failed:" << activeQuery.lastError().text();
    if (activeQuery.next()) {
        m_activeModelId = activeQuery.value(0).toString();
        m_activeModelName = activeQuery.value(1).toString();
        emit activeModelChanged();
    }
}

ModelController::~ModelController() = default;

QVariantList ModelController::availableModels() const { return m_availableModels; }
QVariantList ModelController::installedModels() const { return m_installedModels; }
QVariantList ModelController::modelFiles() const { return m_modelFiles; }
double ModelController::downloadProgress() const { return m_downloadProgress; }
bool ModelController::isDownloading() const { return m_isDownloading; }
QString ModelController::downloadingModelName() const { return m_downloadingModelName; }
QString ModelController::downloadSpeed() const { return m_downloadSpeed; }
QString ModelController::downloadSize() const { return m_downloadSize; }
QString ModelController::activeModelId() const { return m_activeModelId; }
QString ModelController::activeModelName() const { return m_activeModelName; }
bool ModelController::isFetchingFiles() const { return m_isFetchingFiles; }

void ModelController::searchModels(const QString &query)
{
    m_api->searchModels(query);
}

void ModelController::fetchModelFiles(const QString &repoId)
{
    m_modelFiles.clear();
    m_isFetchingFiles = true;
    emit modelFilesChanged();
    emit isFetchingFilesChanged();
    m_api->getModelFiles(repoId);
}

void ModelController::downloadModel(const QString &repoId, const QString &filename)
{
    if (filename.isEmpty()) {
        emit downloadFailed("No filename specified. Please select a GGUF file to download.");
        return;
    }

    QString dataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QString modelsDir = dataPath + "/models";
    QDir().mkpath(modelsDir);

    m_isDownloading = true;
    m_downloadProgress = 0.0;
    m_downloadingModelName = repoId;
    emit isDownloadingChanged();

    QString destPath = modelsDir + "/" + filename;
    m_downloader->download(repoId, filename, destPath, m_hfToken);
}

void ModelController::cancelDownload()
{
    m_downloader->cancel();
    m_isDownloading = false;
    emit isDownloadingChanged();
}

void ModelController::deleteModel(const QString &modelId)
{
    QSqlQuery query(Database::instance().db());
    query.prepare("SELECT file_path FROM models WHERE id = ?");
    query.addBindValue(modelId);

    if (query.exec() && query.next()) {
        QString filePath = query.value(0).toString();
        QFile::remove(filePath);
    }

    query.prepare("DELETE FROM models WHERE id = ?");
    query.addBindValue(modelId);
    if (!query.exec()) {
        qWarning() << "deleteModel failed:" << query.lastError().text();
        emit downloadFailed("Failed to delete model: " + query.lastError().text());
        return;
    }

    if (modelId == m_activeModelId) {
        m_activeModelId.clear();
        m_activeModelName.clear();
        emit activeModelChanged();
    }

    loadInstalledModels();
}

void ModelController::setActiveModel(const QString &modelId)
{
    QSqlQuery query(Database::instance().db());
    if (!query.exec("UPDATE models SET is_active = 0"))
        qWarning() << "setActiveModel: clear-active failed:" << query.lastError().text();

    query.prepare("UPDATE models SET is_active = 1 WHERE id = ?");
    query.addBindValue(modelId);
    if (!query.exec()) {
        qWarning() << "setActiveModel: set-active failed:" << query.lastError().text();
        return;
    }

    query.prepare("SELECT name FROM models WHERE id = ?");
    query.addBindValue(modelId);
    if (query.exec() && query.next()) {
        m_activeModelId = modelId;
        m_activeModelName = query.value(0).toString();
        emit activeModelChanged();
    }

    loadInstalledModels();
}

void ModelController::refreshInstalledModels()
{
    loadInstalledModels();
}

void ModelController::setHfToken(const QString &token)
{
    m_hfToken = token;
    m_api->setToken(token);
    m_downloader->setToken(token);
}

void ModelController::loadInstalledModels()
{
    m_installedModels.clear();

    QSqlQuery query(Database::instance().db());
    if (!query.exec("SELECT id, hf_repo_id, name, filename, file_path, size_bytes, "
                    "model_type, quantization, capabilities, is_active, downloaded_at "
                    "FROM models ORDER BY downloaded_at DESC")) {
        qWarning() << "loadInstalledModels failed:" << query.lastError().text();
        emit installedModelsChanged();
        return;
    }

    while (query.next()) {
        QVariantMap model;
        model["id"] = query.value(0).toString();
        model["hfRepoId"] = query.value(1).toString();
        model["name"] = query.value(2).toString();
        model["filename"] = query.value(3).toString();
        model["filePath"] = query.value(4).toString();
        model["sizeBytes"] = query.value(5).toLongLong();
        model["modelType"] = query.value(6).toString();
        model["quantization"] = query.value(7).toString();
        model["capabilities"] = query.value(8).toString();
        model["isActive"] = query.value(9).toBool();
        model["downloadedAt"] = query.value(10).toString();

        double gb = query.value(5).toLongLong() / (1024.0 * 1024.0 * 1024.0);
        model["sizeFormatted"] = gb >= 1.0 ? QString::number(gb, 'f', 1) + " GB"
                                           : QString::number(gb * 1024, 'f', 0) + " MB";

        m_installedModels.append(model);
    }

    emit installedModelsChanged();
}
