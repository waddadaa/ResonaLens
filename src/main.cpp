#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QFontDatabase>
#include <QIcon>
#include <QDir>
#include <QStandardPaths>
#include <QSqlQuery>

#include "controllers/SettingsController.h"
#include "controllers/ChatController.h"
#include "controllers/ModelController.h"
#include "controllers/KnowledgeController.h"
#include "controllers/AudioController.h"
#include "controllers/TtsController.h"
#include "controllers/SkillController.h"
#include "core/LlamaBackend.h"
#include "core/WebReaderBackend.h"
#include "database/Database.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("ResonaLens");
    app.setOrganizationName("ResonaLens");
    app.setApplicationVersion("0.1.0");

    QQuickStyle::setStyle("Basic");

    // Load Outfit font
    int fontId = QFontDatabase::addApplicationFont(
        ":/ResonaLensContent/fonts/Outfit-Variable.ttf");
    if (fontId != -1) {
        QStringList families = QFontDatabase::applicationFontFamilies(fontId);
        if (!families.isEmpty()) {
            QFont defaultFont(families.first());
            app.setFont(defaultFont);
        }
    }

    // Initialize database
    QString dataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataPath);
    if (!Database::instance().initialize(dataPath + "/resonalens.db")) {
        qCritical() << "Fatal: database could not be initialized at" << dataPath;
        return EXIT_FAILURE;
    }

    // Create controllers
    auto settingsController = new SettingsController(&app);
    auto chatController = new ChatController(&app);
    auto modelController = new ModelController(&app);
    auto knowledgeLlama = new LlamaBackend(&app);
    auto knowledgeWebReader = new WebReaderBackend(&app);
    auto knowledgeController = new KnowledgeController(knowledgeLlama, knowledgeWebReader, &app);
    auto audioController = new AudioController(&app);
    auto ttsController = new TtsController(&app);
    auto skillController = new SkillController(&app);

    // Wire skill system, knowledge, and settings into chat controller
    chatController->setSkillController(skillController);
    chatController->setKnowledgeController(knowledgeController);
    chatController->setSettingsController(settingsController);

    // Apply saved TTS settings to TtsController
    ttsController->setVoice(settingsController->ttsVoice());
    ttsController->setSpeed(settingsController->ttsSpeed());

    // Keep TTS voice/speed in sync when settings change
    QObject::connect(settingsController, &SettingsController::settingsChanged, [settingsController, ttsController]() {
        ttsController->setVoice(settingsController->ttsVoice());
        ttsController->setSpeed(settingsController->ttsSpeed());
    });

    // Pass HF token from settings to model controller
    if (settingsController->hasHfToken()) {
        // Get stored token via settings DB
        QSqlQuery tokenQuery(Database::instance().db());
        tokenQuery.prepare("SELECT value FROM settings WHERE key = 'hf_token'");
        if (tokenQuery.exec() && tokenQuery.next()) {
            QString token = tokenQuery.value(0).toString();
            // Strip JSON quotes if present
            if (token.startsWith('"') && token.endsWith('"'))
                token = token.mid(1, token.length() - 2);
            if (!token.isEmpty())
                modelController->setHfToken(token);
        }
    }

    // Keep token in sync when settings change
    QObject::connect(settingsController, &SettingsController::hfTokenChanged, [settingsController, modelController]() {
        QSqlQuery q(Database::instance().db());
        q.prepare("SELECT value FROM settings WHERE key = 'hf_token'");
        if (q.exec() && q.next()) {
            QString token = q.value(0).toString();
            if (token.startsWith('"') && token.endsWith('"'))
                token = token.mid(1, token.length() - 2);
            modelController->setHfToken(token);
        }
    });

    // Wire model activation to chat controller
    QObject::connect(modelController, &ModelController::activeModelChanged, [modelController, chatController]() {
        // Get the file path of the active model
        QSqlQuery q(Database::instance().db());
        q.prepare("SELECT file_path, name FROM models WHERE is_active = 1 LIMIT 1");
        if (q.exec() && q.next()) {
            QString filePath = q.value(0).toString();
            QString name = q.value(1).toString();
            chatController->loadModel(filePath, name);
        }
    });

    // Load active model on startup
    {
        QSqlQuery q(Database::instance().db());
        q.prepare("SELECT file_path, name FROM models WHERE is_active = 1 LIMIT 1");
        if (q.exec() && q.next()) {
            QString filePath = q.value(0).toString();
            QString name = q.value(1).toString();
            chatController->loadModel(filePath, name);
        }
    }

    // Register as QML singletons
    QQmlApplicationEngine engine;

    qmlRegisterSingletonInstance("ResonaLens.Controllers", 1, 0,
                                 "SettingsController", settingsController);
    qmlRegisterSingletonInstance("ResonaLens.Controllers", 1, 0,
                                 "ChatController", chatController);
    qmlRegisterSingletonInstance("ResonaLens.Controllers", 1, 0,
                                 "ModelController", modelController);
    qmlRegisterSingletonInstance("ResonaLens.Controllers", 1, 0,
                                 "KnowledgeController", knowledgeController);
    qmlRegisterSingletonInstance("ResonaLens.Controllers", 1, 0,
                                 "AudioController", audioController);
    qmlRegisterSingletonInstance("ResonaLens.Controllers", 1, 0,
                                 "TtsController", ttsController);
    qmlRegisterSingletonInstance("ResonaLens.Controllers", 1, 0,
                                 "SkillController", skillController);

    // Make sure QML imports resolve correctly on all platforms (Android in
    // particular packages things under qrc:/qt/qml/ on Qt 6, and plain-qrc
    // paths aren't searched by default).
    engine.addImportPath(QStringLiteral("qrc:/"));
    engine.addImportPath(QStringLiteral("qrc:/qt/qml"));

    const QUrl url(u"qrc:/qml/main.qml"_qs);
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
