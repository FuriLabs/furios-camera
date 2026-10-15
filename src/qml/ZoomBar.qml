// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Furi Labs
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: zoomBar

    // Inputs
    property var camera: null
    property real unit: 1
    property var presets: []

    // Variables
    property real zoom: 1.0
    property var ratios: [1.0]
    property int zoomIndex: 0
    property real maxZoomRatio: 4 // This was meassured on the FLX1s
    readonly property real appliedZoom: ratios[Math.max(0, Math.min(zoomIndex, ratios.length - 1))]
    readonly property real maxZoom: ratios[ratios.length - 1]
    readonly property var visiblePresets: {
        var list = presets.length > 0 ? presets.slice() : autoPresets(maxZoom)
        return list.filter(function (p) { return p <= maxZoom + 0.01 })
    }
    readonly property bool available: visiblePresets.length > 1

    property real _pinchStart: 1.0

    // Functions
    function setZoom(z) {
        anim.stop()
        zoom = clamp(z)
    }

    function animateZoom(z) {
        anim.to = clamp(z)
        anim.restart()
    }

    function beginPinch() {
        _pinchStart = zoom
    }

    function updatePinch(scale) {
        setZoom(_pinchStart * scale)
    }

    function reset() {
        anim.stop()
        zoom = 1.0
        zoomIndex = 0
        if (camera) {
            camera.setDigitalZoom(0)
        }
    }

    function formatZoom(z) {
        if (z >= 10) {
            return Math.round(z) + "×"
        }

        var r = Math.round(z * 10) / 10
        
        if (r % 1 === 0){
            return ((r.toFixed(0)) + "x")
        } else {
            return ((r.toFixed(1)) + "x")
        }
    }

    // ratios[i] = zoom ratio of HAL index i (0..maximumDigitalZoom).
    function rebuild() {
        if (!camera) {
            ratios = [1.0]
            zoomIndex = 0
            zoom = 1.0
            return
        }

        var maxIndex = Math.max(0, Math.round(camera.maximumDigitalZoom))
        var table = []

        for (var i = 0; i <= maxIndex; i++) {
            if (maxIndex > 0) {
                table.push(Math.pow(maxZoomRatio, i / maxIndex))
            } else {
                table.push(1.0)
            }
        }

        ratios = table
        reset()
    }

    onMaxZoomRatioChanged: rebuild()

    function clamp(z) {
        return Math.max(1, Math.min(maxZoom, z))
    }

    function autoPresets(max) {
        var out = [1]
        if (max <= 5.01) {
            for (var i = 2; i <= Math.floor(max + 0.01); i++) out.push(i)
        } else {
            [2, 5, 10, 20, 50].forEach(function (p) { if (p <= max + 0.01) out.push(p) })
        }
        return out
    }

    function nearestIndex(r) {
        var best = 0
        for (var i = 1; i < ratios.length; i++) {
            if (Math.abs(ratios[i] - r) < Math.abs(ratios[best] - r)) best = i
        }
        return best
    }

    // Only talk to the HAL when the index changes
    onZoomChanged: {
        var idx = nearestIndex(zoom)
        if (idx !== zoomIndex && camera) {
            zoomIndex = idx
            camera.setDigitalZoom(idx)
        }
    }

    onCameraChanged: rebuild()
    Component.onCompleted: rebuild()

    Connections {
        target: zoomBar.camera
        ignoreUnknownSignals: true
        function onMaximumDigitalZoomChanged() { zoomBar.rebuild() }
        function onDeviceIdChanged() { zoomBar.rebuild() }
    }

    NumberAnimation {
        id: anim
        target: zoomBar
        property: "zoom"
        duration: 250
        easing.type: Easing.OutCubic
    }

    // UI
    readonly property real chipSize: 52 * unit

    implicitWidth: pill.width
    implicitHeight: pill.height
    visible: available

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: row.implicitWidth + 10 * zoomBar.unit
        height: zoomBar.chipSize + 10 * zoomBar.unit
        radius: height / 2
        color: "#4d000000"

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6 * zoomBar.unit

            Repeater {
                model: zoomBar.visiblePresets

                AbstractButton {
                    id: chip

                    readonly property real nextPreset: index + 1 < zoomBar.visiblePresets.length ? zoomBar.visiblePresets[index + 1] : Infinity
                    readonly property bool active: zoomBar.appliedZoom >= modelData - 0.05 && zoomBar.appliedZoom < nextPreset - 0.05

                    width: zoomBar.chipSize
                    height: zoomBar.chipSize
                    scale: active ? 1 : 0.78

                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    background: Rectangle {
                        radius: width / 2
                        color: chip.down ? "#80000000" : "#59000000"
                    }

                    contentItem: Text {
                        text: chip.active ? zoomBar.formatZoom(zoomBar.appliedZoom) : modelData
                        color: chip.active ? "#f6d32d" : "white"
                        font.pixelSize: 18 * zoomBar.unit
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: zoomBar.animateZoom(modelData)
                }
            }
        }
    }
}
