// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Furi Labs
//
// Authors:
// Bardia Moshiri <bardia@furilabs.com>
// Joaquin Philco <joaquinphilco@gmail.com>

#ifndef UTILS_H
#define UTILS_H

#include <QObject>
#include <QStringList>

class Utils : public QObject
{
    Q_OBJECT

public:
    explicit Utils(QObject *parent = nullptr);

    Q_INVOKABLE QStringList getMegaPixels();
};

#endif // UTILS_H
