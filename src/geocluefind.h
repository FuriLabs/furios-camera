// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
// Copyright (C) 2024 Furi Labs
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

#ifndef GEOCLUEFIND_H
#define GEOCLUEFIND_H

#include <QObject>
#include <QString>
#include <QDBusInterface>
#include <QVariantMap>
#include <QStringList>
#include <QDBusReply>

struct Timestamp {
    int time1, time2;
};

struct GeoClueProperties {
    float Latitude;
    float Longitude;
    float Accuracy;
    float Altitude;
    float Speed;
    float Heading;
    QString Description;
    Timestamp timestamp;
};

class GeoClueFind : public QObject
{
    Q_OBJECT
public:
    explicit GeoClueFind(QObject *parent = nullptr);
    ~GeoClueFind();

    void getGeoclueClient();
    void setClientInterface();
    void stopClient();
    GeoClueProperties getProperties() const;

signals:
    void locationUpdated();
    void clientDeleted();

public slots:
    void locationAvailable(QDBusObjectPath oldLocation, QDBusObjectPath newLocations);

private:
    GeoClueProperties* m_properties;
    QString* m_clientObjPath;
    QString* m_locationObjPath;
};

#endif // GEOCLUEFIND_H