// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2023 Droidian Project
// Copyright (C) 2026 Furi Labs
//
// Authors:
// Bardia Moshiri <fakeshell@bardia.tech>
// Erik Inkinen <erik.inkinen@gmail.com>
// Alexander Rutz <alex@familyrutz.com>
// Joaquin Philco <joaquinphilco@gmail.com>

#include "filemanager.h"
#include "geocluefind.h"
#include "exif.h"
#include <QDir>
#include <QStandardPaths>
#include <QFile>
#include <QProcess>
#include <QDateTime>
#include <QDebug>
#include <QUrl>
#include <iomanip>
#include <exiv2/exiv2.hpp>
#include <cmath>


FileManager::FileManager(QObject *parent) : QObject(parent), m_geoClueInstance(nullptr), m_locationAvailable(new int(0)) {
}

FileManager::~FileManager() {
    delete m_geoClueInstance;
    delete m_locationAvailable;
}

// ***************** File Management *****************
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
    QFileInfo primaryConfig("/usr/lib/furios/device/furios-camera.conf");
    QFileInfo secodaryConfig("/etc/furios-camera.conf");

    if (primaryConfig.exists()) {
        return primaryConfig.absoluteFilePath();
    } else if (secodaryConfig.exists()) {
        return secodaryConfig.absoluteFilePath();
    } else {
        return "None";
    }
}

QStringList FileManager::decimalToDMS(double decimal, bool isLongitude) { // This is based on the exiv2 tag lists
    int degrees = static_cast<int>(decimal);
    double decimalMinutes = std::abs(decimal - degrees) * 60;
    int minutes = static_cast<int>(decimalMinutes);
    double decimalSeconds = (decimalMinutes - minutes) * 60;

    // Represent seconds with 1/100 precision
    unsigned int uSeconds = static_cast<unsigned int>(decimalSeconds * 100);

    // Format degrees as three digits if it's longitude
    QString degreesStr = QString::number(std::abs(degrees));
    if (isLongitude) {
        degreesStr = QString("%1").arg(std::abs(degrees), 3, 10, QChar('0'));
    }

    return QStringList() << QString("%1/1").arg(degreesStr) << QString("%1/1").arg(minutes) << QString("%1/100").arg(uSeconds);
}

void FileManager::appendGPSMetadata(const QString &fileUrl) {

    QStringList coordinates = getCurrentLocation();

    if (coordinates.size() != 4) {
        qDebug() << "Error: Invalid number of coordinates";
        return;
    }

    QString latitude = coordinates[0];
    QString longitude = coordinates[1];
    QString altitude = coordinates[2];
    QString heading = coordinates[3];

    double lat = latitude.toDouble();
    double lon = longitude.toDouble();
    double alt = altitude.toDouble();
    double hdg = heading.toDouble();

    std::unique_ptr<Exiv2::Image> image = Exiv2::ImageFactory::open(fileUrl.toStdString());
    if (!image) {
        qDebug() << "Error: Could not open image file: " << fileUrl;
        return;
    }
    image->readMetadata();

    Exiv2::ExifData& exifData = image->exifData();

    QStringList latDMS = decimalToDMS(lat);
    exifData["Exif.GPSInfo.GPSLatitude"] = latDMS.join(" ").toStdString();
    exifData["Exif.GPSInfo.GPSLatitudeRef"] = (lat >= 0) ? "N" : "S";

    QStringList lonDMS = decimalToDMS(lon, true);
    exifData["Exif.GPSInfo.GPSLongitude"] = lonDMS.join(" ").toStdString();
    exifData["Exif.GPSInfo.GPSLongitudeRef"] = (lon >= 0) ? "E" : "W";

    if (alt != -1.79769e+308) {
        exifData["Exif.GPSInfo.GPSAltitude"] = QString("%1/1").arg(std::abs(alt)).toStdString();
        exifData["Exif.GPSInfo.GPSAltitudeRef"] = (alt >= 0) ? "0" : "1";  // 0 = Above sea level, 1 = Below sea level
    }

    if (hdg != -1) {
        exifData["Exif.GPSInfo.GPSImgDirection"] = QString("%1/1").arg(hdg).toStdString();
        exifData["Exif.GPSInfo.GPSImgDirectionRef"] = "T";
    }

    image->writeMetadata();
}

qint64 FileManager::getMediaEpochMs(const QString &fileUrl) {
    const QString filePath = QUrl(fileUrl).toLocalFile();
    QFileInfo fi(filePath);
    if (!fi.exists()) return -1;

    return fi.lastModified().toMSecsSinceEpoch(); // Filesystem timestamp
}

QString FileManager::getTimeFormat() {

    QProcess process;
    process.start("gsettings", QStringList() << "get" << "org.gnome.desktop.interface" << "clock-format");
    process.waitForFinished();

    return process.readAllStandardOutput().trimmed();
}

// ***************** GPS Metadata *****************
QStringList FileManager::getCurrentLocation() {
    QStringList coordinates;
    if (*m_locationAvailable == 1) {
        GeoClueFind* geoClue = m_geoClueInstance;
        GeoClueProperties props = geoClue->getProperties();

        coordinates.append(QString::number(props.Latitude, 'f', 6));
        coordinates.append(QString::number(props.Longitude, 'f', 6));
        coordinates.append(QString::number(props.Altitude, 'f', 6));
        coordinates.append(QString::number(props.Heading, 'f', 6));
    } else {
        qDebug() << "GPS data not available yet";
    }
    return coordinates;
}

void FileManager::restartGps() {
    m_geoClueInstance = new GeoClueFind(this);
    connect(m_geoClueInstance, &GeoClueFind::locationUpdated, this, &FileManager::onLocationUpdated);
    connect(m_geoClueInstance, &GeoClueFind::clientDeleted, this, &FileManager::onClientDeleted);
}

void FileManager::turnOnGps() {
    qDebug() << "Turning on gps";
    if (m_geoClueInstance == nullptr) {
        m_geoClueInstance = new GeoClueFind(this);
        connect(m_geoClueInstance, &GeoClueFind::locationUpdated, this, &FileManager::onLocationUpdated);
        connect(m_geoClueInstance, &GeoClueFind::clientDeleted, this, &FileManager::onClientDeleted);
    }
}

void FileManager::turnOffGps() {
    GeoClueFind* geoClue = m_geoClueInstance;

    if (geoClue) {
        geoClue->stopClient();
    } else {
        qDebug() << "GeoClue instance is null!";
    }
}

void FileManager::onLocationUpdated() {
    *m_locationAvailable = 1;
    emit gpsDataReady();
}

void FileManager::onClientDeleted() {
    delete m_geoClueInstance;
    m_geoClueInstance = nullptr;
}
