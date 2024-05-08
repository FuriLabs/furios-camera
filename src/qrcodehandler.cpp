// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

#include "qrcodehandler.h"
#include <QProcess>
#include <cstdlib> 
#include <iostream>
#include <QUrl>

QRCodeHandler::QRCodeHandler(QObject *parent) : QObject(parent) {
    const char* waylandDisplay = getenv("WAYLAND_DISPLAY");

    if (waylandDisplay == nullptr) {
        setenv("WAYLAND_DISPLAY", "wayland-0", 1);
        std::cout << "WAYLAND_DISPLAY was not set. It is now set to 'wayland-0'." << std::endl;
    } else {
        std::cout << "WAYLAND_DISPLAY is already set to '" << waylandDisplay << "'." << std::endl;
    }
}

void QRCodeHandler::openUrlInFirefox(const QString &url) {
    QUrl qUrl(url);
    if (qUrl.isValid() && (qUrl.scheme() == "http" || qUrl.scheme() == "https")) {
        QProcess::startDetached("xdg-open", QStringList() << url);
    } else {
        std::cerr << "Provided string is not a valid URL: " << url.toStdString() << std::endl;
    }
}
