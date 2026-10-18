#include "HuggingFaceApi.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrl>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <memory>

HuggingFaceApi::HuggingFaceApi(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

void HuggingFaceApi::setToken(const QString &token)
{
    m_token = token;
}

void HuggingFaceApi::searchModels(const QString &query)
{
    // Use a shared state to collect results from both searches
    struct SearchState {
        QVariantList results;
        int pending = 2;
    };
    auto state = std::make_shared<SearchState>();

    auto parseModels = [](QNetworkReply *reply, const QString &format) -> QVariantList {
        QVariantList models;
        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "HF search error (" << format << "):" << reply->errorString();
            return models;
        }
        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isArray()) {
            qWarning() << "HF search (" << format << "): unexpected response shape";
            return models;
        }
        for (const QJsonValue &v : doc.array()) {
            if (!v.isObject()) continue;
            QJsonObject obj = v.toObject();
            QVariantMap model;
            const QString id = obj.value("id").toString();
            model["id"] = id;
            const QStringList parts = id.split('/');
            model["name"] = parts.isEmpty() ? id : parts.last();
            model["author"] = parts.size() > 1 ? parts.first() : QString();
            model["downloads"] = obj.value("downloads").toInt();
            model["likes"] = obj.value("likes").toInt();
            model["isGated"] = obj.value("gated").toBool();
            model["pipelineTag"] = obj.value("pipeline_tag").toString();
            model["format"] = format;

            QStringList tags;
            const QJsonValue tagsVal = obj.value("tags");
            if (tagsVal.isArray()) {
                for (const QJsonValue &t : tagsVal.toArray())
                    tags.append(t.toString());
            }
            model["tags"] = tags;

            models.append(model);
        }
        return models;
    };

    auto mergeAndEmit = [this, state]() {
        state->pending--;
        if (state->pending <= 0) {
            qInfo() << "Search complete:" << state->results.size() << "models found";
            emit searchResultsReady(state->results);
        }
    };

#ifdef Q_OS_ANDROID
    // On Android, only LiteRT models are supported (GGUF/Vulkan crashes on Adreno,
    // OpenCL requires Q4_0 which most repos don't provide).
    // Skip GGUF search entirely to avoid confusing users.
    state->pending = 1;  // only LiteRT search
#else
    // Desktop: search GGUF models
    QUrl ggufUrl("https://huggingface.co/api/models");
    QUrlQuery ggufQuery;
    ggufQuery.addQueryItem("search", query);
    ggufQuery.addQueryItem("filter", "gguf");
    ggufQuery.addQueryItem("sort", "downloads");
    ggufQuery.addQueryItem("direction", "-1");
    ggufQuery.addQueryItem("limit", "15");
    ggufUrl.setQuery(ggufQuery);

    QNetworkRequest ggufReq(ggufUrl);
    ggufReq.setRawHeader("User-Agent", "ResonaLens/0.1");
    if (!m_token.isEmpty())
        ggufReq.setRawHeader("Authorization", ("Bearer " + m_token).toUtf8());

    QNetworkReply *ggufReply = m_nam->get(ggufReq);
    connect(ggufReply, &QNetworkReply::finished, this, [state, ggufReply, parseModels, mergeAndEmit]() {
        state->results.append(parseModels(ggufReply, "gguf"));
        ggufReply->deleteLater();
        mergeAndEmit();
    });
#endif

    // Search LiteRT models
    QUrl liteRTUrl("https://huggingface.co/api/models");
    QUrlQuery liteRTQuery;
    liteRTQuery.addQueryItem("search", query + " litert");
    liteRTQuery.addQueryItem("filter", "litert-lm");
    liteRTQuery.addQueryItem("sort", "downloads");
    liteRTQuery.addQueryItem("direction", "-1");
    liteRTQuery.addQueryItem("limit", "15");
    liteRTUrl.setQuery(liteRTQuery);

    QNetworkRequest liteRTReq(liteRTUrl);
    liteRTReq.setRawHeader("User-Agent", "ResonaLens/0.1");

    QNetworkReply *liteRTReply = m_nam->get(liteRTReq);
    connect(liteRTReply, &QNetworkReply::finished, this, [state, liteRTReply, parseModels, mergeAndEmit]() {
        QVariantList liteRTModels = parseModels(liteRTReply, "litertlm");
        // Prepend LiteRT models (faster inference) but avoid duplicates
        for (const QVariant &m : liteRTModels) {
            QString id = m.toMap()["id"].toString();
            bool exists = false;
            for (const QVariant &r : state->results) {
                if (r.toMap()["id"] == id) { exists = true; break; }
            }
            if (!exists)
                state->results.prepend(m);
        }
        liteRTReply->deleteLater();
        mergeAndEmit();
    });
}

void HuggingFaceApi::getModelInfo(const QString &repoId)
{
    QUrl url("https://huggingface.co/api/models/" + repoId);

    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "ResonaLens/0.1");
    if (!m_token.isEmpty())
        request.setRawHeader("Authorization", ("Bearer " + m_token).toUtf8());

    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        QVariantMap info;

        if (reply->error() == QNetworkReply::NoError) {
            QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (doc.isObject()) {
                QJsonObject obj = doc.object();
                info["id"] = obj.value("id").toString();
                info["author"] = obj.value("author").toString();
                info["description"] = obj.value("description").toString();
                info["downloads"] = obj.value("downloads").toInt();
                info["likes"] = obj.value("likes").toInt();
                info["isGated"] = obj.value("gated").toBool();
                const QJsonValue cardData = obj.value("cardData");
                if (cardData.isObject())
                    info["license"] = cardData.toObject().value("license").toString();
            } else {
                qWarning() << "HF getModelInfo: unexpected response shape";
            }
        } else {
            qWarning() << "HF getModelInfo failed:" << reply->errorString();
        }

        reply->deleteLater();
        emit modelInfoReady(info);
    });
}

void HuggingFaceApi::getModelFiles(const QString &repoId)
{
    QUrl url("https://huggingface.co/api/models/" + repoId + "/tree/main");

    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "ResonaLens/0.1");
    if (!m_token.isEmpty())
        request.setRawHeader("Authorization", ("Bearer " + m_token).toUtf8());

    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        QVariantList files;

        if (reply->error() == QNetworkReply::NoError) {
            QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (!doc.isArray()) {
                qWarning() << "HF getModelFiles: unexpected response shape";
                reply->deleteLater();
                emit modelFilesReady(files);
                return;
            }
            QJsonArray arr = doc.array();

            // Quantizations that work on Adreno GPU (OpenCL backend).
            // Others fall back to CPU and are extremely slow on mobile.
            static const QStringList gpuQuantTypes = {
                "Q4_0", "Q8_0", "Q6_K"
            };

            for (const QJsonValue &v : arr) {
                QJsonObject obj = v.toObject();
                QString name = obj["path"].toString();
                // Accept both GGUF and LiteRT model files
                if (!name.endsWith(".gguf") && !name.endsWith(".litertlm") && !name.endsWith(".task"))
                    continue;

                QVariantMap file;
                file["name"] = name;
                file["size"] = obj["size"].toInteger();

                // Extract quantization from filename
                static QRegularExpression quantRe("(Q[0-9]_[A-Z_]+|F16|F32|IQ[0-9]_[A-Z]+)",
                                                   QRegularExpression::CaseInsensitiveOption);
                auto match = quantRe.match(name);
                QString quant = match.hasMatch() ? match.captured(1).toUpper() : "unknown";
                file["quantization"] = quant;

                // LiteRT models are always GPU-compatible
                bool isLiteRT = name.endsWith(".litertlm") || name.endsWith(".task");

                // For GGUF: only show quantizations that work on the phone's GPU.
                // IQ4_XS, Q5_K_M, etc. fall back to CPU and are too slow.
                if (!isLiteRT && !gpuQuantTypes.contains(quant)) {
                    qInfo() << "Skipping incompatible GGUF quant:" << name << quant;
                    continue;
                }

                double gb = obj["size"].toInteger() / (1024.0 * 1024.0 * 1024.0);
                file["sizeFormatted"] = gb >= 1.0 ?
                    QString::number(gb, 'f', 1) + " GB" :
                    QString::number(gb * 1024, 'f', 0) + " MB";

                // Tag GPU-accelerated files
                file["gpuAccelerated"] = isLiteRT || gpuQuantTypes.contains(quant);

                files.append(file);
            }
        }

        reply->deleteLater();
        emit modelFilesReady(files);
    });
}

void HuggingFaceApi::validateToken(const QString &token)
{
    QUrl url("https://huggingface.co/api/whoami-v2");
    QNetworkRequest request(url);
    request.setRawHeader("Authorization", ("Bearer " + token).toUtf8());
    request.setRawHeader("User-Agent", "ResonaLens/0.1");
    // A redirect that downgrades HTTPS -> HTTP (or cross-origin) would leak
    // the bearer token in the Location request. NoLessSafeRedirectPolicy
    // forbids exactly that.
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(15 * 1000);

    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        bool valid = reply->error() == QNetworkReply::NoError;
        if (valid) {
            // whoami-v2 returns a JSON object with a "name" field for valid
            // tokens. Empty/malformed response => invalid even if HTTP 200.
            QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            valid = doc.isObject() && doc.object().contains(QStringLiteral("name"));
        }
        reply->deleteLater();
        emit tokenValidated(valid);
    });
}
