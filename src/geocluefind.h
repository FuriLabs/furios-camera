// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
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
    GeoClueProperties getProperties() const;
    void updateProperties();

signals:
    void locationUpdated();
    
public slots:
    void locationAvailable(QDBusObjectPath oldLocation, QDBusObjectPath newLocations);
    void handlePropertiesUpdated(const QString &interface_name,
                                const QVariantMap &changed_properties,
                                const QStringList &invalidated_properties);

private:
    GeoClueProperties properties;
};

#endif // GEOCLUEFIND_H