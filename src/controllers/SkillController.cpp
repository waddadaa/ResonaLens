#include "SkillController.h"
#include "core/SkillExecutor.h"

#include <QDebug>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>

SkillController::SkillController(QObject *parent)
    : QObject(parent)
    , m_executor(new SkillExecutor(this))
{
    connect(m_executor, &SkillExecutor::skillStarted, this, [this](const QString &name) {
        m_isExecuting = true;
        m_activeSkill = name;
        emit isExecutingChanged();
        emit activeSkillChanged();
        emit skillStarted(name);
    });

    connect(m_executor, &SkillExecutor::skillCompleted,
            this, [this](const QString &name, const QVariantMap &result) {
        m_isExecuting = false;
        m_activeSkill.clear();
        emit isExecutingChanged();
        emit activeSkillChanged();
        emit skillCompleted(name, result);
    });

    connect(m_executor, &SkillExecutor::skillFailed,
            this, [this](const QString &name, const QString &error) {
        m_isExecuting = false;
        m_activeSkill.clear();
        emit isExecutingChanged();
        emit activeSkillChanged();
        emit skillFailed(name, error);
    });

    loadSkills();
}

SkillController::~SkillController() = default;

QVariantList SkillController::availableSkills() const { return m_availableSkills; }
bool SkillController::isExecuting() const { return m_isExecuting; }
QString SkillController::activeSkill() const { return m_activeSkill; }

void SkillController::loadSkills()
{
    // Skills are embedded in the binary via qt_add_resources.
    // ":/skills" works on all platforms (desktop, Android, iOS) — single binary, no loose files.
    // Filesystem fallback only for desktop dev when running outside CMake build.
    QStringList searchPaths = {
        ":/skills",
        QCoreApplication::applicationDirPath() + "/skills",
        QCoreApplication::applicationDirPath() + "/../../skills",
    };

    QString skillsDir;
    for (const QString &path : searchPaths) {
        if (QDir(path).exists()) {
            skillsDir = QFileInfo(path).absoluteFilePath();
            break;
        }
    }

    if (skillsDir.isEmpty()) {
        qWarning() << "Skills directory not found in any search path:" << searchPaths;
        return;
    }

    qInfo() << "Loading skills from:" << skillsDir;
    m_executor->loadSkillDefinitions(skillsDir);
    m_availableSkills = m_executor->skillList();
    emit skillsChanged();
}

QVariantMap SkillController::executeSkill(const QString &skillName, const QVariantMap &params)
{
    // Bridge the QVariantMap interface (used by LiteRT tool calling) to the new
    // string-based SkillExecutor API. Extract the most relevant input string.
    QString input = params["query"].toString();
    if (input.isEmpty()) input = params["input"].toString();
    if (input.isEmpty()) input = params["url"].toString();
    if (input.isEmpty()) input = params["file_path"].toString();

    QString resultText = m_executor->executeSkill(skillName, input);

    QVariantMap result;
    result["content"] = resultText;
    return result;
}
