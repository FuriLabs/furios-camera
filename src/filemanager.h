// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2023 Droidian Project
//
// Authors:
// Bardia Moshiri <fakeshell@bardia.tech>
// Erik Inkinen <erik.inkinen@gmail.com>
// Alexander Rutz <alex@familyrutz.com>
// Joaquin Philco <joaquinphilco@gmail.com>

#ifndef FILEMANAGER_H
#define FILEMANAGER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include "exif.h"
#include "geocluefind.h"

class FileManager : public QObject
{
    Q_OBJECT
public:
    explicit FileManager(QObject *parent = nullptr);
    ~FileManager();
// ***************** File Management *****************
    Q_INVOKABLE void createDirectory(const QString &path);
    Q_INVOKABLE void removeGStreamerCacheDirectory();
    Q_INVOKABLE QString getConfigFile();
    Q_INVOKABLE bool deleteImage(const QString &fileUrl);
// ***************** Picture Metada *****************
    Q_INVOKABLE easyexif::EXIFInfo getPictureMetaData(const QString &fileUrl);
    Q_INVOKABLE QString getPictureDate(const QString &fileUrl);
    Q_INVOKABLE QString getCameraHardware(const QString &fileUrl);
    Q_INVOKABLE QString getDimensions(const QString &fileUrl);
    Q_INVOKABLE QString getFStop(const QString &fileUrl);
    Q_INVOKABLE QString getExposure(const QString &fileUrl);
    Q_INVOKABLE QString getISOSpeed(const QString &fileUrl);
    Q_INVOKABLE QString getExposureBias(const QString &fileUrl);
    Q_INVOKABLE QString focalLengthStandard(const QString &fileUrl);
    Q_INVOKABLE QString focalLength(const QString &fileUrl);
    Q_INVOKABLE bool getFlash(const QString &fileUrl);
// ***************** Video Metadata *****************
    Q_INVOKABLE void getVideoMetadata(const QString &fileUrl);
    Q_INVOKABLE QString runMkvInfo(const QString &fileUrl);
    Q_INVOKABLE QString getVideoDate(const QString &fileUrl);
    Q_INVOKABLE QString getVideoDimensions(const QString &fileUrl);
    Q_INVOKABLE QString getDuration(const QString &fileUrl);
    Q_INVOKABLE QString getMultiplexingApplication(const QString &fileUrl);
    Q_INVOKABLE QString getWritingApplication(const QString &fileUrl);
    Q_INVOKABLE QString getDocumentType(const QString &fileUrl);
    Q_INVOKABLE QString getCodecId(const QString &fileUrl);
// ***************** GPS Metadata *****************
    Q_INVOKABLE QStringList getCurrentLocation();
    Q_INVOKABLE void turnOffGps();
    Q_INVOKABLE void turnOnGps();
    Q_INVOKABLE void appendGPSMetadata(const QString &fileUrl);
    QStringList decimalToDMS(double decimal, bool isLongitude = false);

private slots:
    void onLocationUpdated();

private:
    GeoClueFind* geoClueInstance;
};

#endif // FILEMANAGER_H
