#pragma once

#include <QObject>
#include <QVariant>
#include <QString>

class SettingsController : public QObject {
    Q_OBJECT
    Q_PROPERTY(double temperature READ temperature NOTIFY settingsChanged)
    Q_PROPERTY(double topP READ topP NOTIFY settingsChanged)
    Q_PROPERTY(int maxTokens READ maxTokens NOTIFY settingsChanged)
    Q_PROPERTY(QString theme READ theme NOTIFY settingsChanged)
    Q_PROPERTY(qint64 modelsStorageUsed READ modelsStorageUsed NOTIFY storageChanged)
    Q_PROPERTY(qint64 chatStorageUsed READ chatStorageUsed NOTIFY storageChanged)
    Q_PROPERTY(qint64 knowledgeStorageUsed READ knowledgeStorageUsed NOTIFY storageChanged)
    Q_PROPERTY(bool hasHfToken READ hasHfToken NOTIFY hfTokenChanged)
    Q_PROPERTY(bool hfTokenValid READ hfTokenValid NOTIFY hfTokenChanged)
    Q_PROPERTY(QString hfToken READ hfToken NOTIFY hfTokenChanged)
    Q_PROPERTY(double ttsSpeed READ ttsSpeed NOTIFY settingsChanged)
    Q_PROPERTY(bool ttsAutoSpeak READ ttsAutoSpeak NOTIFY settingsChanged)
    Q_PROPERTY(QString ttsVoice READ ttsVoice NOTIFY settingsChanged)
    Q_PROPERTY(bool ttsEnabled READ ttsEnabled NOTIFY settingsChanged)

public:
    explicit SettingsController(QObject *parent = nullptr);

    double temperature() const;
    double topP() const;
    int maxTokens() const;
    QString theme() const;
    qint64 modelsStorageUsed() const;
    qint64 chatStorageUsed() const;
    qint64 knowledgeStorageUsed() const;
    bool hasHfToken() const;
    bool hfTokenValid() const;
    QString hfToken() const;
    double ttsSpeed() const;
    bool ttsAutoSpeak() const;
    QString ttsVoice() const;
    bool ttsEnabled() const;

public slots:
    void setSetting(const QString &key, const QVariant &value);
    void setHfToken(const QString &token);
    void validateHfToken();
    void clearCache();
    void clearHistory();
    void refreshStorage();

signals:
    void settingsChanged();
    void storageChanged();
    void hfTokenChanged();
    void hfTokenValidated(bool valid);

private:
    QVariant getSetting(const QString &key, const QVariant &defaultValue = QVariant()) const;
    void storeSetting(const QString &key, const QVariant &value);

    double m_temperature = 0.7;
    double m_topP = 0.9;
    int m_maxTokens = 2048;
    QString m_theme = "light";
    double m_ttsSpeed = 1.0;
    bool m_ttsAutoSpeak = false;
    QString m_ttsVoice = "af_heart";
    bool m_ttsEnabled = false;
    QString m_hfToken;
    bool m_hfTokenValid = false;
    qint64 m_modelsStorage = 0;
    qint64 m_chatStorage = 0;
    qint64 m_knowledgeStorage = 0;
};
