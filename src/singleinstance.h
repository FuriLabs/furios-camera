// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Furi Labs
//
// Authors:
// Bardia Moshiri <bardia@furilabs.com>

#pragma once

#include <QObject>
#include <QLocalServer>

class SingleInstance : public QObject
{
    Q_OBJECT
public:
    explicit SingleInstance(QObject *parent = nullptr);
    bool listen(const QString &serverName);

signals:
    void showWindow();

private slots:
    void onNewConnection();

private:
    QLocalServer *m_server;
};
