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


Item{
    id: barcodeReaderComponent

    property alias qrcode : barcodeReader
    property Item viewfinder

    property var nullPoints: [Qt.point(0,0), Qt.point(0,0), Qt.point(0,0), Qt.point(0,0)]
    property var points: nullPoints

    BarcodeReader {
        id: barcodeReader

        formats: (linearSwitch.checked ? (ZXing.LinearCodes) : ZXing.None) | (matrixSwitch.checked ? (ZXing.MatrixCodes) : ZXing.None)
        tryRotate: tryRotateSwitch.checked
        tryHarder: tryHarderSwitch.checked
        tryDownscale: tryDownscaleSwitch.checked

        // callback with parameter 'result', called for every successfully processed frame
        // onFoundBarcode: {}

        // callback with parameter 'result', called for every processed frame
        onNewResult: {
            points = result.isValid
                    ? [result.position.topLeft, result.position.topRight, result.position.bottomRight, result.position.bottomLeft]
                    : nullPoints

            if (result.isValid)
                resetInfo.restart()

            if (result.isValid || !resetInfo.running)
                info.text = qsTr("Format: \t %1 \nText: \t %2 \nError: \t %3 \nTime: \t %4 ms").arg(result.formatName).arg(result.text).arg(result.status).arg(result.runTime)
        }
    }



    Shape {
        id: polygon
        anchors.fill: viewfinder
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

    Label {
        id: info
        color: "white"
        visible: cslate.state === "QRC"
        padding: 10
        background: Rectangle { color: "#80808080" }
    }

    Timer {
        id: resetInfo
        interval: 2000
    }
}




