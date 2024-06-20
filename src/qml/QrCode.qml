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

    property var lastValidResult: null
    property var smoothedPosition: QtObject {
        property var topLeft: Qt.point(0, 0)
        property var topRight: Qt.point(0, 0)
        property var bottomLeft: Qt.point(0, 0)
        property var bottomRight: Qt.point(0, 0)
    }

    // TODO: this unit is in image-space, not screen-space
    property double padding: 64

    property double currentOpacity: 0

    function lowPassFilter(current, previous) {
        if (!previous || previous.x == 0) return current

        var alpha = Math.abs((current.x - previous.x) + (current.y - previous.y)) > 64 ? 0.4 : 0.05
        return Qt.point(alpha * current.x + (1 - alpha) * previous.x,
                        alpha * current.y + (1 - alpha) * previous.y)
    }

    function updateLowPass()
    {
        var points = ["topLeft", "topRight", "bottomLeft", "bottomRight"]

        for (var i = 0; i < points.length; i++) {
            smoothedPosition[points[i]] = lowPassFilter(lastValidResult.position[points[i]], smoothedPosition[points[i]])
        }
    }

    BarcodeReader {
        id: barcodeReader

        formats: ZXing.QRCode

        tryRotate: false
        tryHarder: false
        tryDownscale: true

        onNewResult: {
            if (result.isValid) {
                if (fadeOut.running || !lastValidResult) {
                    fadeOut.stop()
                    fadeIn.start()
                }

                if (!lastValidResult) {
                    smoothedPosition = {
                        topLeft: result.position.topLeft,
                        topRight: result.position.topRight,
                        bottomLeft: result.position.bottomLeft,
                        bottomRight: result.position.bottomRight
                    }

                }
                lastValidResult = result
            } else if (lastValidResult && !fadeOut.running) {
                fadeIn.stop()
                fadeOut.start()
            }
        }
    }

    function reducePoints(position, f) {
        var points = ["topLeft", "topRight", "bottomLeft", "bottomRight"]
        var val
        for (var i = 0; i < points.length; i++) {
            val = f(viewfinder.mapPointToItem(position[points[i]]), val)
        }
        return val
    }

    function calcButtonX() {
        if (!lastValidResult) return 0
        return reducePoints(lastValidResult.position, function(point, accum) { return accum ? Math.min(point.x, accum) : point.x })
    }

    function calcButtonY() {
        if (!lastValidResult) return 0
        return reducePoints(lastValidResult.position, function(point, accum) { return accum ? Math.min(point.y, accum) : point.y })
    }

    function calcButtonWidth() {
        if (!lastValidResult) return 0
        return reducePoints(lastValidResult.position, function(point, accum) { return accum ? Math.max(point.x, accum) : point.x }) - calcButtonX()
    }

    function calcButtonHeight() {
        if (!lastValidResult) return 0
        return reducePoints(lastValidResult.position, function(point, accum) { return accum ? Math.max(point.y, accum) : point.y }) - calcButtonY()
    }

    Button {
        id: qrOverlay
        visible: lastValidResult != null
        x: calcButtonX()
        y: calcButtonY()
        width: calcButtonWidth()
        height: calcButtonHeight()
        onClicked: {
            QRCodeHandler.openUrlInFirefox(lastValidResult.text)
        }

        background: Rectangle {
            color: "transparent"
            border.color: "transparent"
        }
    }

    function map(point, substractPadding)
    {
        if (!lastValidResult) return Qt.point(0, 0)

        point = smoothedPosition[point]
        return viewfinder.mapPointToItem(
            Qt.point(point.x + Math.floor(padding) * (substractPadding ? -1 : 1) * currentOpacity,
                     point.y + Math.floor(padding) * (substractPadding ? -1 : 1) * currentOpacity))
    }

    Shape {
        id: polygon
        visible: lastValidResult != null
        opacity: currentOpacity

        ShapePath {
            strokeWidth: 8
            strokeColor: "#3584e4"
            strokeStyle: ShapePath.SolidLine
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            startX: map("bottomLeft", false).x
            startY: map("bottomLeft", false).y
            PathLine {
                x: map("topLeft", false).x
                y: map("topLeft", true).y
            }
            PathLine {
                x: map("topRight", true).x
                y: map("topRight", true).y
            }
            PathLine {
                x: map("bottomRight", true).x
                y: map("bottomRight", false).y
            }
            PathLine {
                x: map("bottomLeft", false).x
                y: map("bottomLeft", false).y
            }
        }
    }

    SequentialAnimation {
        id: paddingAnimation
        running: true
        loops: Animation.Infinite

        NumberAnimation {
            target: barcodeReaderComponent
            property: "padding"
            from: 64
            to: 86
            duration: 800
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: barcodeReaderComponent
            property: "padding"
            from: 86
            to: 64
            duration: 800
            easing.type: Easing.InOutQuad
        }
    }

    Timer {
        id: updateLowPassTimer
        interval: 1000 / 120
        running: !!lastValidResult
        onTriggered: {
            if (!lastValidResult) return

            barcodeReaderComponent.updateLowPass()
            updateLowPassTimer.start()
        }
    }

    SequentialAnimation {
        id: fadeOut
        running: false
        PauseAnimation {
            duration: 500
        }
        NumberAnimation {
            target: barcodeReaderComponent
            property: "currentOpacity"
            to: 0
            duration: 1500
            easing.type: Easing.Bezier
            easing.bezierCurve: [
                0.4, 0,
                0.9, 0,
                1,   1
            ]
        }
        PropertyAction {
            target: barcodeReaderComponent
            property: "lastValidResult"
            value: null
        }
    }

    NumberAnimation {
        id: fadeIn
        running: false
        target: barcodeReaderComponent
        property: "currentOpacity"
        to: 1
        duration: 100
        easing.type: Easing.InOutQuad
    }
}
