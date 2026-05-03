// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Furi Labs
//
// Authors:
// Bardia Moshiri <bardia@furilabs.com>
// Joaquin Philco <joaquinphilco@gmail.com>

#include "utils.h"

#include <QFile>
#include <QHash>
#include <QString>
#include <QStringList>
#include <QDebug>
#include <QRegularExpression>

static const QHash<QString, QString> cameraMegaPixels = {
    { "imx586", "48" },
    { "imx350", "20" },
    { "imx135", "13" },
    { "gc2375h", "2" },
    { "ov50a40", "50" },
    { "ov16a1q", "16" },
    { "bf2253Lmacro", "2" },
    { "s5k4h7yxnight", "8" }
};

Utils::Utils(QObject *parent)
    : QObject(parent)
{
}

QStringList Utils::getMegaPixels()
{
    QStringList megaPixels;

    const QString basePath = "/proc/device-tree/kd_camera_hw1@1a004000/";

    for (int i = 0; i <= 10; ++i) {
        const QString filePath = basePath + QString("cam%1_enable_sensor").arg(i);

        QFile file(filePath);
        if (!file.exists()) {
            continue;
        }

        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            qDebug() << "Could not open camera sensor file:" << filePath;
            continue;
        }

        QString content = QString::fromUtf8(file.readAll());
        file.close();

        content.replace('\0', ' ');
        content = content.trimmed();

        QStringList sensors = content.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);

        for (QString sensor : sensors) {
            sensor.remove("_mipi_raw");
            sensor = sensor.trimmed();

            if (sensor.isEmpty()) {
                continue;
            }

            QString mp = "0";

            if (cameraMegaPixels.contains(sensor)) {
                mp = cameraMegaPixels.value(sensor);
            } else {
                qDebug() << "Unknown camera sensor:" << sensor;
            }

            megaPixels.append(QString("%1: %2").arg(i).arg(mp));
        }
    }

    return megaPixels;
}
