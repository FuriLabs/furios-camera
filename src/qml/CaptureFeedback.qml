// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 Furi Labs
//
// Authors:
// Joaquin Philco <joaquinphilco@gmail.com>

import QtQuick 2.15
import QtGraphicalEffects 1.0

Item {
    id: captureFeedback

    // Inputs
    property Item source: null
    property Item gallery_thumbnail: null
    property real unit: 1
    property int flyDuration: 320

    // Functions
    function start() {
        if (!source || !gallery_thumbnail || !source.visible) {
            return
        }

        var success = source.grabToImage(onImageGrabbed)

        if (!success) {
            console.warn("CaptureFeedback: grabToImage failed")
        }
    }

    function onImageGrabbed(result) {
        flyer.source = result.url
        fly()
    }

    function stop() {
        flyAnimation.stop()
        flyerFrame.opacity = 0
        flyer.source = ""
    }

    function fly() {
        var s = source.mapToItem(captureFeedback, 0, 0)
        var t = gallery_thumbnail.mapToItem(captureFeedback, 0, 0)

        flyerFrame.x = s.x
        flyerFrame.y = s.y
        flyerFrame.width = source.width
        flyerFrame.height = source.height
        flyerFrame.radius = 0
        flyerFrame.opacity = 1

        toX.to = t.x
        toY.to = t.y
        toW.to = gallery_thumbnail.width
        toH.to = gallery_thumbnail.height
        toR.to = Math.min(gallery_thumbnail.width, gallery_thumbnail.height) / 2

        flyAnimation.restart()
    }

    // Flying snapshot
    Rectangle {
        id: flyerFrame
        opacity: 0
        visible: opacity > 0
        color: "black"
        border.width: 2 * captureFeedback.unit
        border.color: "white"

        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: flyerFrame.width
                height: flyerFrame.height
                radius: flyerFrame.radius
            }
        }

        Image {
            id: flyer
            anchors.fill: parent
            anchors.margins: parent.border.width
            fillMode: Image.PreserveAspectCrop
            cache: false
            smooth: true
        }
    }

    // Animation
    SequentialAnimation {
        id: flyAnimation

        ParallelAnimation {
            NumberAnimation { id: toX; target: flyerFrame; property: "x"; duration: captureFeedback.flyDuration; easing.type: Easing.InOutCubic }
            NumberAnimation { id: toY; target: flyerFrame; property: "y"; duration: captureFeedback.flyDuration; easing.type: Easing.InOutCubic }
            NumberAnimation { id: toW; target: flyerFrame; property: "width"; duration: captureFeedback.flyDuration; easing.type: Easing.InOutCubic }
            NumberAnimation { id: toH; target: flyerFrame; property: "height"; duration: captureFeedback.flyDuration; easing.type: Easing.InOutCubic }
            NumberAnimation { id: toR; target: flyerFrame; property: "radius"; duration: captureFeedback.flyDuration; easing.type: Easing.InOutCubic }
        }

        NumberAnimation { target: flyerFrame; property: "opacity"; to: 0; duration: 150 }
        ScriptAction { script: flyer.source = "" }
    }
}
