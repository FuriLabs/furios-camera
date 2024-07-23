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

QString protocol = "";
QString ssid = "";
QString password = "";

QRegularExpression urlPattern("^(?:http(s)?://)?[\\w.-]+(?:\\.[\\w.-]+)+[\\w\\-._~:/?#[\\]@!$&'()*+,;=]*$");
QRegularExpression wifiPattern("^WIFI:S:([^;]+);T:([^;]+);P:([^;]+)");

QRCodeHandler::QRCodeHandler(QObject *parent) : QObject(parent) {
    const char* waylandDisplay = getenv("WAYLAND_DISPLAY");

    if (waylandDisplay == nullptr) {
        setenv("WAYLAND_DISPLAY", "wayland-0", 1);
        std::cout << "WAYLAND_DISPLAY was not set. It is now set to 'wayland-0'." << std::endl;
    } else {
        std::cout << "WAYLAND_DISPLAY is already set to '" << waylandDisplay << "'." << std::endl;
    }
}

QString QRCodeHandler::parseQrString(const QString &qrString) {
    QString mutableQrString = qrString;

    if (urlPattern.match(mutableQrString).hasMatch()) {
        return QString("URL");
    } else if (wifiPattern.match(mutableQrString).hasMatch()) {
        QString mutableCredentials = qrString;

        QRegularExpressionMatch match = wifiPattern.match(mutableCredentials);
        ssid = match.captured(1);
        protocol = match.captured(2);
        password = match.captured(3);

        return QString("WIFI");
    } else {
        qDebug() << "Invalid QR string: " << qrString;
    }
}

void QRCodeHandler::openUrlInFirefox(const QString &url) {
    QString mutableUrl = url;

    if (!mutableUrl.startsWith("http://") && !mutableUrl.startsWith("https://")) {
        mutableUrl.prepend("http://");
    }
    QProcess::startDetached("xdg-open", QStringList() << mutableUrl);
}

void QRCodeHandler::connectToWifi() {

    qDebug() << "Protocol: " << protocol;
    qDebug() << "SSID: " << ssid;
    qDebug() << "Password: " << password;
}

QString QRCodeHandler::getWifiId() {
    return ssid;
}
