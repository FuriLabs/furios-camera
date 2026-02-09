// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Furi Labs
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

#include "gallery_manager.h"
#include <QProcess>
#include <QDebug>

GalleryManager::GalleryManager(QObject *parent)
    : QObject(parent)
{
}

GalleryManager::~GalleryManager()
{
}

GalleryManager *GalleryManager::get_gallery_manager_instance()
{
    static GalleryManager *instance = nullptr;
    if (!instance)
        instance = new GalleryManager;
    return instance;
}

void GalleryManager::onQmlRequestedScan()
{
    QProcess::startDetached("/usr/bin/io.FuriOS.Gallery", {});
}