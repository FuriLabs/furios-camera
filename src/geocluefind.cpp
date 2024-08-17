// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
// Copyright (C) 2024 Furi Labs
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

#define BUS_NAME QString("org.freedesktop.GeoClue2")
#define MANAGER_PATH QString("/org/freedesktop/GeoClue2/Manager")

GeoClueFind::GeoClueFind(QObject *parent) : QObject(parent), m_clientObjPath(new QString("")), m_properties(new GeoClueProperties()), m_locationObjPath(new QString("")) {
    qDebug() << "Init GPS Client";
    getGeoclueClient();
}

GeoClueFind::~GeoClueFind() {
    delete m_clientObjPath;
    delete m_locationObjPath;
    delete m_properties;
}

void GeoClueFind::getGeoclueClient() {

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

    qDebug() << "GeoClue Client: " << *m_clientObjPath;

    setClientInterface();
}

void GeoClueFind::setClientInterface() {

    QDBusConnection dbusConnection = QDBusConnection::systemBus();

    QDBusInterface clientInterface(BUS_NAME, *m_clientObjPath, "org.freedesktop.GeoClue2.Client", dbusConnection);
    if (!clientInterface.isValid()) {
        qWarning() << "D-Bus org.freedesktop.GeoClue2.Client interface is not valid!";
    }

    if (!clientInterface.setProperty("DesktopId", "furios-camera")) {
        qWarning() << "DBus call to set DesktopId failed";
    }

    if (!clientInterface.setProperty("DistanceThreshold", QVariant::fromValue(0u))) {
        qWarning() << "Failed to set DistanceThreshold";
    }

    if (!clientInterface.setProperty("TimeThreshold", QVariant::fromValue(0u))) {
        qWarning() << "Failed to set TimeThreshold";
    }

    if (!clientInterface.setProperty("RequestedAccuracyLevel", QVariant::fromValue<uint>(8))) {
        qWarning() << "Failed to set RequestedAccuracyLevel to EXACT";
    }

    if (!dbusConnection.connect(BUS_NAME, *m_clientObjPath, QString("org.freedesktop.GeoClue2.Client"), QString("LocationUpdated"), QString("oo"), this,
                                SLOT(locationAvailable(QDBusObjectPath, QDBusObjectPath)))) {
        qWarning() << "Unable to attach Location Updated Callback.";
    }

    QDBusMessage message = clientInterface.call("Start");

    if (message.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "DBus call to start GeoClue client failed: " << message.errorMessage();
    }
}

void GeoClueFind::locationAvailable(QDBusObjectPath oldLocation, QDBusObjectPath newLocation) {

    *m_locationObjPath = newLocation.path();

    QDBusConnection dbusConnection = QDBusConnection::systemBus();

    QDBusInterface locationInterface(BUS_NAME, *m_locationObjPath, "org.freedesktop.DBus.Properties", dbusConnection);

    if (!locationInterface.isValid()) {
        qWarning() << "D-Bus org.freedesktop.DBus.Properties interface is not valid!";
    }

    QDBusReply<QVariantMap> reply = locationInterface.call("GetAll", "org.freedesktop.GeoClue2.Location");

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

    emit locationUpdated();
}

GeoClueProperties GeoClueFind::getProperties() const {
    return *m_properties;
}

void GeoClueFind::stopClient() {

    qDebug() << "Stopping Client";

    if (m_clientObjPath->isEmpty()) {
        // if we try to remove an empty object path, it could lead to a seg fault
        qDebug() << "Failed to destroy object path: object path is invalid: " << *m_clientObjPath;
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
        qDebug() << "GeoClue Client: " << *m_clientObjPath << "deleted";
        emit clientDeleted();
    }
}
