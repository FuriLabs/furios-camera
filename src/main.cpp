// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2023 Droidian Project
//
// Authors:
// Bardia Moshiri <fakeshell@bardia.tech>
// Erik Inkinen <erik.inkinen@gmail.com>
// Alexander Rutz <alex@familyrutz.com>
// Joaquin Philco <joaquinphilco@gmail.com>

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QStandardPaths>
#include <QQmlContext>
#include <QIcon>
#include <QFile>
#include <QFont>
#include "flashlightcontroller.h"
#include "filemanager.h"
#include "thumbnailgenerator.h"
#include "zxingreader.h"
#include "qrcodehandler.h"
#include "settingsmanager.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QGuiApplication app(argc, argv);

    app.setOrganizationName("FuriOS");
    app.setOrganizationDomain("furios.io");

    QIcon::setThemeName("default");
    QIcon::setThemeSearchPaths(QStringList("/usr/share/icons"));

    QQmlApplicationEngine engine;
    FlashlightController flashlightController;
    FileManager fileManager;
    ThumbnailGenerator thumbnailGenerator;
    QRCodeHandler qrCodeHandler;

    QString mainQmlPath = "qrc:/main.qml";

    qDebug() << "selected aal backend";

    fileManager.removeGStreamerCacheDirectory();

    engine.rootContext()->setContextProperty("flashlightController", &flashlightController);
    engine.rootContext()->setContextProperty("fileManager", &fileManager);
    engine.rootContext()->setContextProperty("thumbnailGenerator", &thumbnailGenerator);
    engine.rootContext()->setContextProperty("QRCodeHandler", &qrCodeHandler);

    const QFont cantarell = QFont("Cantarell");
    app.setFont(cantarell);

    const QUrl url(mainQmlPath);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    ZXingQt::registerQmlAndMetaTypes();

    engine.load(url);

    SettingsManager::instance().initialize(&engine);

    fileManager.createDirectory(QString("/Pictures/furios-camera"));
    fileManager.createDirectory(QString("/Videos/furios-camera"));

    if (SettingsManager::instance().gpsOn()) {
        fileManager.restartGps();
    }

    return app.exec();
}
