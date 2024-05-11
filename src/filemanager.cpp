// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2023 Droidian Project
//
// Authors:
// Bardia Moshiri <fakeshell@bardia.tech>
// Erik Inkinen <erik.inkinen@gmail.com>
// Alexander Rutz <alex@familyrutz.com>
// Joaquin Philco <joaquinphilco@gmail.com>

#include "filemanager.h"
#include "exif.h"
#include <QDir>
#include <QStandardPaths>
#include <QFile>
#include <QDateTime>
#include <QDebug>
#include <iomanip>

FileManager::FileManager(QObject *parent) : QObject(parent) {
}

void FileManager::createDirectory(const QString &path) {
    QDir dir;

    QString homePath = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    if (!dir.exists(homePath + path)) {
        dir.mkpath(homePath + path);
    }
}

void FileManager::removeGStreamerCacheDirectory() {
    QString homePath = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QString filePath = homePath + "/.cache/gstreamer-1.0/registry.aarch64.bin";
    QDir dir(homePath + "/.cache/gstreamer-1.0/");

    QFile file(filePath);

    if (file.exists()) {
         QFileInfo fileInfo(file);
         QDateTime lastModified = fileInfo.lastModified();

         if (lastModified.addDays(7) < QDateTime::currentDateTime()) {
             dir.removeRecursively();
         }
    }
}

QString FileManager::getConfigFile() {
    QFileInfo primaryConfig("/usr/lib/droidian/device/droidian-camera.conf");
    QFileInfo secodaryConfig("/etc/droidian-camera.conf");

    if (primaryConfig.exists()) {
        return primaryConfig.absoluteFilePath();
    } else if (secodaryConfig.exists()) {
        return secodaryConfig.absoluteFilePath();
    } else {
        return "None";
    }
}

bool FileManager::deleteImage(const QString &fileUrl) {
    QString path = fileUrl;
    int colonIndex = path.indexOf(':');

    if (colonIndex != -1) {
        path.remove(0, colonIndex + 1);
    }

    QFile file(path);

    return file.exists() && file.remove();
}


easyexif::EXIFInfo FileManager::returnMetaData(const QString &fileUrl){

    QString path = fileUrl;
    int colonIndex = path.indexOf(':');

    if (colonIndex != -1) {
        path.remove(0, colonIndex + 1);
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning("Can't open file.");
    }

    QByteArray fileContent = file.readAll();
    if (fileContent.isEmpty()) {
        qWarning("Can't read file.");
    }
    file.close();

    easyexif::EXIFInfo result;
    int code = result.parseFrom(reinterpret_cast<unsigned char*>(fileContent.data()), fileContent.size());
    if (code) {
        qWarning() << "Error parsing EXIF: code" << code;
    }

    return result;
}

QString FileManager::getDate(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = returnMetaData(fileUrl);

    std::tm tm = {};
    std::istringstream ss(metadata.DateTime);

    ss >> std::get_time(&tm, "%Y:%m:%d %H:%M:%S");
    if (ss.fail()) {
        return "Image date/time: Invalid date/time\n";
    }

    char buffer[80];
    // Formats to [Weekday Name] Day\nHH:MM
    strftime(buffer, sizeof(buffer), "%A %d\n%H:%M", &tm);
    return QString::fromStdString(buffer);
}

QString FileManager::getCameraHardware(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = returnMetaData(fileUrl);

    std::string make = metadata.Make;
    std::string model = metadata.Model;

    return QString("%1 %2").arg(QString::fromStdString(make)).arg(QString::fromStdString(model));
}

QString FileManager::getDimensions(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = returnMetaData(fileUrl);

    int width = metadata.ImageWidth;
    int height = metadata.ImageHeight;

    return QString("%1 x %2").arg(QString::number(width)).arg(QString::number(height));
}

QString FileManager::getFStop(const QString &fileUrl) { // Aperture settings
    easyexif::EXIFInfo metadata = returnMetaData(fileUrl);

    float fNumber = metadata.FNumber;

    return QString("f/%1").arg(QString::number(fNumber));
}

QString FileManager::getExposure(const QString &fileUrl) { // Exposure Time
    easyexif::EXIFInfo metadata = returnMetaData(fileUrl);

    unsigned int exposure = static_cast<unsigned int>(1.0 / metadata.ExposureTime);

    return QString("1/%1 s").arg(QString::number(exposure));
}

QString FileManager::getISOSpeed(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = returnMetaData(fileUrl);

    int iso = metadata.ISOSpeedRatings;

    return QString("ISO: %1").arg(QString::number(iso));
}

QString FileManager::getExposureBias(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = returnMetaData(fileUrl);

    float exposureBias = metadata.ExposureBiasValue;


    return QString("%1 EV").arg(QString::number(exposureBias));
}
QString FileManager::focalLengthStandard(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = returnMetaData(fileUrl);

    unsigned short focalLength = metadata.FocalLengthIn35mm;

    return QString("35mm focal length: %1 mm").arg(QString::number(focalLength));
}

QString FileManager::focalLength(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = returnMetaData(fileUrl);

    float focalLength = metadata.FocalLength;

    return QString("%1 mm").arg(QString::number(focalLength));
}

bool FileManager::getFlash(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = returnMetaData(fileUrl);
    
    return  metadata.Flash == '1';
}