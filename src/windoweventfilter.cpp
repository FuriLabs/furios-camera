// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Furi Labs
//
// Authors:
// Bardia Moshiri <bardia@furilabs.com>

#include "windoweventfilter.h"
#include <QEvent>

WindowEventFilter::WindowEventFilter(QQuickWindow* window, QSystemTrayIcon* trayIcon)
    : m_window(window), m_trayIcon(trayIcon)
{
}

bool WindowEventFilter::eventFilter(QObject* obj, QEvent* event)
{
    if (obj == m_window && event->type() == QEvent::Close) {
        event->ignore();
        m_window->hide();
        m_trayIcon->showMessage("FuriOS Camera", "Application is still running in the background.");
        emit windowClosed();
        return true;
    }
    return QObject::eventFilter(obj, event);
}
