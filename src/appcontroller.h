// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Furi Labs
//
// Authors:
// Bardia Moshiri <bardia@furilabs.com>

#ifndef APPCONTROLLER_H
#define APPCONTROLLER_H

#include <QObject>
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QSystemTrayIcon>

class FlashlightController;
class FileManager;
class ThumbnailGenerator;
class QRCodeHandler;

class AppController : public QObject
{
    Q_OBJECT
public:
    explicit AppController(QApplication& app);
    ~AppController();

    void initialize();
    void unloadResources();
    void reloadResources();
    void initializeSettings();
    void createDirectories();
    void restartGpsIfNeeded();

private:
    void setupEngine();
    void loadMainWindow();

    QApplication& m_app;
    QQmlApplicationEngine* m_engine;
    QQuickWindow* m_window;
    QSystemTrayIcon* m_trayIcon;
    FlashlightController* m_flashlightController;
    FileManager* m_fileManager;
    ThumbnailGenerator* m_thumbnailGenerator;
    QRCodeHandler* m_qrCodeHandler;
};

#endif // APPCONTROLLER_H
