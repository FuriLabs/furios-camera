// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2023 Droidian Project
//
// Authors:
// Bardia Moshiri <fakeshell@bardia.tech>
// Erik Inkinen <erik.inkinen@gmail.com>
// Alexander Rutz <alex@familyrutz.com>
// Joaquin Philco <joaquinphilco@gmail.com>

#include <QApplication>
#include <QIcon>
#include <QFont>
#include <QSystemTrayIcon>
#include <QMenu>
#include "singleinstance.h"
#include "appcontroller.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    QApplication app(argc, argv);
    app.setOrganizationName("FuriOS");
    app.setOrganizationDomain("furios.io");

    SingleInstance singleInstance;
    if (!singleInstance.listen("FuriOSCameraApp")) {
        qDebug() << "Application already running";
        return 0;
    }

    QIcon::setThemeName("default");
    QIcon::setThemeSearchPaths(QStringList("/usr/share/icons"));

    const QFont cantarell = QFont("Cantarell");
    app.setFont(cantarell);

    AppController appController(app);

    QSystemTrayIcon trayIcon(QIcon("/usr/share/icons/camera-app.svg"), &app);
    QMenu trayMenu;
    QAction quitAction("Quit");
    QObject::connect(&quitAction, &QAction::triggered, &app, &QCoreApplication::quit);
    trayMenu.addAction(&quitAction);
    trayIcon.setContextMenu(&trayMenu);
    trayIcon.show();

    QObject::connect(&singleInstance, &SingleInstance::showWindow, &appController, &AppController::reloadResources);

    appController.initialize();
    appController.initializeSettings();
    appController.createDirectories();
    appController.restartGpsIfNeeded();

    return app.exec();
}
