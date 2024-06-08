// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2023 Droidian Project
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
#include <iomanip>
#include <exiv2/exiv2.hpp>
#include <cmath>

GeoClueFind* geoClueInstance = nullptr;
int locationAvailable = 0;

FileManager::FileManager(QObject *parent) : QObject(parent) {
}

FileManager::~FileManager() {
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

    Exiv2::Image::AutoPtr image = Exiv2::ImageFactory::open(fileUrl.toStdString());
    if (!image.get()) {
        qDebug() << "Error: Could not open image file";
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

// ***************** Picture Metadata *****************

easyexif::EXIFInfo FileManager::getPictureMetaData(const QString &fileUrl){

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

QString FileManager::getPictureDate(const QString &fileUrl) {

    if (fileUrl == "") {
        return QString("");
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    std::tm tm = {};
    std::istringstream ss(metadata.DateTime);

    ss >> std::get_time(&tm, "%Y:%m:%d %H:%M:%S");
    if (ss.fail()) {
        return "Invalid date/time";
    }

    char buffer[80];
    // Formats to "Month day Year    HH:mm"
    strftime(buffer, sizeof(buffer), "%b %d, %Y \n %H:%M", &tm);
    return QString::fromStdString(buffer);
}

QString FileManager::getCameraHardware(const QString &fileUrl) {

    if (fileUrl == "") {
        return QString("");
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    std::string make = metadata.Make;
    std::string model = metadata.Model;

    return QString("%1 %2").arg(QString::fromStdString(make)).arg(QString::fromStdString(model));
}

QString FileManager::getDimensions(const QString &fileUrl) {

    if (fileUrl == "") {
        return QString("");
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    int width = metadata.ImageWidth;
    int height = metadata.ImageHeight;

    return QString("%1 x %2").arg(QString::number(width)).arg(QString::number(height));
}

QString FileManager::getFStop(const QString &fileUrl) { // Aperture settings

    if (fileUrl == "") {
        return QString("");
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    float fNumber = metadata.FNumber;

    return QString("f/%1").arg(QString::number(fNumber));
}

QString FileManager::getExposure(const QString &fileUrl) { // Exposure Time

    if (fileUrl == "") {
        return QString("");
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    unsigned int exposure = static_cast<unsigned int>(1.0 / metadata.ExposureTime);

    return QString("1/%1 s").arg(QString::number(exposure));
}

QString FileManager::getISOSpeed(const QString &fileUrl) {

    if (fileUrl == "") {
        return QString("");
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    int iso = metadata.ISOSpeedRatings;

    return QString("ISO: %1").arg(QString::number(iso));
}

QString FileManager::getExposureBias(const QString &fileUrl) {

    if (fileUrl == "") {
        return QString("");
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    float exposureBias = metadata.ExposureBiasValue;


    return QString("%1 EV").arg(QString::number(exposureBias));
}

QString FileManager::focalLengthStandard(const QString &fileUrl) {

    if (fileUrl == "") {
        return QString("");
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    unsigned short focalLength = metadata.FocalLengthIn35mm;

    return QString("35mm focal length: %1 mm").arg(QString::number(focalLength));
}

QString FileManager::focalLength(const QString &fileUrl) {

    if (fileUrl == "") {
        return QString("");
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    float focalLength = metadata.FocalLength;

    return QString("%1 mm").arg(QString::number(focalLength));
}

bool FileManager::getFlash(const QString &fileUrl) {

    if (fileUrl == "") {
        return false;
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);
    
    return  metadata.Flash == '1';
}

// ***************** Video Metadata *****************

void FileManager::getVideoMetadata(const QString &fileUrl) {
    QStringList metadataList;
    qDebug() << "Requesting Date for Video";

    QString path = fileUrl;
    int colonIndex = path.indexOf(':');

    if (colonIndex != -1) {
        path.remove(0, colonIndex + 1);
    }

    QProcess process;
    process.setProgram("mkvinfo");
    process.setArguments(QStringList() << path);

    process.start();
    if (!process.waitForFinished()) {
        qDebug() << "Error executing mkvinfo:" << process.errorString();
        return;
    }

    QString output = process.readAllStandardOutput();
    QString errorOutput = process.readAllStandardError();

    if (!errorOutput.isEmpty()) {
        qDebug() << "mkvinfo error output:" << errorOutput;
    }

    qDebug() << "Full mkvinfo output:" << output;

    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        if (line.contains("Duration") || line.contains("Title") ||
            line.contains("Muxing application") || line.contains("Writing application") ||
            line.contains("Track number") || line.contains("Track type") ||
            line.contains("Codec ID") || line.contains("Pixel width") ||
            line.contains("Pixel height") || line.contains("Channels") ||
            line.contains("Sampling frequency") || line.contains("Date")) {
            metadataList << line.trimmed();
        }
    }

    qDebug() << "Metadata Tags:";
    for (const QString &info : metadataList) {
        qDebug() << info;
    }
}

QString FileManager::runMkvInfo(const QString &fileUrl) {
    QString path = fileUrl;
    int colonIndex = path.indexOf(':');
    if (colonIndex != -1) {
        path.remove(0, colonIndex + 1);
    }

    QProcess process;
    process.setProgram("mkvinfo");
    process.setArguments(QStringList() << path);
    process.start();
    if (!process.waitForFinished()) {
        qDebug() << "Error executing mkvinfo:" << process.errorString();
        return "";
    }

    QString output = process.readAllStandardOutput();
    QString errorOutput = process.readAllStandardError();
    if (!errorOutput.isEmpty()) {
        qDebug() << "mkvinfo error output:" << errorOutput;
    }

    return output;
}

QString FileManager::getVideoDate(const QString &fileUrl) {
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        if (line.contains("Date")) {
            QString dateLine = line.trimmed();
            QString dateTimeStr = dateLine.section(':', 1).trimmed();
            QDateTime dateTime = QDateTime::fromString(dateTimeStr, "yyyy-MM-dd HH:mm:ss t");
            if (dateTime.isValid()) {
                return dateTime.toString("MMM d, yyyy \n HH:mm");
            }
            break;
        }
    }
    return QString("Date not found.");
}

QString FileManager::getVideoDimensions(const QString &fileUrl) {
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    QString width, height;

    for (const QString &line : outputLines) {
        if (line.contains("Pixel width")) {
            width = line.split(':').last().trimmed();
        } else if (line.contains("Pixel height")) {
            height = line.split(':').last().trimmed();
        }
    }

    if (!width.isEmpty() && !height.isEmpty()) {
        return QString("%1x%2").arg(width).arg(height);
    } else {
        qDebug() << "Dimensions not found.";
        return QString("Dimensions not found.");
    }
}

QString FileManager::getDuration(const QString &fileUrl) {
    qDebug() << "Video Component";
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        if (line.contains("Duration")) {
            QString string = QString( "Duration: ") + line.trimmed();
            qDebug() << string;
            return string;
        }
    }
    qDebug() << "Duration not found.";
    return QString("Duration not found.");
}

QString FileManager::getMultiplexingApplication(const QString &fileUrl) {
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        if (line.contains("Multiplexing application:")) {
            QString multiplexingApplication = line.split(':').last().trimmed();
            return QString("%1").arg(multiplexingApplication);
        }
    }
    return QString("Multiplexing Application: Not found");
}

QString FileManager::getWritingApplication(const QString &fileUrl) {
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        if (line.contains("Writing application")) {
            QString string =  line.trimmed();
            return string;
        }
    }
    qDebug() << "Writing application not found.";
    return "";
}

QString FileManager::getDocumentType(const QString &fileUrl) {
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        if (line.contains("Document type:")) {
            QString documentType = line.split(':').last().trimmed();
            return QString("File Type: %1").arg(documentType);
        }
    }
    return QString("File Type: Not found");
}

QString FileManager::getCodecId(const QString &fileUrl) {
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        if (line.contains("Codec ID:")) {
            QString codecId = line.split(':').last().trimmed();
            return QString("Codec ID: %1").arg(codecId);
        }
    }
    return QString("Codec ID: Not found");
}

// ***************** GPS Metadata *****************

bool FileManager::gpsMetadataAvailable(const QString &fileUrl) {
    if (fileUrl == "") {
        return false;
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    if (metadata.GeoLocation.Latitude != 0.0 || metadata.GeoLocation.Longitude != 0.0) {
        return true;
    }

    return false;
}

QString FileManager::getGpsMetadata(const QString &fileUrl) {

    if (fileUrl == "" || !gpsMetadataAvailable(fileUrl)) {
        return QString("");
    }

    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    return QString("Lat: %1 | Lon: %2")
        .arg(metadata.GeoLocation.Latitude, 0, 'f', 6)
        .arg(metadata.GeoLocation.Longitude, 0, 'f', 6);
}

QStringList FileManager::getCurrentLocation() {
    QStringList coordinates;
    if (locationAvailable == 1) {
        GeoClueFind* geoClue = geoClueInstance;
        geoClue->updateProperties();
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

void FileManager::turnOnGps() {
    qDebug() << "turning on gps";
    if (geoClueInstance == nullptr) {
        geoClueInstance = new GeoClueFind(this);
        connect(geoClueInstance, &GeoClueFind::locationUpdated, this, &FileManager::onLocationUpdated);
    }
}

void FileManager::turnOffGps() {
    GeoClueFind* geoClue = geoClueInstance;
    geoClue->stopClient();
    delete geoClueInstance;
    geoClueInstance = nullptr;
}

void FileManager::onLocationUpdated() {
    qDebug() << "Location Available";
    locationAvailable = 1;
    emit gpsDataReady();
}