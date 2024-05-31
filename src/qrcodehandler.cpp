// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

#include "qrcodehandler.h"
#include <QProcess>
#include <cstdlib> 
#include <iostream>
#include <QRegularExpression>
#include <QUrl>
#include <QDebug>

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

    QString mutableUrl = url;
    QRegularExpression pattern("^(?:http(s)?://)?[\\w.-]+(?:\\.[\\w.-]+)+[\\w\\-._~:/?#[\\]@!$&'()*+,;=]*$");

    if (pattern.match(mutableUrl).hasMatch()) {
        if (!mutableUrl.startsWith("http://") && !mutableUrl.startsWith("https://")) {
            mutableUrl.prepend("http://");
        }
        QProcess::startDetached("xdg-open", QStringList() << mutableUrl);
    } else {
        qDebug() << "Provided string is not a valid URL: " << url;
    }
}
