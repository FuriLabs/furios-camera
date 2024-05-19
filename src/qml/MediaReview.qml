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
                         StandardPaths.writableLocation(StandardPaths.MoviesLocation) + "/droidian-camera" :
                         StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/droidian-camera"
    property var deletePopUp: "closed"
    property bool hideMediaInfo: false
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
        sourceComponent: viewRect.index == -1 ? null :
                         imgModel.get(viewRect.index, "fileUrl").toString().endsWith(".mkv") ? videoOutputComponent : imageComponent
    }

    function swipeGesture(deltaX, deltaY, swipeThreshold) {
        if (Math.abs(deltaY) > Math.abs(deltaX)) {
            if (deltaY < -swipeThreshold) { // Upward swipe
                drawerAnimation.to = parent.height - 70 - drawer.height
                drawerAnimation.start()
            } else if (deltaY > swipeThreshold) { // Downward swipe
                drawerAnimation.to = parent.height
                drawerAnimation.start()
            }
            viewRect.hideMediaInfo = false
        } else if (Math.abs(deltaX) > swipeThreshold) {
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
            viewRect.hideMediaInfo = !viewRect.hideMediaInfo

            if (viewRect.currentFileUrl.endsWith(".mkv")) {
                playbackRequest()
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
                anchors.fill: parent
                autoTransform: true
                transformOrigin: Item.Center
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: (viewRect.currentFileUrl && !viewRect.currentFileUrl.endsWith(".mkv")) ? viewRect.currentFileUrl : ""
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
                    mediaPlayer.pause();
                } else {
                    if (firstFramePlayed) {
                        mediaPlayer.muted = false;
                    }
                    if (viewRect.visible == true) {
                        mediaPlayer.play();
                    }
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

    Button {
        id: btnPrev
        implicitWidth: 60
        implicitHeight: 60
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
        implicitWidth: 60
        implicitHeight: 60
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

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 70
        color: "#AA000000"
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
            font.pixelSize: 16
        }
    }

    RowLayout {
        width: parent.width
        height: 70
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 5

        Button {
            id: btnClose
            implicitWidth: 70
            implicitHeight: 70
            icon.name: "camera-video-symbolic"
            icon.width: Math.round(btnClose.width * 0.7)
            icon.height: Math.round(btnClose.height * 0.7)
            icon.color: "white"
            enabled: deletePopUp === "closed" && viewRect.visible
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
    }

    Button {
        id: btnDelete
        implicitWidth: 70
        implicitHeight: 70
        anchors.bottom: parent.bottom
        anchors.right: parent.right 
        anchors.rightMargin: 5
        icon.name: "edit-delete-symbolic"
        icon.width: Math.round(btnDelete.width * 0.5)
        icon.height: Math.round(btnDelete.height * 0.5)
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
        width: 200
        height: 80
        background: Rectangle {
            border.color: "#444"
            color: "lightgrey"
            radius: 10
        }
        closePolicy: Popup.NoAutoClose
        x: (parent.width - width) / 2
        y: (parent.height - height)

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: viewRect.currentFileUrl.endsWith(".mkv") ? "  Delete Video": "  Delete Photo?"
                horizontalAlignment: parent.AlignHCenter
            }

            Row {
                spacing: 20
                Button {
                    text: "Yes"
                    width: 60
                    onClicked: {
                        if(fileManager.deleteImage(viewRect.currentFileUrl)){
                            viewRect.index = viewRect.index - 1
                        }
                        deletePopUp = "closed"
                        confirmationPopup.close()
                    }
                }
                Button {
                    text: "No"
                    width: 60
                    onClicked: {
                        deletePopUp = "closed"
                        confirmationPopup.close()
                    }
                }
            }
        }
    }

    Rectangle {
        id: pictureMetaData
        anchors.top: parent.top
        width: parent.width
        height: 60
        color: "#AA000000"
        visible: viewRect.index >= 0 && !viewRect.hideMediaInfo

        Text {
            id: date
            text: {
                if (!viewRect.visible) {
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
            font.family: "Arial"
            font.bold: true
            style: Text.Raised 
            styleColor: "black"
            font.pixelSize: 16
        }
    }

    MetadataView {
        id: drawer
        width: parent.width
        height: parent.height/ 3 - 50
        y: !viewRect.visible ? parent.height : parent.height
        visible: !viewRect.hideMediaInfo

        PropertyAnimation {
            id: drawerAnimation
            target: drawer
            property: "y"
            duration: 500
            easing.type: Easing.InOutQuad
        }

        folder: viewRect.folder
        currentFileUrl: viewRect.currentFileUrl
        visibility: viewRect.visible && !viewRect.hideMediaInfo
        rectHeight: parent.height
        rectWidth: parent.width
    }
}