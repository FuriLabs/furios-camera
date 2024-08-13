// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

#ifndef QRCODEHANDLER_H
#define QRCODEHANDLER_H

#include <QObject>
#include <QDBusMessage>

typedef QMap<QString, QVariantMap> Connection;

class QRCodeHandler : public QObject {
    Q_OBJECT

public:
    explicit QRCodeHandler(QObject *parent = nullptr);
    Q_INVOKABLE QString parseQrString(const QString &qrString);
    Q_INVOKABLE void openUrlInFirefox(const QString &url);
    Q_INVOKABLE void connectToWifi();
    bool forgetConnection();
    bool deactivateConnection();
    quint8 getSignalStrength(const QString &ap);
    QList<QString> getWiFiDevices(); 
    bool scanWiFiAccessPoints();
    Q_INVOKABLE QString getWifiId();

public slots:
    void onAccessPointAdded(const QDBusMessage &message);

private:
    QString protocol = "";
    QString ssid = "";
    QString password = "";
    QString WiFiDevice = "";
    int accessPointAddedCalled = 0;
};

#endif // QRCODEHANDLER_H