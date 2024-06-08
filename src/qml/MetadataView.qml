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
    property int mediaIndex: mediaIndex

    Rectangle {
        id: metadataRect
        property var folder: ""
        property var currentFileUrl: ""
        color: "#AA000000"
        width: rectWidth
        height: rectHeight / 3 - 50

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: (!visibility ||  mediaIndex === -1) ? null : currentFileUrl.endsWith(".mkv") ? videoMetadata : drawerContent
        }

        Component {
            id: drawerContent
            Column {
                spacing: 10
                anchors.fill: parent
                anchors.margins: 10
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    color: "#171d2b"
                    width: parent.width - 40
                    height: 30
                    radius: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        text: fileManager.getCameraHardware(currentFileUrl)
                        anchors.fill: parent
                        anchors.margins: 5
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: "white"
                        font.family: "Arial"
                        font.bold: true
                        style: Text.Raised
                        styleColor: "black"
                        font.pixelSize: 16
                    }
                }

                Row {
                    spacing: 10
                    width: parent.width - 40
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        color: "#171d2b"
                        width: (parent.width) / 2 - 5
                        height: 30
                        radius: 10
                        Text {
                            text: fileManager.getDimensions(currentFileUrl)
                            anchors.centerIn: parent
                            color: "white"
                            font.family: "Arial"
                            font.pixelSize: 16
                        }
                    }
                    Rectangle {
                        color: "#171d2b"
                        width: (parent.width) / 2 - 5
                        height: 30
                        radius: 10
                        Text {
                            text: fileManager.getFStop(currentFileUrl) + "   " + fileManager.getExposure(currentFileUrl)
                            anchors.centerIn: parent
                            color: "white"
                            font.family: "Arial"
                            font.pixelSize: 16
                        }
                    }
                }

                Rectangle {
                    color: "#171d2b"
                    width: parent.width - 40
                    height: 30
                    radius: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        text: fileManager.getISOSpeed(currentFileUrl) + " | " +
                            fileManager.getExposureBias(currentFileUrl) + " | " +
                            fileManager.focalLength(currentFileUrl)
                        anchors.fill: parent
                        anchors.margins: 5
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: "white"
                        font.bold: true
                        font.family: "Arial"
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
                        text: fileManager.focalLengthStandard(currentFileUrl)
                        anchors.fill: parent
                        anchors.margins: 5
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: "white"
                        font.bold: true
                        font.family: "Arial"
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
                    visible: fileManager.gpsMetadataAvailable(currentFileUrl)
                    Text {
                        text: fileManager.getGpsMetadata(currentFileUrl)
                        anchors.fill: parent
                        anchors.margins: 5
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: "white"
                        font.bold: true
                        font.family: "Arial"
                        style: Text.Raised
                        styleColor: "black"
                        font.pixelSize: 16
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
                    color: "#171d2b"
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
                        font.family: "Arial"
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
                        font.family: "Arial"
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
                        font.family: "Arial"
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
                        font.family: "Arial"
                        style: Text.Raised
                        styleColor: "black"
                        font.pixelSize: 16
                    }
                }
            }
        }
    }
}