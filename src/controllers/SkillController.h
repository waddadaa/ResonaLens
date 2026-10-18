#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

class SkillExecutor;

class SkillController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList availableSkills READ availableSkills NOTIFY skillsChanged)
    Q_PROPERTY(bool isExecuting READ isExecuting NOTIFY isExecutingChanged)
    Q_PROPERTY(QString activeSkill READ activeSkill NOTIFY activeSkillChanged)

public:
    explicit SkillController(QObject *parent = nullptr);
    ~SkillController();

    QVariantList availableSkills() const;
    bool isExecuting() const;
    QString activeSkill() const;

public slots:
    void loadSkills();
    QVariantMap executeSkill(const QString &skillName, const QVariantMap &params);

signals:
    void skillStarted(const QString &skillName);
    void skillCompleted(const QString &skillName, const QVariantMap &result);
    void skillFailed(const QString &skillName, const QString &error);
    void skillsChanged();
    void isExecutingChanged();
    void activeSkillChanged();

private:
    QVariantList m_availableSkills;
    bool m_isExecuting = false;
    QString m_activeSkill;
    SkillExecutor *m_executor = nullptr;
};
