// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

#include "geocluefind.h"
#include <QDBusInterface>
#include <QDBusReply>
#include <QDebug>
#include <QVariantMap>
#include <QStringList>
#include <iomanip>

#define BUS_NAME "org.freedesktop.GeoClue2"
#define MANAGER_PATH "/org/freedesktop/GeoClue2/Manager"

GeoClueFind::GeoClueFind(QObject *parent) : QObject(parent), m_clientObjPath(new QString("")), m_properties(nullptr), m_locationObjPath(new QString("")) {

    qDebug() << "Creating Geoclue Object";

    QDBusConnection dbusConnection = QDBusConnection::systemBus();

    QDBusInterface dbusInterface(BUS_NAME, MANAGER_PATH, "org.freedesktop.GeoClue2.Manager", dbusConnection);
    if (!dbusInterface.isValid()) {
        qWarning() << "D-Bus org.freedesktop.GeoClue2.Manager interface is not valid!";
    }
    QDBusReply<QDBusObjectPath> reply = dbusInterface.call("GetClient");
    if (!reply.isValid()) {
        qWarning() << "DBus GetClient call failed: " << reply.error().message();
    }

    *m_clientObjPath = reply.value().path();

    qDebug() << "GeoClue Client: " << &m_clientObjPath;

    QDBusInterface clientInterface(BUS_NAME, *m_clientObjPath, "org.freedesktop.GeoClue2.Client", dbusConnection);
    if (!clientInterface.isValid()) {
        qWarning() << "D-Bus org.freedesktop.GeoClue2.Client interface is not valid!";
    }

    if (!clientInterface.setProperty("DesktopId", "CameraApp")) {
        qWarning() << "DBus call to set DesktopId failed";
    }

    if (!clientInterface.setProperty("DistanceThreshold", QVariant::fromValue(50000u))) {
        qWarning() << "DBus call failed to set DistanceThreshold failed";
    }

    QDBusMessage message = clientInterface.call("Start");

    if (message.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "DBus call to start GeoClue client failed: " << message.errorMessage();
    }

    if (!dbusConnection.connect(BUS_NAME, *m_clientObjPath, "org.freedesktop.GeoClue2.Client", "LocationUpdated", this,
                                SLOT(locationAvailable(QDBusObjectPath, QDBusObjectPath)))) {
        qWarning() << "Unable to attach Location Updated Callback.";
    }
}

GeoClueFind::~GeoClueFind() {
    delete m_clientObjPath;
    delete m_locationObjPath;
    delete m_properties;
}

void GeoClueFind::locationAvailable(QDBusObjectPath oldLocation, QDBusObjectPath newLocation) {

    *m_locationObjPath = newLocation.path();
    QDBusConnection dbusConnection = QDBusConnection::systemBus();

    bool propertiesUpdatedSignal = dbusConnection.connect(BUS_NAME, *m_locationObjPath,
                                                      "org.freedesktop.DBus.Properties",
                                                      "PropertiesChanged", this,
                                                      SLOT(handlePropertiesUpdated(QString, QVariantMap, QStringList)));

    emit locationUpdated();
}

void GeoClueFind::handlePropertiesUpdated(const QString &interface_name, const QVariantMap &changed_properties, const QStringList &invalidated_properties) {

    QDBusConnection dbusConnection = QDBusConnection::systemBus();

    QDBusInterface clientInterfacess(BUS_NAME, *m_locationObjPath, "org.freedesktop.DBus.Properties", dbusConnection);
    if (!clientInterfacess.isValid()) {
        qWarning() << "D-Bus org.freedesktop.DBus.Properties interface is not valid!";
    } else {
        qDebug() << "Connected to Location Interface DBus BUS_NAME: " << &m_locationObjPath;
    }

    QDBusReply<QVariantMap> reply = clientInterfacess.call("GetAll", "org.freedesktop.GeoClue2.Location");

    if (reply.isValid()) {
        QVariantMap propertiesMap = reply.value();

        m_properties->Latitude = propertiesMap.value("Latitude").toFloat();
        m_properties->Longitude = propertiesMap.value("Longitude").toFloat();
        m_properties->Accuracy = propertiesMap.value("Accuracy").toFloat();
        m_properties->Altitude = propertiesMap.value("Altitude").toFloat();
        m_properties->Speed = propertiesMap.value("Speed").toFloat();
        m_properties->Heading = propertiesMap.value("Heading").toFloat();
        m_properties->Description = propertiesMap.value("Description").toString();
    } else {
        qWarning() << "Failed to get properties:" << reply.error().message();
    }
}


void GeoClueFind::updateProperties() {
    QDBusConnection dbusConnection = QDBusConnection::systemBus();

    QDBusInterface clientInterfacess(BUS_NAME, *m_locationObjPath, "org.freedesktop.DBus.Properties", dbusConnection);
    if (!clientInterfacess.isValid()) {
        qWarning() << "D-Bus org.freedesktop.DBus.Properties interface is not valid!";
    }

    QDBusReply<QVariantMap> reply = clientInterfacess.call("GetAll", "org.freedesktop.GeoClue2.Location");

    if (reply.isValid()) {
        QVariantMap propertiesMap = reply.value();

        m_properties->Latitude = propertiesMap.value("Latitude").toFloat();
        m_properties->Longitude = propertiesMap.value("Longitude").toFloat();
        m_properties->Accuracy = propertiesMap.value("Accuracy").toFloat();
        m_properties->Altitude = propertiesMap.value("Altitude").toFloat();
        m_properties->Speed = propertiesMap.value("Speed").toFloat();
        m_properties->Heading = propertiesMap.value("Heading").toFloat();
        m_properties->Description = propertiesMap.value("Description").toString();
    } else {
        qWarning() << "Failed to get properties:" << reply.error().message();
    }
}

GeoClueProperties GeoClueFind::getProperties() const {
    return *m_properties;
}

void GeoClueFind::stopClient() {

    qDebug() << "Stopping Client";

    if (m_clientObjPath->isEmpty()) {
        // if we try to remove an empty object path, it could lead to a seg fault
        qDebug() << "Failed to destroy object path: object path is invalid: " << &m_clientObjPath;
        return;
    }

    QDBusConnection dbusConnection = QDBusConnection::systemBus();

    QDBusInterface managerInterface(BUS_NAME, MANAGER_PATH, "org.freedesktop.GeoClue2.Manager", dbusConnection);
    if (!managerInterface.isValid()) {
        qWarning() << "Geoclue D-Bus org.freedesktop.GeoClue2.Manager interface is not valid!";
        return;
    }

    QDBusReply<void> reply = managerInterface.call("DeleteClient", QDBusObjectPath(*m_clientObjPath));
    if (!reply.isValid()) {
        qWarning() << "D-Bus DeleteClient call failed: " << reply.error().message();
    } else {
        qDebug() << "GeoClue Client: " << &m_clientObjPath << "deleted";
        emit clientDeleted();
    }
}
