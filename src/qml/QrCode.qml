// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2024 Droidian Project
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

import ZXing 1.0
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.0
import QtMultimedia 5.15
import QtQuick.Shapes 1.12
import QtQuick.Layouts 1.15


Item {
    id: barcodeReaderComponent

    property alias qrcode : barcodeReader
    property int bottomFrameTop: 0
    property int bottomFrameX: 0 
    property Item viewfinder

    property var nullPoints: [Qt.point(0,0), Qt.point(0,0), Qt.point(0,0), Qt.point(0,0)]
    property var points: nullPoints
    property string buttonText: ""
    property bool newURLDetected: false

    BarcodeReader {
        id: barcodeReader

        formats: ZXing.None

        tryRotate: false
        tryHarder: false
        tryDownscale: true

        onNewResult: {
            points = result.isValid
                    ? [result.position.topLeft, result.position.topRight, result.position.bottomRight, result.position.bottomLeft]
                    : nullPoints

            if (result.isValid) {
                resetInfo.restart()
                barcodeReaderComponent.newURLDetected = true
            }

            if (result.isValid || !resetInfo.running) {
                barcodeReaderComponent.buttonText = result.text
            }
        }
    }

    Shape {
        id: polygon
        visible: points.length == 4 && cslate.state === "QRC"
        ShapePath {
            strokeWidth: 3
            strokeColor: "red"
            strokeStyle: ShapePath.SolidLine
            fillColor: "transparent"
            startX: viewfinder.mapPointToItem(points[3]).x
            startY: viewfinder.mapPointToItem(points[3]).y
            PathLine {
                x: viewfinder.mapPointToItem(points[0]).x
                y: viewfinder.mapPointToItem(points[0]).y
            }
            PathLine {
                x: viewfinder.mapPointToItem(points[1]).x
                y: viewfinder.mapPointToItem(points[1]).y
            }
            PathLine {
                x: viewfinder.mapPointToItem(points[2]).x
                y: viewfinder.mapPointToItem(points[2]).y
            }
            PathLine {
                x: viewfinder.mapPointToItem(points[3]).x
                y: viewfinder.mapPointToItem(points[3]).y
            }
        }
    }

    Timer {
        id: resetInfo
        interval: 1000

        onTriggered: barcodeReaderComponent.newURLDetected = false
    }

    Button {
        id: readerResultButton

        text: barcodeReaderComponent.buttonText
        visible: cslate.state === "QRC" && barcodeReaderComponent.newURLDetected

        anchors.bottom:  parent.bottom
        anchors.bottomMargin: (-bottomFrameTop + 20)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 180

        onClicked: QRCodeHandler.openUrlInFirefox(barcodeReaderComponent.buttonText)
    }

    Rectangle {
        id: qrcBtnFrame
        height: 90
        width: 90
        radius: 70
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (-bottomFrameTop - 110)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 180
        visible: cslate.state == "QRC"

        Button {
            id: qrcButton
            anchors.fill: qrcBtnFrame
            anchors.centerIn: parent
            enabled: cslate.state == "QRC"

            icon.name: barcodeReaderComponent.newURLDetected ? "qrc" : ""

            icon.source: barcodeReaderComponent.newURLDetected ? "icons/qrc.svg" : ""

            palette.buttonText: "black"

            icon.width: qrcBtnFrame.width
            icon.height: qrcBtnFrame.height

            font.pixelSize: 64
            font.bold: true

            background: Rectangle {
                anchors.centerIn: parent
                width: qrcBtnFrame.width
                height: qrcBtnFrame.height
                color: "white"
                radius: qrcBtnFrame.radius
            }

            onClicked: {
                QRCodeHandler.openUrlInFirefox(barcodeReaderComponent.buttonText)
            }
        }
    }
}
