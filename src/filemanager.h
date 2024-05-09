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
#include "exif.h"

class FileManager : public QObject
{
    Q_OBJECT
public:
    explicit FileManager(QObject *parent = nullptr);

    Q_INVOKABLE void createDirectory(const QString &path);
    Q_INVOKABLE void removeGStreamerCacheDirectory();
    Q_INVOKABLE QString getConfigFile();
    Q_INVOKABLE bool deleteImage(const QString &fileUrl);
    Q_INVOKABLE easyexif::EXIFInfo returnMetaData(const QString &fileUrl);
    Q_INVOKABLE QString getDate(const QString &fileUrl);
    Q_INVOKABLE QString getCameraHardware(const QString &fileUrl);
    Q_INVOKABLE QString getDimensions(const QString &fileUrl);
    Q_INVOKABLE QString getFStop(const QString &fileUrl);
    Q_INVOKABLE QString getExposure(const QString &fileUrl);
    Q_INVOKABLE QString getISOSpeed(const QString &fileUrl);
    Q_INVOKABLE QString getExposureBias(const QString &fileUrl);
    Q_INVOKABLE QString focalLengthStandard(const QString &fileUrl);
    Q_INVOKABLE QString focalLength(const QString &fileUrl);
    Q_INVOKABLE bool getFlash(const QString &fileUrl);
};

#endif // FILEMANAGER_H
