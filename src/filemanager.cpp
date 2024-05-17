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
#include <QProcess>

FileManager::FileManager(QObject *parent) : QObject(parent) {
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

// ***************** Picture Metada *****************

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
    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    std::tm tm = {};
    std::istringstream ss(metadata.DateTime);

    ss >> std::get_time(&tm, "%Y:%m:%d %H:%M:%S");
    if (ss.fail()) {
        return "Invalid date/time";
    }

    char buffer[80];
    // Formats to "Month day time"
    strftime(buffer, sizeof(buffer), "%b %d %H:%M", &tm);
    return QString::fromStdString(buffer);
}

QString FileManager::getCameraHardware(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    std::string make = metadata.Make;
    std::string model = metadata.Model;

    return QString("%1 %2").arg(QString::fromStdString(make)).arg(QString::fromStdString(model));
}

QString FileManager::getDimensions(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    int width = metadata.ImageWidth;
    int height = metadata.ImageHeight;

    return QString("%1 x %2").arg(QString::number(width)).arg(QString::number(height));
}

QString FileManager::getFStop(const QString &fileUrl) { // Aperture settings
    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    float fNumber = metadata.FNumber;

    return QString("f/%1").arg(QString::number(fNumber));
}

QString FileManager::getExposure(const QString &fileUrl) { // Exposure Time
    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    unsigned int exposure = static_cast<unsigned int>(1.0 / metadata.ExposureTime);

    return QString("1/%1 s").arg(QString::number(exposure));
}

QString FileManager::getISOSpeed(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    int iso = metadata.ISOSpeedRatings;

    return QString("ISO: %1").arg(QString::number(iso));
}

QString FileManager::getExposureBias(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    float exposureBias = metadata.ExposureBiasValue;


    return QString("%1 EV").arg(QString::number(exposureBias));
}
QString FileManager::focalLengthStandard(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    unsigned short focalLength = metadata.FocalLengthIn35mm;

    return QString("35mm focal length: %1 mm").arg(QString::number(focalLength));
}

QString FileManager::focalLength(const QString &fileUrl) {
    easyexif::EXIFInfo metadata = getPictureMetaData(fileUrl);

    float focalLength = metadata.FocalLength;

    return QString("%1 mm").arg(QString::number(focalLength));
}

bool FileManager::getFlash(const QString &fileUrl) {
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

    // Use QProcess to call mkvinfo
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

    // Debug the full output
    qDebug() << "Full mkvinfo output:" << output;

    // Parse mkvinfo output
    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        // Capture relevant metadata lines
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
                return dateTime.toString("MMM d HH:mm");
            }
            break;
        }
    }
    return "Date not found.";
}

void FileManager::getPixelHeight(const QString &fileUrl) {
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        if (line.contains("Pixel height")) {
            qDebug() << "Pixel height:" << line.trimmed();
            return;
        }
    }
    qDebug() << "Pixel height not found.";
}

void FileManager::getDuration(const QString &fileUrl) {
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        if (line.contains("Duration")) {
            qDebug() << "Duration:" << line.trimmed();
            return;
        }
    }
    qDebug() << "Duration not found.";
}

void FileManager::getMuxingApplication(const QString &fileUrl) {
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        if (line.contains("Muxing application")) {
            qDebug() << "Muxing application:" << line.trimmed();
            return;
        }
    }
    qDebug() << "Muxing application not found.";
}

void FileManager::getWritingApplication(const QString &fileUrl) {
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    for (const QString &line : outputLines) {
        if (line.contains("Writing application")) {
            qDebug() << "Writing application:" << line.trimmed();
            return;
        }
    }
    qDebug() << "Writing application not found.";
}

void FileManager::getTrackInfo(const QString &fileUrl) {
    QString output = runMkvInfo(fileUrl);
    QStringList outputLines = output.split('\n');
    bool trackInfoStarted = false;
    for (const QString &line : outputLines) {
        if (line.contains("Track")) {
            trackInfoStarted = true;
        }
        if (trackInfoStarted) {
            if (line.contains("Track number") || line.contains("Track type") ||
                line.contains("Codec ID") || line.contains("Name") ||
                line.contains("Pixel width") || line.contains("Pixel height") ||
                line.contains("Sampling frequency") || line.contains("Channels")) {
                qDebug() << line.trimmed();
            }
        }
    }
}