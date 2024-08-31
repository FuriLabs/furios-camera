// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

import QtQuick 2.15
import QtMultimedia 5.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import Qt.labs.folderlistmodel 2.15
import Qt.labs.platform 1.1

Item {
    id: metadataViewComponent

    property alias metadataView: metadataRect
    property string currentFileUrl: currentFileUrl
    property var scalingRatio: scalingRatio
    property var textSize: textSize
    property var avgMetadataContainerHeight: 60 * scalingRatio

    Component.onCompleted: {
        updateMetadata(currentFileUrl);
    }

    function updateMetadata(url) {
        metadataModel.clear();
        if (url !== "") {
            if (url.endsWith(".mkv")) {
                metadataModel.append({title: "File Type", value: fileManager.getDocumentType(url), dataHeight: avgMetadataContainerHeight});
                metadataModel.append({title: "File Size", value: fileManager.getFileSize(url), dataHeight: avgMetadataContainerHeight});
                metadataModel.append({title: "Video Dimensions", value: fileManager.getVideoDimensions(url), dataHeight: avgMetadataContainerHeight});
                metadataModel.append({title: "Codec ID", value: fileManager.getCodecId(url), dataHeight: avgMetadataContainerHeight});
            } else {
                metadataModel.append({title: "Maker, Model", value: fileManager.getCameraHardware(url), dataHeight: avgMetadataContainerHeight});
                metadataModel.append({title: "Image Dimensions", value: fileManager.getDimensions(url), dataHeight: avgMetadataContainerHeight});
                metadataModel.append({title: "File Size", value: fileManager.getFileSize(url), dataHeight: avgMetadataContainerHeight});
                metadataModel.append({title: "Aperture", value: fileManager.getFStop(url), dataHeight: avgMetadataContainerHeight});
                metadataModel.append({title: "Exposure", value: fileManager.getExposure(url), dataHeight: avgMetadataContainerHeight});
                metadataModel.append({title: "ISO", value: fileManager.getISOSpeed(url), dataHeight: avgMetadataContainerHeight});
                metadataModel.append({title: "Focal Length", value: fileManager.focalLength(url), dataHeight: avgMetadataContainerHeight});
                if(fileManager.gpsMetadataAvailable(url)) {
                    metadataModel.append({title: "GPS Data", value: fileManager.getGpsMetadata(url), dataHeight: 80 * scalingRatio});
                }
            }
        }
    }

    ListModel {
        id: metadataModel
    }

    onCurrentFileUrlChanged: {
        updateMetadata(currentFileUrl);
    }

    Rectangle {
        id: metadataRect
        color: "#2b292a"
        width: parent.width
        height: 408 * scalingRatio

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: metadataComponent

            onLoaded: metadataViewComponent.updateMetadata(metadataViewComponent.currentFileUrl);
        }

        Component {
            id: metadataComponent
            Item {
                ScrollView {
                    anchors.fill: parent
                    clip: true

                    ScrollBar.horizontal: ScrollBar { interactive: false }

                    ListView {
                        header: Rectangle {
                            height: 10 * metadataViewComponent.scalingRatio
                            width: metadataRect.width
                            color: "transparent"
                        }

                        footer: Rectangle {
                            height: 10 * metadataViewComponent.scalingRatio
                            width: metadataRect.width
                            color: "transparent"
                        }

                        width: parent.width
                        height: parent.height
                        spacing: 5
                        model: metadataModel
                        delegate: Rectangle {
                            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                            width: 370 * scalingRatio
                            height: dataHeight
                            color: "transparent"
                            radius: 10 * scalingRatio

                            Column {
                                anchors.fill: parent
                                spacing: 3 * metadataViewComponent.scalingRatio
                                Rectangle {
                                    width: 370 * metadataViewComponent.scalingRatio
                                    height: dataHeight
                                    color: "#3d3d3d"
                                    radius: (10 * metadataViewComponent.scalingRatio)
                                    Text {
                                        text: title
                                        color: "#8a8a8f"
                                        font.bold: true
                                        font.pixelSize: metadataViewComponent.textSize - 2
                                        style: Text.Raised
                                        styleColor: "black"
                                        elide: Text.ElideRight
                                        anchors {
                                            left: parent.left
                                            top: parent.top
                                            leftMargin: 10 * metadataViewComponent.scalingRatio
                                            topMargin: 10 * metadataViewComponent.scalingRatio
                                        }
                                    }

                                    Text {
                                        text: value
                                        color: "white"
                                        font.pixelSize: metadataViewComponent.textSize
                                        style: Text.Raised
                                        styleColor: "black"
                                        elide: Text.ElideRight
                                        anchors {
                                            left: parent.left
                                            bottom: parent.bottom
                                            leftMargin: 10 * metadataViewComponent.scalingRatio
                                            bottomMargin: 10 * metadataViewComponent.scalingRatio
                                        }
                                    }
                                }
                            }
                        }
                    }
                }   
            }
        }
    }
}