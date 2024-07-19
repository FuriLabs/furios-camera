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
    property var folder: folder
    property string currentFileUrl: currentFileUrl
    property bool visibility: visibility
    property var rectWidth: rectWidth
    property var rectHeight: rectHeight
    property var numberBarHeight: numberBarHeight
    property int mediaIndex: mediaIndex
    property var scalingRatio: scalingRatio
    property var textSize: textSize

    Rectangle {
        id: metadataRect
        property var folder: ""
        property var currentFileUrl: ""
        color: "#2b292a"
        width: rectWidth
        height: 327 * metadataViewComponent.scalingRatio

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: (!visibility ||  mediaIndex === -1) ? null : currentFileUrl.endsWith(".mkv") ? videoMetadata : drawerContent
        }

        Component {
            id: drawerContent

            Item {

                ScrollView {
                    anchors.topMargin: 10
                    width: metadataRect.width
                    height: metadataRect.height
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
                        model: ListModel {
                            id: metadataModel
                        }
                        delegate: Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 370 * metadataViewComponent.scalingRatio
                            height: 60 * metadataViewComponent.scalingRatio
                            color: "transparent"
                            radius: (10 * metadataViewComponent.scalingRatio)

                            Column {
                                anchors.fill: parent
                                spacing: 3 * metadataViewComponent.scalingRatio
                                Rectangle {
                                    width: 370 * metadataViewComponent.scalingRatio
                                    height: 60 * metadataViewComponent.scalingRatio
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

                        Component.onCompleted: {
                            updateMetadata();
                        }

                        function updateMetadata() {
                            metadataModel.clear();
                            metadataModel.append({title: "Maker, Model", value: fileManager.getCameraHardware(currentFileUrl)});
                            metadataModel.append({title: "Image Size", value: fileManager.getDimensions(currentFileUrl)});
                            metadataModel.append({title: "Aperture", value: fileManager.getFStop(currentFileUrl)});
                            metadataModel.append({title: "Exposure", value: fileManager.getExposure(currentFileUrl)});
                            metadataModel.append({title: "ISO", value: fileManager.getISOSpeed(currentFileUrl)});
                            metadataModel.append({title: "Focal Length", value: fileManager.focalLength(currentFileUrl)});
                        }
                    }
                }
            }
        }

        Component {
            id: videoMetadata
            Column {
                spacing: 10
                anchors.fill: parent
                anchors.margins: 10
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    color: "#565656"
                    width: parent.width - 40
                    height: 30
                    radius: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        text: fileManager.getMultiplexingApplication(currentFileUrl)
                        anchors.fill: parent
                        anchors.margins: 5
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: "white"
                        font.bold: true
                        style: Text.Raised
                        styleColor: "black"
                        font.pixelSize: 15
                    }
                }

                Rectangle {
                    color: "#171d2b"
                    width: parent.width - 40
                    height: 30
                    radius: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        text: fileManager.getVideoDimensions(currentFileUrl)
                        anchors.fill: parent
                        anchors.margins: 5
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: "white"
                        font.bold: true
                        style: Text.Raised
                        styleColor: "black"
                        font.pixelSize: 16
                    }
                }
                Rectangle {
                    color: "#171d2b"
                    width: parent.width - 40
                    height: 30
                    radius: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        text: fileManager.getCodecId(currentFileUrl)
                        anchors.fill: parent
                        anchors.margins: 5
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: "white"
                        font.bold: true
                        style: Text.Raised
                        styleColor: "black"
                        font.pixelSize: 16
                    }
                }

                Rectangle {
                    color: "#171d2b"
                    width: parent.width - 40
                    height: 30
                    radius: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        text: fileManager.getDocumentType(currentFileUrl)
                        anchors.fill: parent
                        anchors.margins: 5
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: "white"
                        font.bold: true
                        style: Text.Raised
                        styleColor: "black"
                        font.pixelSize: 16
                    }
                }
            }
        }
    }
}
