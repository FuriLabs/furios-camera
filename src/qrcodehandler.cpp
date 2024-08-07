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
#include <QtDBus>

typedef QMap<QString, QVariantMap> Connection;

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
    QDBusInterface wifiEnabled("org.freedesktop.NetworkManager",
                               "/org/freedesktop/NetworkManager",
                               "org.freedesktop.DBus.Properties",
                               QDBusConnection::systemBus());

    if (!wifiEnabled.isValid()) {
        qWarning() << "Failed to connect to dbus";
        return;
    }

    qDBusRegisterMetaType<Connection>();

    Connection connection;

    if (!QRCodeHandler::deactivateConnection()) {
        qWarning() << "Failed to deactivate connection";
        QDBusConnection::systemBus().disconnectFromBus(QDBusConnection::systemBus().name());
        return;
    }

    if (!QRCodeHandler::forgetConnection()) {
        qWarning() << "Failed to forget connection";
        QDBusConnection::systemBus().disconnectFromBus(QDBusConnection::systemBus().name());
        return;
    }

    // Enable WiFi by setting WirelessEnabled to true (RF kill switch)
    QDBusReply<void> reply = wifiEnabled.call("Set", "org.freedesktop.NetworkManager", "WirelessEnabled", QVariant::fromValue(QDBusVariant(QVariant(true))));

    if (!reply.isValid()) {
        qWarning() << "Failed to turn on wifi: " << reply.error().name() + " : " + reply.error().message();
        QDBusConnection::systemBus().disconnectFromBus(QDBusConnection::systemBus().name());
        return;
    } else {
        qDebug() << "Successfully turned on wifi";
    }

    connection["connection"]["type"] = "802-11-wireless";
    connection["connection"]["uuid"] = QUuid::createUuid().toString().remove('{').remove('}');
    connection["connection"]["id"] = ssid;
    connection["connection"]["autoconnect-retries"] = -1;

    connection["802-11-wireless"]["ssid"] = ssid.toUtf8();
    connection["802-11-wireless"]["hidden"] = false;
    connection["802-11-wireless"]["mode"] = "infrastructure";

    if (!password.isEmpty()) {
        connection["802-11-wireless-security"]["key-mgmt"] = "wpa-psk";
        connection["802-11-wireless-security"]["auth-alg"] = "open";
        connection["802-11-wireless-security"]["psk"] = password;
    } else {
        connection["802-11-wireless-security"]["key-mgmt"] = "none";
    }

    connection["ipv4"]["method"] = "auto";
    connection["ipv4"]["dns-priority"] = 600;
    connection["ipv6"]["method"] = "ignore";

    QDBusInterface nmSettings("org.freedesktop.NetworkManager",
                              "/org/freedesktop/NetworkManager/Settings",
                              "org.freedesktop.NetworkManager.Settings",
                              QDBusConnection::systemBus());

    if (!nmSettings.isValid()) {
        qWarning() << "Failed to connect to dbus";
        QDBusConnection::systemBus().disconnectFromBus(QDBusConnection::systemBus().name());
        return;
    }

    // Add the connection
    QDBusReply<QDBusObjectPath> result = nmSettings.call("AddConnection", QVariant::fromValue(connection));

    if (!result.isValid()) {
       qWarning() << "Error adding connection: " << result.error().name() << " : " << result.error().message();
    } else {
       qDebug() << "Added: " << result.value().path();
       qDebug() << "Connection added successfully";
    }

    QDBusConnection::systemBus().disconnectFromBus(QDBusConnection::systemBus().name());
}

bool QRCodeHandler::forgetConnection() {
    qDBusRegisterMetaType<Connection>;

    QDBusInterface nmSettings("org.freedesktop.NetworkManager",
                              "/org/freedesktop/NetworkManager/Settings",
                              "org.freedesktop.NetworkManager.Settings",
                              QDBusConnection::systemBus());

    if (!nmSettings.isValid()) {
        qWarning() << "Failed to connect to dbus";
        return false;
    }

    QDBusReply<QList<QDBusObjectPath>> reply = nmSettings.call("ListConnections");

    if (!reply.isValid()) {
        qWarning() << "Failed to list connections" << reply.error().message();
        return false;
    }

    QList<QDBusObjectPath> connectionsPaths = reply.value();
    bool ssidFound = false;

    for (const QDBusObjectPath &path: connectionsPaths) {
        QDBusInterface connectionSettings("org.freedesktop.NetworkManager",
                                          path.path(),
                                          "org.freedesktop.NetworkManager.Settings.Connection",
                                          QDBusConnection::systemBus());

        if (!connectionSettings.isValid()) {
            qWarning() << "Failed to connect to dbus";
            return false;
        }

        QDBusReply<Connection> settingsReply = connectionSettings.call("GetSettings");
        if (!settingsReply.isValid()) {
            qWarning() << "Failed to get settings for connection:" << path.path();
            continue;
        }

        QMap<QString, QVariantMap> settings = settingsReply.value();
        QString type = settings["connection"]["type"].toString();

        if (type == "802-11-wireless") {
            QString connectionSsid = settings["802-11-wireless"]["ssid"].toString();

            if (connectionSsid == ssid) {
                ssidFound = true;
                QDBusReply<void> deleteReply = connectionSettings.call("Delete");

                if (!deleteReply.isValid()) {
                    qWarning() << "Failed to delete connection:" << path.path();
                    return false;
                } else {
                    qDebug() << "Successfully deleted connection with SSID:" << ssid;
                    // break; not sure if this is a good idea ??
                }
            }
        }
    }

    if (!ssidFound) {
        qDebug() << "SSID not found in the list of connections. Proceeding.";
    }

    QDBusConnection::systemBus().disconnectFromBus(QDBusConnection::systemBus().name());
    return true;
}

bool QRCodeHandler::deactivateConnection() {
    QDBusInterface nmProperties("org.freedesktop.NetworkManager",
                                "/org/freedesktop/NetworkManager",
                                "org.freedesktop.DBus.Properties",
                                QDBusConnection::systemBus());

    if (!nmProperties.isValid()) {
        qWarning() << "Failed to connect to dbus";
        return false;
    }

    QDBusInterface nmInterface("org.freedesktop.NetworkManager",
                               "/org/freedesktop/NetworkManager",
                               "org.freedesktop.NetworkManager",
                               QDBusConnection::systemBus());

    if (!nmInterface.isValid()) {
        qWarning() << "Failed to connect to dbus";
        return false;
    }

    QDBusMessage reply = nmProperties.call("Get", "org.freedesktop.NetworkManager", "ActiveConnections");

    if (reply.type() != QDBusMessage::ReplyMessage) {
        qWarning() << "DBus query failed! reply.type() != QDBusMessage::ReplyMessage";
        return false;
    }

    QList<QVariant> outArgs = reply.arguments();
    QVariant first = outArgs.at(0);
    QDBusVariant dbvFirst = first.value<QDBusVariant>();
    QVariant vFirst = dbvFirst.variant();
    QDBusArgument dbusArgs = vFirst.value<QDBusArgument>();

    QDBusObjectPath objPath;
    bool deactivated = false;

    dbusArgs.beginArray();
    while (!dbusArgs.atEnd()) {
        dbusArgs >> objPath;
        qDebug() <<"Active connection path is: "<< objPath.path();

        QDBusInterface activeConnectionProperties("org.freedesktop.NetworkManager",
                                                  objPath.path(),
                                                  "org.freedesktop.DBus.Properties",
                                                  QDBusConnection::systemBus());

        if (!activeConnectionProperties.isValid()) {
            qWarning() << "Failed to connect to dbus";
            return false;
        }

        QDBusReply<QVariant> reply = activeConnectionProperties.call("Get", "org.freedesktop.NetworkManager.Connection.Active", "Type");

        if (!reply.isValid()) {
            qDebug() << "Failed to retrieve active connection type. Error:" << reply.error().message();
        } else {
            QString activeType = reply.value().toString();
            qDebug() << "Active connection type is: " << activeType;

            if (activeType == "802-11-wireless")  {
                QDBusReply<void> deactivateReply = nmInterface.call("DeactivateConnection", QVariant::fromValue(objPath));

                if (!deactivateReply.isValid()) {
                    qWarning() << "Failed to deactivate path: " << objPath.path() << " " << deactivateReply.error().name() << " : " << reply.error().message();
                    QDBusConnection::systemBus().disconnectFromBus(QDBusConnection::systemBus().name());
                    return false;
                } else {
                    qDebug() << "Deactivated path: " << objPath.path() << " successfully";
                    deactivated = true;
                }
            }
        }
    }

    if (!deactivated) {
        qDebug() << "No wireless connection was deactivated. Proceeding.";
    }

    dbusArgs.endArray();
    QDBusConnection::systemBus().disconnectFromBus(QDBusConnection::systemBus().name());
    return true;
}

QString QRCodeHandler::getWifiId() {
    return ssid;
}