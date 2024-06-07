// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

#include "settingsmanager.h"

SettingsManager& SettingsManager::instance() {
    static SettingsManager _instance;
    return _instance;
}

void SettingsManager::initialize(QQmlApplicationEngine *engine) {
    m_engine = engine;
    fetchSettingsFromQML();
}

void SettingsManager::fetchSettingsFromQML() {
    if (!m_engine->rootObjects().isEmpty()) {
        QObject *rootObject = m_engine->rootObjects().first();
        QObject *settingsObject = rootObject->findChild<QObject*>("settingsObject");

        if (settingsObject) {
            m_gpsOn = settingsObject->property("gpsOn").toBool();
        }
    }
}

bool SettingsManager::gpsOn() const {
    return m_gpsOn;
}
