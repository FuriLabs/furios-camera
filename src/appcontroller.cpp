// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Furi Labs
//
// Authors:
// Bardia Moshiri <bardia@furilabs.com>

#include "appcontroller.h"
#include "windoweventfilter.h"
#include "flashlightcontroller.h"
#include "filemanager.h"
#include "thumbnailgenerator.h"
#include "qrcodehandler.h"
#include "settingsmanager.h"
#include "zxingreader.h"

#include <QQmlContext>

AppController::AppController(QApplication& app)
    : m_app(app), m_engine(nullptr), m_window(nullptr),
      m_flashlightController(nullptr), m_fileManager(nullptr),
      m_thumbnailGenerator(nullptr), m_qrCodeHandler(nullptr)
{
}

AppController::~AppController()
{
    delete m_engine;
    delete m_flashlightController;
    delete m_fileManager;
    delete m_thumbnailGenerator;
    delete m_qrCodeHandler;
}

void AppController::initialize()
{
    m_engine = new QQmlApplicationEngine();
    setupEngine();
    loadMainWindow();
}

void AppController::unloadResources()
{
    if (m_window) {
        m_window->hide();
    }
    delete m_engine;
    m_engine = nullptr;
    m_window = nullptr;
}

void AppController::reloadResources()
{
    if (!m_engine) {
        initialize();
    }
    if (m_window) {
        m_window->show();
        m_window->raise();
        m_window->requestActivate();
    }
}

void AppController::initializeSettings()
{
    if (m_engine) {
        SettingsManager::instance().initialize(m_engine);
    }
}

void AppController::createDirectories()
{
    if (m_fileManager) {
        m_fileManager->createDirectory(QString("/Pictures/furios-camera"));
        m_fileManager->createDirectory(QString("/Videos/furios-camera"));
    }
}

void AppController::restartGpsIfNeeded()
{
    if (m_fileManager && SettingsManager::instance().gpsOn()) {
        m_fileManager->restartGps();
    }
}

void AppController::setupEngine()
{
    m_flashlightController = new FlashlightController();
    m_fileManager = new FileManager();
    m_thumbnailGenerator = new ThumbnailGenerator();
    m_qrCodeHandler = new QRCodeHandler();

    m_engine->rootContext()->setContextProperty("flashlightController", m_flashlightController);
    m_engine->rootContext()->setContextProperty("fileManager", m_fileManager);
    m_engine->rootContext()->setContextProperty("thumbnailGenerator", m_thumbnailGenerator);
    m_engine->rootContext()->setContextProperty("QRCodeHandler", m_qrCodeHandler);

    ZXingQt::registerQmlAndMetaTypes();
}

void AppController::loadMainWindow()
{
    const QUrl url("qrc:/main.qml");
    QObject::connect(m_engine, &QQmlApplicationEngine::objectCreated,
                     &m_app, [this, url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);

        if (auto window = qobject_cast<QQuickWindow*>(obj)) {
            m_window = window;
            m_window->setFlag(Qt::Window);
            auto filter = new WindowEventFilter(m_window, m_trayIcon);
            m_window->installEventFilter(filter);
            QObject::connect(filter, &WindowEventFilter::windowClosed, this, &AppController::unloadResources);
        }
    }, Qt::QueuedConnection);

    m_engine->load(url);
}
