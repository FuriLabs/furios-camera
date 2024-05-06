// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

#ifndef QRCODEHANDLER_H
#define QRCODEHANDLER_H

#include <QObject>

class QRCodeHandler : public QObject {
    Q_OBJECT

public:
    explicit QRCodeHandler(QObject *parent = nullptr);
    Q_INVOKABLE void openUrlInFirefox(const QString &url);
};

#endif // QRCODEHANDLER_H