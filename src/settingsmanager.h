// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

#ifndef SETTINGSMANAGER_H
#define SETTINGSMANAGER_H

#include <QObject>
#include <QQmlApplicationEngine>

class SettingsManager : public QObject {
    Q_OBJECT
public:
    static SettingsManager& instance();
    void initialize(QQmlApplicationEngine *engine);

    bool gpsOn() const;

private:
    QQmlApplicationEngine *m_engine = nullptr;
    mutable bool m_gpsOn = false;

    SettingsManager() {}
    void fetchSettingsFromQML();
};

#endif // SETTINGSMANAGER_H
