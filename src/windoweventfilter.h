// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Furi Labs
//
// Authors:
// Bardia Moshiri <bardia@furilabs.com>

#ifndef WINDOWEVENTFILTER_H
#define WINDOWEVENTFILTER_H

#include <QObject>
#include <QQuickWindow>
#include <QSystemTrayIcon>

class WindowEventFilter : public QObject
{
    Q_OBJECT
public:
    WindowEventFilter(QQuickWindow* window, QSystemTrayIcon* trayIcon);

protected:
    bool eventFilter(QObject* obj, QEvent* event) override;

signals:
    void windowClosed();

private:
    QQuickWindow* m_window;
    QSystemTrayIcon* m_trayIcon;
};

#endif // WINDOWEVENTFILTER_H
