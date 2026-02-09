#pragma once

#include <QObject>

class GalleryManager : public QObject {
    Q_OBJECT

public:
    static GalleryManager *get_gallery_manager_instance();

public slots:
    void onQmlRequestedScan(); 

private:
    explicit GalleryManager(QObject *parent = nullptr);
    ~GalleryManager();

    GalleryManager(const GalleryManager &) = delete;
    GalleryManager &operator=(const GalleryManager &) = delete;
};