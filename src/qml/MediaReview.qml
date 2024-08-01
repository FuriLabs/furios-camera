// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2023 Droidian Project
//
// Authors:
// Bardia Moshiri <fakeshell@bardia.tech>
// Erik Inkinen <erik.inkinen@gmail.com>
// Alexander Rutz <alex@familyrutz.com>
// Joaquin Philco <joaquinphilco@gmail.com>

import QtQuick 2.15
import QtMultimedia 5.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import Qt.labs.folderlistmodel 2.15
import Qt.labs.platform 1.1

Rectangle {
    id: viewRect
    property int index: -1
    property var lastImg: index == -1 ? "" : imgModel.get(viewRect.index, "fileUrl")
    property string currentFileUrl: viewRect.index === -1 || imgModel.get(viewRect.index, "fileUrl") === undefined ? "" : imgModel.get(viewRect.index, "fileUrl").toString()
    property var folder: cslate.state == "VideoCapture" ?
                         StandardPaths.writableLocation(StandardPaths.MoviesLocation) + "/furios-camera" :
                         StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/furios-camera"
    property var deletePopUp: "closed"
    property bool hideMediaInfo: false
    property bool showShapes: true
    property real scalingRatio: scalingRatio
    property var scaleRatio: 1.0
    property var vCenterOffsetValue: 0
    property var textSize: viewRect.height * 0.018
    signal playButtonUpdate()
    signal playbackRequest()
    signal closed
    color: "black"
    visible: false

    Connections {
        target: thumbnailGenerator

        function onThumbnailGenerated(image) {
            viewRect.lastImg = thumbnailGenerator.toQmlImage(image);
        }
    }

    FolderListModel {
        id: imgModel
        folder: viewRect.folder
        showDirs: false
        nameFilters: cslate.state == "VideoCapture" ? ["*.mkv"] : ["*.jpg"]

        onStatusChanged: {
            if (imgModel.status == FolderListModel.Ready) {
                viewRect.index = imgModel.count - 1
                if (cslate.state == "VideoCapture" && viewRect.currentFileUrl.endsWith(".mkv")) {
                    thumbnailGenerator.setVideoSource(viewRect.currentFileUrl)
                } else {
                    viewRect.lastImg = viewRect.currentFileUrl
                }
            }
        }
    }

    Loader {
        id: mediaLoader
        anchors.fill: parent
        sourceComponent: viewRect.index === -1 ? emptyDirectoryComponent : imgModel.get(viewRect.index, "fileUrl") == undefined ? null :
                          imgModel.get(viewRect.index, "fileUrl").toString().endsWith(".mkv") ? videoOutputComponent : imageComponent
    }

    function swipeGesture(deltaX, deltaY, swipeThreshold) {
        if (Math.abs(deltaY) > Math.abs(deltaX)) {
            if (deltaY < -swipeThreshold) { // Upward swipe
                viewRect.scaleRatio = 0.7
                viewRect.vCenterOffsetValue = -(viewRect.height * 0.19)
                drawerAnimation.to = parent.height - 70 - metadataDrawer.height
                drawerAnimation.start()
            } else if (deltaY > swipeThreshold) { // Downward swipe
                viewRect.scaleRatio = 1.0
                viewRect.vCenterOffsetValue = 0
                drawerAnimation.to = parent.height
                drawerAnimation.start()
            }
            viewRect.hideMediaInfo = false
        } else if (Math.abs(deltaX) > swipeThreshold) {
            playButtonUpdate()
            if (deltaX > 0) { // Swipe right
                if (viewRect.index > 0) {
                    viewRect.index -= 1
                }
            } else { // Swipe left
                if (viewRect.index < imgModel.count - 1) {
                    viewRect.index += 1
                }
            }
            viewRect.hideMediaInfo = false
        } else { // Touch
            if (viewRect.hideMediaInfo === false) {
                viewRect.scaleRatio = 1.0
                viewRect.vCenterOffsetValue = 0
            } else {
                if (metadataDrawer.y <= 600) {
                    viewRect.scaleRatio = 0.5
                    viewRect.vCenterOffsetValue = -(viewRect.height * 0.19)
                }
            }

            viewRect.hideMediaInfo = !viewRect.hideMediaInfo

            if (viewRect.currentFileUrl.endsWith(".mkv")) {
                playbackRequest()
            }
        }
    }

    Component {
        id: emptyDirectoryComponent

        Item {
            id: emptyDirectoryItem
            anchors.fill: parent

            Column {
                anchors.centerIn: parent

                Button {
                    implicitWidth: 200 * viewRect.scalingRatio
                    implicitHeight: 200 * viewRect.scalingRatio

                    icon.name: "emblem-photos-symbolic"
                    icon.width: Math.round(200 * viewRect.scalingRatio)
                    icon.height: Math.round(200 * viewRect.scalingRatio)
                    icon.color: "#8a8a8f"

                    anchors.horizontalCenter: parent.horizontalCenter

                    background: Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                    }
                }

                Text {
                    text: "No media found"
                    color: "#8a8a8f"
                    font.bold: true
                    font.pixelSize: textSize * 2
                    style: Text.Raised
                    elide: Text.ElideRight
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Component {
        id: imageComponent
        Item {
            id: imageContainer
            anchors.fill: parent

            Image {
                id: image
                width: viewRect.width
                autoTransform: true
                transformOrigin: Item.Center
                scale: viewRect.scaleRatio
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: (viewRect.currentFileUrl && !viewRect.currentFileUrl.endsWith(".mkv")) ? viewRect.currentFileUrl : ""

                y: parent.height / 2 - height / 2 + viewRect.vCenterOffsetValue

                Behavior on scale {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }
                Behavior on y {
                    NumberAnimation{
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            PinchArea {
                id: pinchArea
                anchors.fill: parent
                pinch.target: image
                pinch.maximumScale: 4
                pinch.minimumScale: 1
                enabled: viewRect.visible
                property real initialX: 0
                property real initialY: 0

                onPinchUpdated: {
                    if (pinchArea.pinch.center !== undefined) {
                        image.scale = pinchArea.pinch.scale
                    }
                }

                MouseArea {
                    id: galleryDragArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: deletePopUp === "closed"
                    property real startX: 0
                    property real startY: 0
                    property int swipeThreshold: 30

                    onPressed: {
                        startX = mouse.x
                        startY = mouse.y
                    }

                    onReleased: {
                        var deltaX = mouse.x - startX
                        var deltaY = mouse.y - startY

                        swipeGesture(deltaX, deltaY, swipeThreshold)
                    }
                }
            }
        }
    }

    MetadataView {
        id: metadataDrawer
        width: parent.width
        height: parent.height / 2.7
        y: parent.height
        visible: !viewRect.hideMediaInfo

        PropertyAnimation {
            id: drawerAnimation
            target: metadataDrawer
            property: "y"
            duration: 500
            easing.type: Easing.InOutQuad
        }

        currentFileUrl: viewRect.currentFileUrl
        textSize: viewRect.textSize
        scalingRatio: viewRect.scalingRatio
    }

    Component {
        id: videoOutputComponent

        Item {
            id: videoItem
            anchors.fill: parent
            property bool firstFramePlayed: false

            signal playbackStateChange()

            Connections {
                target: viewRect
                function onPlaybackRequest() {
                    playbackStateChangeHandler()
                }

                function onPlayButtonUpdate() {
                    playButtonUpdateHandler()
                }
            }

            MediaPlayer {
                id: mediaPlayer
                autoPlay: true
                muted: true
                source: viewRect.visible ? viewRect.currentFileUrl : ""

                onSourceChanged: {
                    firstFramePlayed = false;
                    muted = true;
                    play();
                }

                onPositionChanged: {
                    if (position > 0 && !firstFramePlayed) {
                        pause();
                        firstFramePlayed = true;
                    }
                }
            }

            VideoOutput {
                anchors.fill: parent
                source: mediaPlayer
                visible: viewRect.currentFileUrl && viewRect.currentFileUrl.endsWith(".mkv")
            }

            function playbackStateChangeHandler() {
                if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                    showShapes = true;
                    canvas.requestPaint();
                    mediaPlayer.pause();
                } else {
                    if (firstFramePlayed) {
                        mediaPlayer.muted = false;
                    }
                    if (viewRect.visible == true) {
                        showShapes = false;
                        canvas.requestPaint();
                        mediaPlayer.play();
                    }
                }
            }

            function playButtonUpdateHandler() {
                showShapes = true;
                canvas.requestPaint();
            }

            MouseArea {
                id: galleryDragArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: deletePopUp === "closed"
                property real startX: 0
                property real startY: 0
                property int swipeThreshold: 30

                onPressed: {
                    startX = mouse.x
                    startY = mouse.y
                }

                onReleased: {
                    var deltaX = mouse.x - startX
                    var deltaY = mouse.y - startY

                    swipeGesture(deltaX, deltaY, swipeThreshold)
                }
            }

            Rectangle {
                id: playButton
                anchors.fill: parent
                color: "transparent"

                Canvas {
                    id: canvas
                    anchors.fill: parent

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        if (viewRect.showShapes) {
                            var centerX = width / 2;
                            var centerY = height / 2;
                            var radius = 40;

                            ctx.beginPath();
                            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                            ctx.fillStyle = "white";
                            ctx.fill();

                            var triangleHeight = 30;
                            var triangleWidth = Math.sqrt(3) / 2 * triangleHeight;

                            ctx.beginPath();
                            ctx.lineJoin = "round";
                            ctx.moveTo(centerX + triangleWidth - 5, centerY);
                            ctx.lineTo(centerX - triangleWidth / 2 - 5 , centerY - triangleHeight / 2);
                            ctx.lineTo(centerX - triangleWidth / 2 - 5, centerY + triangleHeight / 2);
                            ctx.closePath();

                            ctx.fillStyle = "#808080";
                            ctx.fill();
                        }
                    }
                }
            }
        }
    }

    Button {
        id: btnPrev
        implicitWidth: 60 * viewRect.scalingRatio
        implicitHeight: 60 * viewRect.scalingRatio
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        icon.name: "go-previous-symbolic"
        icon.width: Math.round(btnPrev.width * 0.5)
        icon.height: Math.round(btnPrev.height * 0.5)
        icon.color: "white"
        Layout.alignment : Qt.AlignHCenter

        visible: viewRect.index > 0 && !viewRect.hideMediaInfo
        enabled: deletePopUp === "closed"

        background: Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        onClicked: {
            if ((viewRect.index - 1) >= 0 ) {
                viewRect.index = viewRect.index - 1
            }
        }
    }

    Button {
        id: btnNext
        implicitWidth: 60 * viewRect.scalingRatio
        implicitHeight: 60 * viewRect.scalingRatio
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        icon.name: "go-next-symbolic"
        icon.width: Math.round(btnNext.width * 0.5)
        icon.height: Math.round(btnNext.height * 0.5)
        icon.color: "white"
        Layout.alignment : Qt.AlignHCenter

        visible: viewRect.index < (imgModel.count - 1) && !viewRect.hideMediaInfo
        enabled: deletePopUp === "closed"

        background: Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        onClicked: {
            if ((viewRect.index + 1) <= (imgModel.count - 1)) {
                viewRect.index = viewRect.index + 1
            }
        }
    }

    Item {
        id: mediaMenu

        anchors.bottom: parent.bottom
        width: parent.width
        height: 70 * viewRect.scalingRatio

        Rectangle {
            anchors.fill: parent
            color: "#2b292a"
        }

        Button {
            id: btnClose
            icon.name: "camera-video-symbolic"
            icon.width: parent.width * 0.15
            icon.height: parent.height * 0.8
            icon.color: "white"
            enabled: deletePopUp === "closed" && viewRect.visible
            anchors.left: parent.left
            anchors.leftMargin: 20 * viewRect.scalingRatio
            anchors.verticalCenter: parent.verticalCenter

            visible: !viewRect.hideMediaInfo

            background: Rectangle {
                anchors.fill: parent
                color: "transparent"
            }

            onClicked: {
                viewRect.visible = false
                playbackRequest();
                viewRect.index = imgModel.count - 1
                viewRect.closed();
            }
        }

        Button {
            id: btnDelete
            anchors.right: parent.right
            anchors.rightMargin: 20 * viewRect.scalingRatio
            anchors.verticalCenter: parent.verticalCenter
            icon.name: "edit-delete-symbolic"
            icon.width: parent.width * 0.1
            icon.height: parent.width * 0.1
            icon.color: "white"
            visible: viewRect.index >= 0 && !viewRect.hideMediaInfo
            Layout.alignment: Qt.AlignHCenter

            background: Rectangle {
                anchors.fill: parent
                color: "transparent"
            }

            onClicked: {
                deletePopUp = "opened"
                confirmationPopup.open()
            }
        }

        Popup {
            id: confirmationPopup
            width: 200 * viewRect.scalingRatio
            height: 80 * viewRect.scalingRatio

            background: Rectangle {
                border.color: "#444"
                color: "#2b292a"
                radius: 10 * viewRect.scalingRatio
            }

            closePolicy: Popup.NoAutoClose
            x: (parent.width - width) / 2
            y: (parent.height - height)

            Column {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: viewRect.currentFileUrl.endsWith(".mkv") ? "  Delete Video?": "  Delete Photo?"
                    horizontalAlignment: parent.AlignHCenter

                    anchors.margins: 5 * viewRect.scalingRatio
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    color: "white"
                    font.bold: true
                    style: Text.Raised
                    styleColor: "black"
                    font.pixelSize: textSize
                }

                Row {
                    spacing: 20 * viewRect.scalingRatio

                    Button {
                        text: "Yes"
                        palette.buttonText: "white"
                        font.pixelSize: viewRect.textSize
                        width: 60 * viewRect.scalingRatio
                        height: confirmationPopup.height * 0.6
                        onClicked: {
                            var tempCurrUrl = viewRect.currentFileUrl
                            fileManager.deleteImage(tempCurrUrl)
                            viewRect.index = imgModel.count
                            deletePopUp = "closed"
                            confirmationPopup.close()
                        }

                        background: Rectangle {
                            anchors.fill: parent
                            color: "#3d3d3d"
                            radius: 10 * viewRect.scalingRatio
                        }
                    }

                    Button {
                        text: "No"
                        palette.buttonText: "white"
                        font.pixelSize: viewRect.textSize
                        width: 60 * viewRect.scalingRatio
                        height: confirmationPopup.height * 0.6
                        onClicked: {
                            deletePopUp = "closed"
                            confirmationPopup.close()
                        }

                        background: Rectangle {
                            anchors.fill: parent
                            color: "#3d3d3d"
                            radius: 10 * viewRect.scalingRatio
                        }
                    }
                }
            }
        }

        Rectangle {
            id: mediaIndexView
            anchors.centerIn: parent
            width: parent.width * 0.2
            height: parent.height
            color: "transparent"
            visible: viewRect.index >= 0 && !viewRect.hideMediaInfo
            Text {
                text: (viewRect.index + 1) + " / " + imgModel.count

                anchors.fill: parent
                anchors.margins: 5
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                color: "white"
                font.bold: true
                style: Text.Raised
                styleColor: "black"
                font.pixelSize: textSize
            }
        }
    }

    Rectangle {
        id: mediaDate
        anchors.top: parent.top
        width: parent.width
        height: 60 * viewRect.scalingRatio
        color: "#2b292a"
        visible: viewRect.index >= 0 && !viewRect.hideMediaInfo

        Text {
            id: date
            text: {
                if (!viewRect.visible || viewRect.index === -1) {
                    return "None"
                } else {
                    if (viewRect.currentFileUrl.endsWith(".mkv")) {
                        return fileManager.getVideoDate(viewRect.currentFileUrl)
                    } else {
                        return fileManager.getPictureDate(viewRect.currentFileUrl)
                    }
                }
            }

            anchors.fill: parent
            anchors.margins: 5
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: "white"
            font.bold: true
            style: Text.Raised 
            styleColor: "black"
            font.pixelSize: viewRect.textSize
        }
    }
}
