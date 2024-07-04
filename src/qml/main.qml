// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2023 Droidian Project
//
// Authors:
// Bardia Moshiri <fakeshell@bardia.tech>
// Erik Inkinen <erik.inkinen@gmail.com>
// Alexander Rutz <alex@familyrutz.com>
// Joaquin Philco <joaquinphilco@gmail.com>

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.12
import QtGraphicalEffects 1.0
import QtMultimedia 5.15
import QtQuick.Layouts 1.15
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
import ZXing 1.0

ApplicationWindow {
    id: window
    width: 400
    height: 800
    visible: true
    title: "Camera"

    Screen.orientationUpdateMask: Qt.PortraitOrientation

    property alias cam: camGst
    property bool videoCaptured: false

    property var countDown: 0
    property var blurView: drawer.position == 0.0 && optionContainer.state == "closed" && tmDrawer.position == 0.0 ? 0 : 1
    property var useFlash: 0
    property var frontCameras: 0
    property var backCameras: 0
    property var swipeDirection: 0 // 0 = swiped left, 1 = swiped right, 2 = clicked
    property var next_state_left: "Empty"
    property var next_state_right: "VideoCapture"
    property var popupState: "closed"
    property var popupTitle: null
    property var popupBody: null
    property var popupData: null
    property var popupButtons: null

    property var gps_icon_source: settings.gpsOn ? "icons/gpsOn.svg" : "icons/gpsOff.svg"
    property var locationAvailable: 0

    function openPopup(title, body, buttons, data) {
        popupTitle = title
        popupBody = body
        popupButtons = buttons
        popupData = data
        popupState = "opened"
    }

    Settings {
        id: settings
        objectName: "settingsObject"
        property int cameraId: 0
        property int aspWide: 0
        property var flash: "flashAuto"
        property var cameras: [{"cameraId": 0, "resolution": 0},
                                {"cameraId": 1, "resolution": 0},
                                {"cameraId": 2, "resolution": 0},
                                {"cameraId": 3, "resolution": 0},
                                {"cameraId": 4, "resolution": 0},
                                {"cameraId": 5, "resolution": 0},
                                {"cameraId": 6, "resolution": 0},
                                {"cameraId": 7, "resolution": 0},
                                {"cameraId": 8, "resolution": 0},
                                {"cameraId": 9, "resolution": 0}]

        property int soundOn: 1
        property var hideTimerInfo: 0
        property int gpsOn: 0
    }

    Settings {
        id: settingsCommon
        fileName: fileManager.getConfigFile(); //"/etc/droidian-camera.conf" or "/usr/lib/droidian/device/droidian-camera.conf"

        property var blacklist: 0
    }

    ListModel {
        id: allCamerasModel
        Component.onCompleted: {
            var blacklist

            if (settingsCommon.blacklist != "") {
                blacklist = settingsCommon.blacklist.split(',')
            }

            for (var i = 0; i < QtMultimedia.availableCameras.length; i++) {
                var cameraInfo = QtMultimedia.availableCameras[i];
                var isBlacklisted = false;

                for (var p in blacklist) {
                    if (blacklist[p] == cameraInfo.deviceId) {
                        console.log("Camera with the id:", blacklist[p], "is blacklisted, not adding to camera list!");
                        isBlacklisted = true;
                        break;
                    }
                }

                if (isBlacklisted) {
                    continue;
                }

                if (cameraInfo.position === Camera.BackFace) {
                    append({"cameraId": cameraInfo.deviceId, "index": i, "position": cameraInfo.position});
                    window.backCameras += 1;
                } else if (cameraInfo.position === Camera.FrontFace) {
                    insert(0, {"cameraId": cameraInfo.deviceId, "index": i, "position": cameraInfo.position});
                    window.frontCameras += 1;
                }
            }
        }
    }

    background: Rectangle {
        color: "black"
    }

    Item {
        id: cslate

        state: "PhotoCapture"

        states: [
            State {
                name: "PhotoCapture"

                PropertyChanges {
                    target: window
                    next_state_left:"Empty" 
                }

                PropertyChanges {
                    target: window
                    next_state_right: "VideoCapture"
                }
            },
            State {
                name: "VideoCapture"

                PropertyChanges {
                    target: window
                    next_state_left: "PhotoCapture"
                }

                PropertyChanges {
                    target: window
                    next_state_right: "Empty"
                }
            }
        ]
    }

    SoundEffect {
        id: sound
        source: "sounds/camera-shutter.wav"
    }

    Rectangle {
        id: videoFrame
        anchors.fill: parent
        color: "black"
    }

    VideoOutput {
        id: viewfinder

        anchors.centerIn: videoFrame
        width: window.width

        source: camera
        autoOrientation: true
        filters: cslate.state === "PhotoCapture" ? [qrCodeComponent.qrcode] : []

        PinchArea {
            id: pinchArea
            x: parent.width / 2 - parent.contentRect.width / 2
            y: parent.height / 2 - parent.contentRect.height / 2
            width: parent.contentRect.width
            height: parent.contentRect.height
            pinch.target: camZoom
            pinch.maximumScale: camera.maximumDigitalZoom / camZoom.zoomFactor
            pinch.minimumScale: 0
            enabled: !mediaView.visible && !window.videoCaptured

            MouseArea {
                id: dragArea
                hoverEnabled: true
                anchors.fill: parent
                enabled: !mediaView.visible && !window.videoCaptured
                property real startX: 0
                property real startY: 0
                property int swipeThreshold: 80
                property var lastTapTime: 0
                property int doubleTapInterval: 300

                onPressed: {
                    startX = mouse.x
                    startY = mouse.y
                }

                onReleased: {
                    var deltaX = mouse.x - startX
                    var deltaY = mouse.y - startY

                    var currentTime = new Date().getTime();
                    if (currentTime - lastTapTime < doubleTapInterval) {
                        window.blurView = 1;
                        camera.position = camera.position === Camera.BackFace ? Camera.FrontFace : Camera.BackFace;
                        cameraSwitchDelay.start();
                        lastTapTime = 0;
                    } else {
                        lastTapTime = currentTime;
                        if (Math.abs(deltaY) > Math.abs(deltaX) && Math.abs(deltaY) > swipeThreshold) { //swipping up or down
                            window.blurView = 1;
                            camera.position = camera.position === Camera.BackFace ? Camera.FrontFace : Camera.BackFace;
                            cameraSwitchDelay.start();
                        } else if (Math.abs(deltaX) > swipeThreshold) {
                            if (deltaX > 0) { // Swipe right
                                window.blurView = 1
                                window.swipeDirection = 0
                                swappingDelay.start()
                            } else { // Swipe left
                                window.blurView = 1
                                window.swipeDirection = 1
                                swappingDelay.start()
                            }
                        } else { // Touch
                            var relativePoint;

                            switch (viewfinder.orientation) {
                                case 0:
                                    relativePoint = Qt.point(mouse.x / viewfinder.contentRect.width, mouse.y / viewfinder.contentRect.height)
                                    break
                                case 90:
                                    relativePoint = Qt.point(1 - (mouse.y / viewfinder.contentRect.height), mouse.x / viewfinder.contentRect.width)
                                    break
                                case 180:
                                    absolutePoint = Qt.point(1 - (mouse.x / viewfinder.contentRect.width), 1 - (mouse.y / viewfinder.contentRect.height))
                                    break
                                case 270:
                                    relativePoint = Qt.point(mouse.y / viewfinder.contentRect.height, 1 - (mouse.x / viewfinder.contentRect.width))
                                    break
                                default:
                                    console.error("wtf")
                            }

                            camera.focus.focusPointMode = Camera.FocusPointCustom
                            camera.focus.customFocusPoint = relativePoint
                            camera.focus.focusMode = Camera.FocusAuto
                            focusPointRect.width = 60
                            focusPointRect.height = 60
                            focusPointRect.visible = true
                            focusPointRect.x = mouse.x - (focusPointRect.width / 2)
                            focusPointRect.y = mouse.y - (focusPointRect.height / 2)

                            visTm.start()
                        }
                    }
                }
            }

            onPinchUpdated: {
                camZoom.zoom = pinch.scale * camZoom.zoomFactor
            }

            Rectangle {
                id: focusPointRect
                border {
                    width: 2
                    color: "#BBB350"
                }

                color: "transparent"
                radius: 2
                width: 80
                height: 80
                visible: false

                Timer {
                    id: visTm
                    interval: 500; running: false; repeat: false
                    onTriggered: focusPointRect.visible = false
                }
            }
        }

        QrCode {
            id: qrCodeComponent
            viewfinder: viewfinder
            openPopupFunction: openPopup
        }

        Rectangle {
            anchors.fill: parent
            opacity: blurView ? 1 : 0
            color: "#40000000"
            visible: opacity != 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }
    }

    FastBlur {
        id: vBlur
        anchors.fill: parent
        opacity: blurView ? 1 : 0
        source: viewfinder
        radius: 128
        visible: opacity != 0
        transparentBorder: false
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }

    Glow {
        anchors.fill: vBlur
        opacity: blurView ? 1 : 0
        radius: 4
        samples: 1
        color: "black"
        source: vBlur
        visible: opacity != 0
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }

    function gcd(a, b) {
        if (b == 0) {
            return a;
        } else {
            return gcd(b, a % b);
        }
    }

    function fnAspectRatio() {
        var maxResolution = {width: 0, height: 0};
        var new43 = 0;
        var new169 = 0;

        for (var p in camera.imageCapture.supportedResolutions) {
            var res = camera.imageCapture.supportedResolutions[p];

            var gcdValue = gcd(res.width, res.height);
            var aspectRatio = (res.width / gcdValue) + ":" + (res.height / gcdValue);

            if (res.width * res.height > maxResolution.width * maxResolution.height) {
                maxResolution = res;
            }

            if (aspectRatio === "4:3" && !new43) {
                new43 = 1;
                camera.firstFourThreeResolution = res;
            }

            if (aspectRatio === "16:9" && !new169) {
                new169 = 1;
                camera.firstSixteenNineResolution = res;
            }
        }

        if (camera.aspWide) {
            camera.imageCapture.resolution = camera.firstSixteenNineResolution;
        } else {
            camera.imageCapture.resolution = camera.firstFourThreeResolution
        }

        if (settings.cameras[camera.deviceId] && settings.cameras[camera.deviceId].resolution !== undefined) {
            settings.cameras[camera.deviceId].resolution = Math.round(
                (camera.imageCapture.supportedResolutions[0].width * camera.imageCapture.supportedResolutions[0].height) / 1000000
            );
        }
    }

    Camera {
        id: camera
        captureMode: Camera.CaptureStillImage

        property variant firstFourThreeResolution
        property variant firstSixteenNineResolution
        property var aspWide: 0

        imageProcessing {
            denoisingLevel: 1.0
            sharpeningLevel: 1.0
            whiteBalanceMode: CameraImageProcessing.WhiteBalanceAuto
        }

        flash.mode: Camera.FlashOff

        imageCapture {
            onImageCaptured: {
                if (settings.soundOn === 1) {
                    sound.play()
                }

                if (settings.hideTimerInfo == 0) {
                    tmDrawer.open()
                }

                if (mediaView.index < 0) {
                    mediaView.folder = StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/furios-camera"
                }
            }

            onImageSaved: {
                if (window.locationAvailable === 1 ) {
                    fileManager.appendGPSMetadata(path);
                }
            }
        }

        Component.onCompleted: {
            camera.stop()
            var currentCam = settings.cameraId
            for (var i = 0; i < QtMultimedia.availableCameras.length; i++) {
                if (settings.cameras[i].resolution == 0)
                    camera.deviceId = i
            }

            if (settings.aspWide == 1 || settings.aspWide == 0) {
                camera.aspWide = settings.aspWide
            }

            window.fnAspectRatio()

            camera.deviceId = currentCam
            camera.start()
        }

        onCameraStatusChanged: {
            if (camera.cameraStatus == Camera.LoadedStatus) {
                window.fnAspectRatio()
            } else if (camera.cameraStatus == Camera.ActiveStatus) {
                camera.focus.focusMode = Camera.FocusContinuous
                camera.focus.focusPointMode = Camera.FocusPointAuto
            }
        }

        onDeviceIdChanged: {
            settings.setValue("cameraId", deviceId);
        }

        onAspWideChanged: {
            settings.setValue("aspWide", aspWide);
        }
    }

    MediaPlayer {
        id: camGst
        autoPlay: false
        videoOutput: viewfinder
        property var backendId: 0
        property string outputPath: StandardPaths.writableLocation(StandardPaths.MoviesLocation).toString().replace("file://","") +
                                            "/furios-camera/video" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmsszzz") + ".mkv"

        Component.onCompleted: {
            fileManager.createDirectory("/Videos/furios-camera");
        }

        property var backends: [
            {
                front: "gst-pipeline: droidcamsrc mode=2 camera-device=1 ! video/x-raw ! videoconvert ! qtvideosink",
                frontRecord: "gst-pipeline: droidcamsrc camera_device=1 mode=2 ! tee name=t t. ! queue ! video/x-raw, width=" + (camera.viewfinder.resolution.width * 3 / 4) + ", height=" + (camera.viewfinder.resolution.height * 3 / 4) + " ! videoconvert ! videoflip video-direction=2 ! qtvideosink t. ! queue ! video/x-raw, width=" + (camera.viewfinder.resolution.width * 3 / 4) + ", height=" + (camera.viewfinder.resolution.height * 3 / 4) + " ! videoconvert ! videoflip video-direction=auto ! jpegenc ! mkv. autoaudiosrc ! queue ! audioconvert ! droidaenc ! mkv. matroskamux name=mkv ! filesink location=" + outputPath,
                back: "gst-pipeline: droidcamsrc mode=2 camera-device=" + camera.deviceId + " ! video/x-raw ! videoconvert ! qtvideosink",
                backRecord: "gst-pipeline: droidcamsrc camera_device=" + camera.deviceId + " mode=2 ! tee name=t t. ! queue ! video/x-raw, width=" + (camera.viewfinder.resolution.width * 3 / 4) + ", height=" + (camera.viewfinder.resolution.height * 3 / 4) + " ! videoconvert ! qtvideosink t. ! queue ! video/x-raw, width=" + (camera.viewfinder.resolution.width * 3 / 4) + ", height=" + (camera.viewfinder.resolution.height * 3 / 4) + " ! videoconvert ! videoflip video-direction=auto ! jpegenc ! mkv. autoaudiosrc ! queue ! audioconvert ! droidaenc ! mkv. matroskamux name=mkv ! filesink location=" + outputPath
            }
        ]

        onError: {
            if (backendId + 1 in backends) {
                backendId++;
            }
        }
    }

    function handleVideoRecording() {
        if (window.videoCaptured == false) {
            camGst.outputPath = StandardPaths.writableLocation(StandardPaths.MoviesLocation).toString().replace("file://","") +
                                            "/furios-camera/video" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmsszzz") + ".mkv"

            if (camera.position === Camera.BackFace) {
                camGst.source = camGst.backends[camGst.backendId].backRecord;
            } else {
                camGst.source = camGst.backends[camGst.backendId].frontRecord;
            }

            camera.stop();

            camGst.play();
            window.videoCaptured = true;
        } else {
            camGst.stop();
            window.videoCaptured = false;
            camera.cameraState = Camera.UnloadedState;
            camera.start();
        }
    }

    Item {
        id: camZoom
        property real zoomFactor: 2.0
        property real zoom: 0
        NumberAnimation on zoom {
            duration: 200
            easing.type: Easing.InOutQuad
        }

        onScaleChanged: {
            camera.setDigitalZoom(scale * zoomFactor)
        }
    }

    Timer {
        id: swappingDelay
        interval: 400
        repeat: false

        onTriggered: {
            if (window.swipeDirection != 2){
                cslate.state = (swipeDirection == 0) ? window.next_state_left : window.next_state_right;
            }
            
            window.blurView = 0
        }
    }

    Timer {
        id: cameraSwitchDelay
        interval: 100
        repeat: false

        onTriggered: {
            window.blurView = 0;
        }
    }

    Drawer {
        id: drawer
        width: 100
        height: parent.height
        dim: false
        background: Rectangle {
            id: background
            anchors.fill: parent
            color: "transparent"
        }

        ColumnLayout {
            id: btnContainer
            spacing: 25
            anchors.centerIn: parent

            Button {
                id: cameraSelectButton
                Layout.topMargin: -35
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                icon.name: "view-more-horizontal-symbolic"
                icon.height: 40
                icon.width: 40
                icon.color: "white"

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                visible: window.backCameras > 1 && window.videoCaptured == false

                onClicked: {
                    backCamSelect.visible = true
                    optionContainer.state = "opened"
                    drawer.close()
                    window.blurView = 1
                }
            }

            Button {
                id: flashButton

                height: width
                Layout.alignment: Qt.AlignHCenter
                icon.name: "thunderbolt-symbolic"
                icon.height: 40
                icon.width: 40
                icon.color: "white"
                state: settings.flash

                visible: !window.videoCaptured

                states: [
                    State {
                        name: "flashOff"
                        PropertyChanges {
                            target: camera
                            flash.mode: Camera.FlashOff
                        }

                        PropertyChanges {
                            target: settings
                            flash: "flashOff"
                        }
                    },

                    State {
                        name: "flashOn"
                        PropertyChanges {
                            target: camera
                            flash.mode: Camera.FlashOn
                        }

                        PropertyChanges {
                            target: settings
                            flash: "flashOn"
                        }
                    },

                    State {
                        name: "flashAuto"
                            PropertyChanges {
                            target: camera
                            flash.mode: Camera.FlashAuto
                        }

                        PropertyChanges {
                            target: settings
                            flash: "flashAuto"
                        }
                    }
                ]

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                onClicked: {
                    if (camera.position !== Camera.FrontFace) {
                        if (flashButton.state == "flashOff") {
                            flashButton.state = "flashOn"
                        } else if (flashButton.state == "flashOn") {
                            flashButton.state = "flashAuto"
                        } else if (flashButton.state == "flashAuto") {
                            flashButton.state = "flashOff"
                        }
                    }
                }

                Text {
                    anchors.fill: parent
                    text: flashButton.state == "flashOn" ? "\u2714" :
                            flashButton.state == "flashOff" ? "\u2718" : "A"
                    color: "white"
                    z: parent.z + 1
                    font.pixelSize: 32
                    font.bold: true
                    style: Text.Outline;
                    styleColor: "black"
                    bottomPadding: 10
                }
            }
        }

        onClosed: {
            window.blurView = optionContainer.state == "opened" ? 1 : 0
        }
    }

    Rectangle {
        id: optionContainer
        width: parent.width
        height: parent.height * .5
        anchors.verticalCenter: parent.verticalCenter
        state: "closed"

        color: "transparent"

        states: [
            State {
                name: "opened"
                PropertyChanges {
                    target: optionContainer
                    x: window.width / 2 - optionContainer.width / 2
                }
            },

            State {
                name: "closed"
                PropertyChanges {
                    target: optionContainer
                    x: window.width
                }
            }
        ]

        ColumnLayout {
            anchors.fill: parent

            ColumnLayout {
                id: backCamSelect
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true

                function getSpaces(numDigits) {
                    if (numDigits === 1) {
                        return "      ";
                    } else if (numDigits === 2) {
                        return "    ";
                    } else if (numDigits === 3) {
                        return " ";
                    } else {
                        return "";
                    }
                }

                Repeater {
                    model: allCamerasModel
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: parent.width * 0.9
                    Button {
                        property var pos: model.position == 1 ? "Back" : "Front"
                        property var numDigits: settings.cameras[model.cameraId].resolution.toString().length
                        Layout.alignment: Qt.AlignLeft
                        visible: parent.visible
                        icon.name: "camera-video-symbolic"
                        icon.color: "white"
                        icon.width: 48
                        icon.height: 48
                        palette.buttonText: "white"

                        font.pixelSize: 32
                        font.bold: true
                        text: " " + settings.cameras[model.cameraId].resolution + "MP" + backCamSelect.getSpaces(numDigits) + pos

                        background: Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                        }

                        onClicked: {
                            window.blurView = 0
                            camera.deviceId = model.cameraId
                            optionContainer.state = "closed"
                        }
                    }
                }
            }
        }

        Behavior on x {
            PropertyAnimation {
                duration: 300
            }
        }
    }

    Timer {
        id: preCaptureTimer
        interval: 1000
        onTriggered: {
            countDown -= 1
            if (countDown < 1) {
                camera.imageCapture.capture();
                preCaptureTimer.stop();
            }
        }

        running: false
        repeat: true
    }

    Drawer {
        id: tmDrawer
        width: parent.width
        edge: Qt.BottomEdge
        dim: true

        background: Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.9
        }

        GridLayout {
            columnSpacing: 5
            rowSpacing: 25
            anchors.centerIn: parent
            width: parent.width * 0.9
            columns: 2
            rows: 2

            Button {
                icon.name: "help-about-symbolic"
                icon.color: "lightblue"
                icon.width: 48
                icon.height: 48
                Layout.preferredWidth: icon.width * 1.5
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                Layout.topMargin: 10

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }
            }

            Text {
                Layout.alignment: Qt.AlignLeft
                Layout.fillWidth: true
                Layout.topMargin: 10
                text: "Press & hold to use the timer"
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                font.pixelSize: 32
                font.bold: true
                style: Text.Outline;
                styleColor: "black"
                wrapMode: Text.WordWrap
            }

            Button {
                icon.name: "emblem-default-symbolic"
                icon.color: "white"
                icon.width: 48
                icon.height: 48
                Layout.columnSpan: 2
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                onClicked: {
                    tmDrawer.close()
                    settings.hideTimerInfo = 1
                    settings.setValue("hideTimerInfo", 1);
                }
            }
        }
        onClosed: {
            window.blurView = 0;
        }
    }

    Item {
        id: mainBar2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 35
        height: 150
        width: parent.width
        visible: !mediaView.visible

        Item {
            id: hotBar
            anchors.top: parent.top
            width: parent.width
            height: parent.height / 3

            Rectangle{
                id: frame
                anchors.fill: parent
                color: "red"
            }

            Rectangle {
                id: stateContainer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 400
                height: 180
                color: "transparent"

                RowLayout {
                    anchors.centerIn: parent
                    visible: !mediaView.visible && !window.videoCaptured
                    enabled: !mediaView.visible && !window.videoCaptured
                    spacing: 15

                    Rectangle {
                        width: 80
                        height: 30
                        radius: 5
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Camera"
                            font.bold: true
                            color: cslate.state == "PhotoCapture" ? "orange" : "lightgray"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (cslate.state != "PhotoCapture") {
                                    optionContainer.state = "closed"
                                    window.swipeDirection = 2
                                    window.blurView = 1
                                    cslate.state = "PhotoCapture"
                                    swappingDelay.start()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 80
                        height: 30
                        radius: 5
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Video"
                            font.bold: true
                            color: cslate.state == "VideoCapture" ? "orange" : "lightgray"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (cslate.state != "VideoCapture") {
                                    optionContainer.state = "closed"
                                    cslate.state = "VideoCapture"
                                    window.swipeDirection = 2
                                    window.blurView = 1
                                    swappingDelay.start()
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: mainBarBottom
            anchors.top: hotBar.bottom
            width: parent.width
            height: parent.height - hotBar.height

            Rectangle {
                id: frame2
                anchors.fill: parent
                color: "blue"
            }

            Rectangle {
                id: rotateBtnFrame
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 60
                width: 60
                radius: 20
                color: "#333333"
                anchors.rightMargin: 50
                anchors.bottomMargin: 5
                visible: !window.videoCaptured

                Button {
                    id: rotateCamera
                    anchors.fill: parent
                    icon.source: "icons/rotateCamera.svg"
                    icon.color: "white"
                    icon.width: 45
                    icon.height: 40
                    enabled: !window.videoCaptured
                    visible: drawer.position == 0.0 && optionContainer.state == "closed"

                    background: Rectangle {
                        color: "transparent"
                    }

                    onClicked: {
                        if (camera.position === Camera.BackFace) {
                            drawer.close()
                            camera.position = Camera.FrontFace;
                        } else if (camera.position === Camera.FrontFace) {
                            drawer.close()
                            camera.position = Camera.BackFace;
                        }
                    }
                }
            }

            Rectangle {
                id: reviewBtnFrame
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: 60
                radius: 5
                width: 60
                anchors.leftMargin: 50
                anchors.bottomMargin: 10
                enabled: !window.videoCaptured
                visible: !window.videoCaptured

                Rectangle {
                    id: reviewBtn
                    width: parent.width
                    height: parent.height
                    radius: 5
                    color: "black"
                    layer.enabled: true

                    layer.effect: OpacityMask {
                        maskSource: Item {
                            width: reviewBtn.width
                            height: reviewBtn.height

                            Rectangle {
                                anchors.centerIn: parent
                                width: reviewBtn.adapt ? reviewBtn.width : Math.min(reviewBtn.width, reviewBtn.height)
                                height: reviewBtn.adapt ? reviewBtn.height : width
                                radius: 5
                            }
                        }
                    }

                    Image {
                        anchors.centerIn: parent
                        autoTransform: true
                        transformOrigin: Item.Center
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: (cslate.state == "PhotoCapture") ? mediaView.lastImg : ""
                        scale: Math.min(parent.width / width, parent.height / height)
                    }
                }

                Rectangle {
                    anchors.fill: reviewBtn
                    color: "transparent"
                    radius: 5

                    MouseArea {
                        anchors.fill: parent
                        onClicked: mediaView.visible = true
                    }
                }
            }

            Rectangle {
                id: shutterBtnFrame
                height: 70
                width: 70
                radius: 70
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                visible: cslate.state === "PhotoCapture"

                Loader {
                    id: shutterBtnLoader
                    anchors.fill: parent
                    sourceComponent: configBar.opened === 1 || preCaptureTimer.running ? timerShutter : pictureShutter
                }

                Component{
                    id: pictureShutter
                    Item {
                        Rectangle {
                            anchors.centerIn: parent
                            height: 55
                            width: 55
                            radius: 55
                            color: "black"
                        }

                        Button {
                            id: shutterBtn
                            anchors.centerIn: parent
                            height: 70
                            width: 70
                            enabled: cslate.state === "PhotoCapture" && !mediaView.visible

                            background: Rectangle {
                                id: camerabtn
                                anchors.centerIn: parent
                                width: shutterBtnFrame.width - 20
                                height: shutterBtnFrame.height - 20
                                radius: shutterBtnFrame.radius - 20
                                color: "white"

                                SequentialAnimation on color {
                                    id: animation
                                    running: false

                                    ColorAnimation {
                                        target: camerabtn
                                        property: "color"
                                        from: "white"
                                        to: "gray"
                                        duration: 150
                                    }

                                    ColorAnimation {
                                        target: camerabtn
                                        property: "color"
                                        from: "gray"
                                        to: "white"
                                        duration: 150
                                    }
                                }
                            }

                            onClicked: {
                                animation.start();
                                pinchArea.enabled = true
                                window.blurView = 0
                                camera.imageCapture.capture()
                            }
                        }
                    }
                }

                Component {
                    id: timerShutter
                    Item {
                        Button {
                            id: shutterBtn
                            anchors.fill: parent.fill
                            anchors.centerIn: parent
                            enabled: cslate.state === "PhotoCapture" && !mediaView.visible
                            icon.name: preCaptureTimer.running ? "" : configBar.currIndex < 1 ? "window-close-symbolic" : ""
                            icon.source: preCaptureTimer.running ? "" : configBar.currIndex > 0 ? "icons/timer.svg" : ""

                            icon.color: "white"
                            icon.width: shutterBtnFrame.width - 10
                            icon.height: shutterBtnFrame.height - 10

                            text: preCaptureTimer.running ? countDown : ""

                            palette.buttonText: "red"

                            font.pixelSize: 50
                            font.bold: true
                            font.family: "Lato Hairline"
                            visible: true

                            background: Rectangle {
                                anchors.centerIn: parent
                                width: shutterBtnFrame.width
                                height: shutterBtnFrame.height
                                color: "black"
                                radius: shutterBtnFrame.radius - 10
                            }

                            onClicked: {
                                pinchArea.enabled = true
                                window.blurView = 0

                                if (configBar.currIndex > 0) {
                                    configBar.opened = 0
                                    optionContainer.state = "closed"
                                    countDown = configBar.currIndex
                                    preCaptureTimer.start()
                                } else if (configBar.currIndex < 1) {
                                    optionContainer.state = "closed"
                                    configBar.opened = 0
                                }
                            }
                        }
                    }

                }
            }

            Rectangle {
                id: videoBtnFrame
                height: 70
                width: 70
                radius: 35
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                visible: cslate.state === "VideoCapture"

                Button {
                    id: videoBtn
                    anchors.fill: parent
                    enabled: cslate.state === "VideoCapture" && !mediaView.visible

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        color: "red"
                        radius: 15
                        visible: !window.videoCaptured
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: window.videoCaptured
                        width: 30
                        height: 30
                        color: "black"
                    }

                    text: preCaptureTimer.running ? countDown : ""
                    palette.buttonText: "white"
                    font.pixelSize: 64
                    font.bold: true

                    background: Rectangle {
                        anchors.centerIn: parent
                        width: videoBtnFrame.width
                        height: videoBtnFrame.height
                        color: "white"
                        radius: videoBtnFrame.radius
                    }

                    onClicked: {
                        handleVideoRecording()
                    }

                    Behavior on rotation {
                        RotationAnimation {
                            duration: 250
                            direction: RotationAnimation.Counterclockwise
                        }
                    }
                }
            }
        }
    }

    MediaReview {
        id: mediaView
        anchors.fill: parent
        onClosed: camera.start()
        focus: visible
    }

    Item {
        id: configBar
        width: parent.width
        anchors.top: parent.top
        anchors.topMargin: 20

        property var opened: 0;
        property var aspectRatioOpened: 0;
        property var currIndex: timerTumbler.currentIndex
        visible: !mediaView.visible

        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Button {
                icon.name: settings.soundOn === 1 ? "audio-volume-high-symbolic" : "audio-volume-muted-symbolic"
                icon.height: 30
                icon.width: 30
                icon.color: settings.soundOn === 1 ? "white" : "grey"

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                onClicked: {
                    settings.soundOn = settings.soundOn === 1 ? 0 : 1;
                }
            }

            Button {
                icon.source: window.gps_icon_source
                icon.height: 30
                icon.width: 30
                icon.color: settings.locationAvailable === 1 ? "white" : "grey"

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                Connections {
                    target: fileManager

                    function onGpsDataReady() {
                        window.gps_icon_source = "icons/gpsOn.svg";
                        window.locationAvailable = 1;
                    }
                }

                onClicked: {
                    settings.gpsOn = settings.gpsOn === 1 ? 0 : 1;

                    if (settings.gpsOn === 1) {
                        fileManager.turnOnGps();
                    } else {
                        fileManager.turnOffGps();
                        window.gps_icon_source = "icons/gpsOff.svg";
                        window.locationAvailable = 0;
                    }
                }

                Connections {
                    target: fileManager

                    function onGpsDataReady() {
                        window.gps_icon_source = "icons/gpsOn.svg";
                        window.locationAvailable = 1;
                    }
                }
            }

            Button {
                id: timerButton
                icon.source: "icons/timer.svg"
                icon.height: 30
                icon.width: 30
                icon.color: "white"

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                onClicked: {
                    configBar.opened = configBar.opened === 1 ? 0 : 1
                    configBar.aspectRatioOpened = 0
                    window.blurView = 1
                }

                Tumbler {
                    id: timerTumbler
                    height: 200
                    anchors.horizontalCenter: timerButton.horizontalCenter
                    Layout.preferredWidth: parent.width * 0.9
                    anchors.top: timerButton.bottom
                    model: 60
                    visible: configBar.opened === 1 ? true : false
                    enabled: configBar.opened === 1 ? true : false

                    delegate: Text {
                        text: modelData == 0 ? "Off" : modelData
                        color: "white"
                        font.bold: true
                        font.pixelSize: 35
                        font.family: "Lato Hairline"
                        horizontalAlignment: Text.AlignHCenter
                        opacity: 0.4 + Math.max(0, 1 - Math.abs(Tumbler.displacement)) * 0.6
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.InOutQuad
                        }
                    }

                    onVisibleChanged: {
                        opacity = visible ? 1 : 0
                    }
                }
            }

            Button {
                id: aspectRatioButton
                icon.source: "icons/aspectRatioMenu.svg"
                icon.height: 30
                icon.width: 30
                icon.color: "white"

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                onClicked: {
                    configBar.aspectRatioOpened = configBar.aspectRatioOpened === 1 ? 0 : 1
                    configBar.opened = 0
                }

                ColumnLayout {
                    id: aspectRatios
                    anchors.top: aspectRatioButton.bottom
                    anchors.horizontalCenter: aspectRatioButton.horizontalCenter
                    visible: configBar.aspectRatioOpened === 1 ? true : false

                    Button {
                        id: sixteenNineButton
                        text: "16:9"
                        Layout.preferredWidth: 60
                        font.pixelSize: 18
                        font.bold: true
                        font.family: "Lato Hairline"
                        palette.buttonText: camera.aspWide === 1 ? "white" : "gray"

                        background: Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: "white"
                            radius: 6
                        }

                        onClicked: {
                            camera.aspWide = 1;
                            configBar.aspectRatioOpened = 0;
                            camera.imageCapture.resolution = camera.firstSixteenNineResolution
                        }
                    }

                    Button {
                        id: fourThreeButton
                        text: "4:3"
                        Layout.preferredWidth: 60
                        font.pixelSize: 18
                        font.bold: true
                        font.family: "Lato Hairline"
                        palette.buttonText: camera.aspWide === 1 ? "gray" : "white"

                        background: Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: "white"
                            radius: 6
                        }

                        onClicked: {
                            camera.aspWide = 0;
                            configBar.aspectRatioOpened = 0;
                            camera.imageCapture.resolution = camera.firstFourThreeResolution
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.InOutQuad
                        }
                    }

                    onVisibleChanged: {
                        opacity = visible ? 1 : 0
                    }
                }
            }

            Button {
                id: menu
                icon.source: "icons/menu.svg"
                icon.height: 30
                icon.width: 30
                icon.color: "white"
                enabled: !window.videoCaptured

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                onClicked: {
                    if (!mediaView.visible) {
                        window.blurView = 1
                        drawer.open()
                    }
                }
            }
        }
    }
    
    Rectangle {
        id: popupBackdrop
        width: window.width
        height: window.height
        color: "#66000000"
        opacity: popupState === "opened" ? 1 : 0
        visible: popupState === "opened"

        Behavior on opacity {
            NumberAnimation {
                duration: 125
            }
        }

        Behavior on visible {
            PropertyAnimation {
                duration: 125
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                popupState = "closed"
            }
        }

        TextEdit {
            id: copyToClipboardHelper
            opacity: 0
            text: popupData
        }

        Rectangle {
            id: popup
            width: window.width * 0.8
            height: childrenRect.height
            color: "#ff383838"
            radius: 10
            anchors.centerIn: parent

            /* adwaita-like popup: big title, center-aligned text, buttons at the bottom */
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                spacing: 0

                Text {
                    text: popupTitle
                    color: "white"
                    font.pixelSize: 24
                    font.weight: Font.ExtraBold
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    wrapMode: Text.WordWrap
                    padding: 5
                    topPadding: 25
                }

                Text {
                    text: popupBody
                    color: "white"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    wrapMode: Text.WordWrap
                    padding: 10
                    topPadding: 10
                    bottomPadding: 25
                }

                Rectangle {
                    width: parent.width
                    height: 48
                    color: "transparent"
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                        width: parent.width
                        height: parent.height
                        spacing: 0

                        Repeater {
                            model: popupButtons
                            Button {
                                text: modelData.text
                                onClicked: {
                                    popupState = "closed"
                                    // modelData.onClicked(popupData)

                                    // jesus todo: I don't know why but I can't call functions passed inside the object.
                                    // printing the keys shows that the function is there, but calling it says it's undefined. ???

                                    if (modelData.text === "Open") {
                                        QRCodeHandler.openUrlInFirefox(popupData)
                                    } else if (modelData.text === "Copy") {
                                        /* oh god */
                                        copyToClipboardHelper.selectAll()
                                        copyToClipboardHelper.copy()
                                    }
                                }

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                background: Rectangle {
                                    color: parent.down ? "#33ffffff" : "transparent"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 100
                                        }
                                    }
                                }

                                palette.buttonText: modelData.isPrimary ? "#62a0ea" : "white"
                                font.pixelSize: 16
                                font.bold: true

                                clip: true
                                Rectangle {
                                    visible: popupButtons.length > 1 && index < popupButtons.length - 1 ? 1 : 0
                                    border.width: 1
                                    border.color: "#565656"
                                    anchors.fill: parent
                                    anchors.leftMargin: -1
                                    anchors.topMargin: -1
                                    anchors.bottomMargin: -1
                                    color: "transparent"
                                }
                            }
                        }
                    }

                    /* top border */
                    clip: true
                    Rectangle {
                        border.width: 1
                        border.color: "#565656"
                        anchors.fill: parent
                        anchors.leftMargin: -2
                        anchors.rightMargin: -2
                        anchors.bottomMargin: -2
                        color: "transparent"
                    }
                }
            }
        }
        DropShadow {
            anchors.fill: popup
            horizontalOffset: 0
            verticalOffset: 1
            radius: 8
            samples: 6
            color: "#44000000"
            source: popup
        }
    }
}
