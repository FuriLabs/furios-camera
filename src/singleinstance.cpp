// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Furi Labs
//
// Authors:
// Bardia Moshiri <bardia@furilabs.com>

#include "singleinstance.h"
#include <QLocalSocket>

SingleInstance::SingleInstance(QObject *parent) : QObject(parent), m_server(new QLocalServer(this)) {
    connect(m_server, &QLocalServer::newConnection, this, &SingleInstance::onNewConnection);
}

bool SingleInstance::listen(const QString &serverName) {
    if (!m_server->listen(serverName)) {
        QLocalSocket socket;
        socket.connectToServer(serverName);
        if (socket.waitForConnected(500)) {
            socket.write("SHOW");
            socket.waitForBytesWritten();
            return false;
        }
        m_server->removeServer(serverName);
        return m_server->listen(serverName);
    }
    return true;
}

void SingleInstance::onNewConnection() {
    QLocalSocket *socket = m_server->nextPendingConnection();
    if (socket) {
        connect(socket, &QLocalSocket::readyRead, [this, socket]() {
            if (socket->readAll() == "SHOW") {
                emit showWindow();
            }
        });
    }
}
