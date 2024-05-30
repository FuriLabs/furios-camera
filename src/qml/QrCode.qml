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
    property Item viewfinder

    property var nullPoints: [Qt.point(0,0), Qt.point(0,0), Qt.point(0,0), Qt.point(0,0)]
    property var points: nullPoints
    property string buttonText: ""

    property bool newURLDetected: barcodeReaderComponent.newURLDetected
    property string urlResult: barcodeReaderComponent.buttonText

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
}
