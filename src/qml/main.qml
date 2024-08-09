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

    property real refHeight: 800
    property real refWidth: 400

    property real scalingRatio: Math.min(Screen.width / refWidth, Screen.height / refHeight)


    property alias cam: camGst
    property bool videoCaptured: false

    property var countDown: 0
    property var blurView: optionContainer.state == "closed" && infoDrawer.position == 0.0 ? 0 : 1
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
    property var mediaViewOpened: false
    property var focusPointVisible: false
    property var aeflock: "AEFLockOff"


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
        property var hideInfoDrawer: 0
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
        id: focusState

        state: "AutomaticFocus"

        states: [
            State {
                name: "WaitingForTarget" // AEF lock on and waiting for target.

                PropertyChanges {
                    target: camera
                    focus.focusMode: Camera.FocusAuto
                    focus.focusPointMode: Camera.FocusPointCustom
                }
            },
            State {
                name: "TargetLocked" // First touch after AEF Lock started.

                PropertyChanges {
                    target: camera
                    focus.focusMode: Camera.FocusContinuous
                    focus.focusPointMode: Camera.FocusPointCustom
                }
            },
            State {
                name: "AutomaticFocus" // Moving around and no touch, no AEF lock.

                PropertyChanges {
                    target: camera
                    focus.focusMode: Camera.FocusAuto
                    focus.focusPointMode: Camera.FocusPointAuto
                }
            },
            State {
                name: "ManualFocus" // Touch screen and no AEF lock.

                PropertyChanges {
                    target: camera
                    focus.focusMode: Camera.FocusAuto
                    focus.focusPointMode: Camera.FocusPointCustom
                }
            }
        ]
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

        property var gcdValue: gcd(camera.viewfinder.resolution.width, camera.viewfinder.resolution.height)

        width: videoFrame.width
        height: videoFrame.height
        anchors.centerIn: parent
        anchors.verticalCenterOffset: gcdValue === "16:9" ? -30 * window.scalingRatio : -60 * window.scalingRatio
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
                        if (Math.abs(deltaY) > Math.abs(deltaX) && Math.abs(deltaY) > swipeThreshold) {
                            if (deltaY > 0) { // Swipe down logic
                                configBarDrawer.open()
                            } else { // Swipe up logic
                                window.blurView = 1;
                                flashButton.state = "flashOff"
                                camera.position = camera.position === Camera.BackFace ? Camera.FrontFace : Camera.BackFace;
                                cameraSwitchDelay.start();
                            }
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

                            if (aefLockTimer.running) {
                                focusState.state = "TargetLocked"
                                aefLockTimer.stop()
                            } else {
                                focusState.state = "ManualFocus"
                                window.aeflock = "AEFLockOff"
                            }

                            if (window.aeflock !== "AEFLockOn" || focusState.state === "TargetLocked") {
                                camera.focus.customFocusPoint = relativePoint
                                focusPointRect.width = 60 * window.scalingRatio
                                focusPointRect.height = 60 * window.scalingRatio
                                window.focusPointVisible = true
                                focusPointRect.x = mouse.x - (focusPointRect.width / 2)
                                focusPointRect.y = mouse.y - (focusPointRect.height / 2)
                            }

                            console.log("index: " + configBar.currIndex)
                            window.blurView = 0
                            configBarDrawer.close()
                            optionContainer.state = "closed"
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
                    color: "#FDD017"
                }

                color: "transparent"
                radius: 5 * window.scalingRatio
                width: 80 * window.scalingRatio
                height: 80 * window.scalingRatio
                visible: window.focusPointVisible

                Timer {
                    id: visTm
                    interval: 500; running: false; repeat: false
                    onTriggered: window.aeflock === "AEFLockOff" ? window.focusPointVisible = false : null
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

        focus {
            focusMode: Camera.AutoFocus
            focusPointMode: Camera.FocusPointCenter
        }

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

                if (settings.hideInfoDrawer == 0) {
                    infoDrawer.open()
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
        property var next_state: ""

        onTriggered: {
            if (window.swipeDirection != 2){
                swappingDelay.next_state = (swipeDirection == 0) ? window.next_state_left : window.next_state_right;
                cslate.state = next_state === "Empty" ? cslate.state : swappingDelay.next_state;
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

    Timer {
        id: aefLockTimer
        interval: 2000
        repeat: false

        onTriggered: {
            focusState.state = "AutomaticFocus"
            window.aeflock = "AEFLockOff"
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
                        icon.source: "icons/cameraVideoSymbolic.svg"
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
        id: infoDrawer
        width: parent.width
        edge: Qt.BottomEdge
        dim: true
        interactive: settings.hideInfoDrawer != 1

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
                icon.source: "icons/helpAboutSymbolic.svg"
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
                text: "Swipe down for more options"
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                font.pixelSize: 32
                font.bold: true
                style: Text.Outline;
                styleColor: "black"
                wrapMode: Text.WordWrap
            }

            Button {
                icon.source: "icons/emblemDefaultSymbolic.svg"
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
                    infoDrawer.close()
                    settings.hideInfoDrawer = 1
                    settings.setValue("hideInfoDrawer", 1);
                }
            }
        }
        onClosed: {
            window.blurView = 0;
        }
    }

    Item {
        id: mainBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30 * window.scalingRatio
        height: 150 * window.scalingRatio
        width: parent.width
        visible: !mediaView.visible

        Item {
            id: hotBar
            anchors.top: parent.top
            anchors.horizontalCenter: mainBar.horizontalCenter
            width: parent.width
            height: parent.height / 3
            visible: !window.videoCaptured

            Rectangle {
                id: flashButtonFrame
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: parent.width * 0.15
                radius: 20
                color: "transparent"
                anchors.leftMargin: 40 * window.scalingRatio

                Button {
                    id: flashButton

                    height: width
                    anchors.fill: parent
                    icon.source: flashButton.state === "flashOn" ? "icons/flashOn.svg" : flashButton.state === "flashOff" ? "icons/flashOff.svg" : "icons/flashAuto.svg"
                    icon.height: parent.height / 1.5
                    icon.width: parent.width / 1.5
                    icon.color: "white"
                    state: settings.flash

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
                }
            }

            Rectangle {
                id: changeStateBtnFrame
                width: hotBar.width * 0.4
                height: hotBar.height * 0.9
                color: "transparent"
                anchors.centerIn: parent

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Item {
                        width: changeStateBtnFrame.width
                        height: changeStateBtnFrame.height
                        Rectangle {
                            anchors.fill: parent
                            radius: 30 * window.scalingRatio
                        }
                    }
                }

                Rectangle {
                    anchors.fill: changeStateBtnFrame
                    color: "#ff383838"
                    anchors.centerIn: parent

                    RowLayout {
                        width: parent.width
                        height: parent.height
                        spacing: 0

                        Button {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            icon.source: "icons/cameraState.svg"
                            icon.height: parent.height * 0.5
                            icon.width: parent.width * 0.15
                            icon.color: "white"

                            background: Rectangle {
                                color: cslate.state === "PhotoCapture" ? "transparent" : "#33ffffff"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 300
                                    }
                                }
                            }

                            onClicked: {
                                if (cslate.state != "PhotoCapture") {
                                    optionContainer.state = "closed"
                                    cslate.state = "PhotoCapture"
                                    window.swipeDirection = 2
                                    window.blurView = 1
                                    swappingDelay.start()
                                }
                            }
                        }

                        Button {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            icon.source: "icons/videoState.svg"
                            icon.height: parent.height * 0.37
                            icon.width: parent.width * 0.15
                            icon.color: "white"

                            background: Rectangle {
                                color: cslate.state === "VideoCapture" ? "transparent" : "#33ffffff"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 300
                                    }
                                }
                            }

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

            Rectangle {
                id: aefLockBtnFrame
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height + 10
                width: parent.width * 0.15
                radius: 20 * window.scalingRatio
                color: "transparent"
                anchors.rightMargin: 43 * window.scalingRatio

                Button {
                    id: aefLockBtn

                    height: width
                    anchors.fill: parent
                    icon.source: window.aeflock === "AEFLockOn" ? "icons/AEFLockOn.svg" : "icons/AEFLockOff.svg"
                    icon.height: parent.height / 1.5
                    icon.width: parent.width / 1.5
                    icon.color: "white"
                    state: window.aeflock

                    states: [
                        State {
                            name: "AEFLockOff"

                            PropertyChanges {
                                target: window
                                aeflock: "AEFLockOff"
                            }
                        },

                        State {
                            name: "AEFLockOn"

                            PropertyChanges {
                                target: window
                                aeflock: "AEFLockOn"
                            }
                        }
                    ]

                    background: Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                    }

                    onClicked: {
                        if (camera.position !== Camera.FrontFace) {
                            if (aefLockBtn.state === "AEFLockOff") {
                                focusState.state = "WaitingForTarget"
                                window.aeflock = "AEFLockOn"
                                aefLockTimer.start()
                            } else if (aefLockBtn.state === "AEFLockOn") {
                                window.aeflock = "AEFLockOff"
                                focusState.state = "AutomaticFocus"
                                window.focusPointVisible = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: aefLockLabel
                anchors.horizontalCenter: hotBar.horizontalCenter
                anchors.bottom: parent.top
                width: hotBar.width * 0.4
                height: hotBar.height * 0.8
                radius: 15 * window.scalingRatio
                color: "#FDD017"

                visible: window.aeflock === "AEFLockOn" || focusState.state === "TargetLocked"

                Text {
                    text: focusState.state === "WaitingForTarget" ? "Select a Target" : "AE/AF Lock On"
                    color: "black"
                    font.pixelSize: 17 * window.scalingRatio
                    style: Text.Raised
                    styleColor: "black"
                    elide: Text.ElideRight
                    anchors.centerIn: parent
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

        Item {
            id: mainBarBottom
            anchors.bottom: mainBar.bottom
            width: parent.width
            height: parent.height - hotBar.height

            Rectangle {
                id: rotateBtnFrame
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height * 0.65
                width: height
                radius: width / 2
                color: "#333333"
                anchors.rightMargin: 40 * window.scalingRatio
                visible: !window.videoCaptured

                Button {
                    id: rotateCamera
                    anchors.fill: parent
                    icon.source: "icons/rotateCamera.svg"
                    icon.color: "white"
                    icon.width: rotateBtnFrame.height * 0.45
                    icon.height: rotateBtnFrame.height * 0.3
                    enabled: !window.videoCaptured
                    visible: optionContainer.state == "closed"

                    background: Rectangle {
                        color: "transparent"
                    }

                    onClicked: {
                        if (camera.position === Camera.BackFace) {
                            flashButton.state = "flashOff"
                            camera.position = Camera.FrontFace;
                        } else if (camera.position === Camera.FrontFace) {
                            camera.position = Camera.BackFace;
                        }
                    }
                }
            }

            Rectangle {
                id: reviewBtnFrame
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height * 0.65
                width: height
                radius: width / 2
                anchors.leftMargin: 40 * window.scalingRatio
                enabled: !window.videoCaptured
                visible: !window.videoCaptured

                Rectangle {
                    id: reviewBtn
                    anchors.fill: parent
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
                                radius: width / 2
                            }
                        }
                    }

                    Image {
                        anchors.centerIn: parent
                        autoTransform: true
                        transformOrigin: Item.Center
                        fillMode: Image.Stretch
                        smooth: false
                        source: (cslate.state == "PhotoCapture") ? mediaView.lastImg : ""
                        scale: Math.min(parent.width / width, parent.height / height)
                    }
                }

                Rectangle {
                    anchors.fill: reviewBtn
                    color: "transparent"
                    radius: 5 * window.scalingRatio

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            mediaView.visible = true;
                        }
                    }
                }
            }

            Loader {
                id: stateBtnLoader
                anchors.fill: parent
                asynchronous: true
                sourceComponent: cslate.state === "PhotoCapture"? shutterBtnComponent : videoBtnComponent
            }

            Component {
                id: shutterBtnComponent
                Item {
                    Rectangle {
                        id: shutterBtnFrame
                        height: parent.height * 0.75
                        width: height
                        radius: 70 * window.scalingRatio
                        color: "white"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        visible: cslate.state === "PhotoCapture"

                        Loader {
                            id: shutterBtnLoader
                            anchors.fill: parent
                            asynchronous: true
                            sourceComponent: configBar.opened === 1 || preCaptureTimer.running ? timerShutter : pictureShutter
                        }

                        Component{
                            id: pictureShutter
                            Item {
                                Rectangle {
                                    anchors.centerIn: parent
                                    height: shutterBtnFrame.height * 0.80
                                    width: height
                                    radius: 55 * window.scalingRatio
                                    color: "black"
                                }

                                Button {
                                    id: shutterBtn
                                    anchors.centerIn: parent
                                    height: shutterBtnFrame.height
                                    width: height
                                    enabled: cslate.state === "PhotoCapture" && !mediaView.visible

                                    background: Rectangle {
                                        id: camerabtn
                                        anchors.centerIn: parent
                                        height: shutterBtnFrame.height * 0.75
                                        width: height
                                        radius: 55 * window.scalingRatio
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
                                    icon.source: preCaptureTimer.running ? "" : configBar.currIndex === 0 ? "icons/windowCloseSymbolic.svg" : "icons/timer.svg"
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
                }
            }

            Component {
                id: videoBtnComponent
                Item {
                    Rectangle {
                        id: videoBtnFrame
                        height: parent.height * 0.75
                        width: height
                        radius: 70 * window.scalingRatio
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        visible: cslate.state === "VideoCapture"

                        Button {
                            id: videoBtn
                            anchors.fill: parent
                            enabled: !mediaView.visible

                            Rectangle {
                                anchors.centerIn: parent
                                height: videoBtnFrame.height * 0.5
                                width: height
                                color: "red"
                                radius: videoBtnFrame.radius
                                visible: !window.videoCaptured
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                visible: window.videoCaptured
                                height: videoBtnFrame.height * 0.5
                                width: height
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
        }
    }

    MediaReview {
        id: mediaView
        anchors.fill: parent
        onClosed: camera.start()
        focus: visible

        scalingRatio: window.scalingRatio
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
                                    } else if (modelData.text === "Connect") {
                                        QRCodeHandler.connectToWifi();
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

    Drawer {
        id: configBarDrawer
        height: 55 * window.scalingRatio
        width: window.width
        dim: false
        edge: Qt.TopEdge
        modal: false
        interactive: false

        visible: !configBarBtn.visible

        background: Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        Item {
            id: configBar
            width: parent.width
            height: configBarDrawer.height
            anchors.centerIn: parent

            property var opened: 0;
            property var aspectRatioOpened: 0;
            property var currIndex: timerTumbler.currentIndex
            visible: !mediaView.visible && !window.videoCaptured

            RowLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: configBarDrawer.height * 0.4

                Button {
                    icon.source: settings.soundOn === 1 ? "icons/audioOn.svg" : "icons/audioOff.svg"
                    icon.height: configBarDrawer.height * 0.6
                    icon.width: configBarDrawer.width * 0.08
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
                    icon.height: configBarDrawer.height * 0.6
                    icon.width: configBarDrawer.width * 0.08
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
                    icon.height: configBarDrawer.height * 0.6
                    icon.width: configBarDrawer.width * 0.08
                    icon.color: "white"

                    background: Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                    }

                    onClicked: {
                        configBar.opened = configBar.opened === 1 ? 0 : 1
                        configBar.aspectRatioOpened = 0
                        optionContainer.state = "closed"
                        window.blurView = 1
                    }

                    Tumbler {
                        id: timerTumbler
                        height: 200 * window.scalingRatio
                        width: 50 * window.scalingRatio
                        anchors.horizontalCenter: timerButton.horizontalCenter
                        Layout.preferredWidth: parent.width
                        anchors.top: timerButton.bottom
                        model: 60
                        visible: configBar.opened === 1 ? true : false
                        enabled: configBar.opened === 1 ? true : false

                        delegate: Text {
                            text: modelData == 0 ? "Off" : modelData
                            color: "white"
                            font.bold: true
                            font.pixelSize: 30 * window.scalingRatio
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
                    icon.height: configBarDrawer.height * 0.6
                    icon.width: configBarDrawer.width * 0.08
                    icon.color: "white"

                    background: Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                    }

                    onClicked: {
                        configBar.aspectRatioOpened = configBar.aspectRatioOpened === 1 ? 0 : 1
                        optionContainer.state = "closed"
                        configBar.opened = 0
                    }

                    ColumnLayout {
                        id: aspectRatios
                        anchors.top: aspectRatioButton.bottom
                        anchors.horizontalCenter: aspectRatioButton.horizontalCenter
                        visible: configBar.aspectRatioOpened === 1 ? true : false
                        spacing: 5 * window.scalingRatio

                        Button {
                            id: sixteenNineButton
                            text: "16:9"
                            Layout.preferredWidth: 60 * window.scalingRatio
                            font.pixelSize:  35 * window.scalingRatio * 0.5
                            font.bold: true
                            font.family: "Lato Hairline"
                            palette.buttonText: camera.aspWide === 1 ? "white" : "gray"

                            background: Rectangle {
                                width: 60 * window.scalingRatio
                                height: 35 * window.scalingRatio
                                anchors.centerIn: parent
                                color: "transparent"
                                border.width: 1 * window.scalingRatio
                                border.color: "white"
                                radius: 6 * window.scalingRatio
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
                            Layout.preferredWidth: 60 * window.scalingRatio
                            font.pixelSize:  35 * window.scalingRatio * 0.5
                            font.bold: true
                            font.family: "Lato Hairline"
                            palette.buttonText: camera.aspWide === 1 ? "gray" : "white"

                            background: Rectangle {
                                width: 60 * window.scalingRatio
                                height: 35 * window.scalingRatio
                                anchors.centerIn: parent
                                color: "transparent"
                                border.width: 1 * window.scalingRatio
                                border.color: "white"
                                radius: 6 * window.scalingRatio
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
                    icon.height: configBarDrawer.height * 0.6
                    icon.width: configBarDrawer.width * 0.08
                    icon.color: "white"
                    enabled: !window.videoCaptured

                    background: Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                    }

                    onClicked: {
                        backCamSelect.visible = true
                        optionContainer.state = "opened"
                        configBarDrawer.close()
                        window.blurView = 1
                    }
                }
            }
        }

        onClosed: {
            window.blurView = optionContainer.state === "opened" ? 1 : 0;
            configBar.opened = 0;
            configBar.aspectRatioOpened = 0;
        }
    }

    Button {
        id: configBarBtn
        icon.source: configBarDrawer.position == 0.0 ?  "icons/goDownSymbolic.svg" : ""
        icon.height: configBarDrawer.height * 0.5
        icon.width: configBarDrawer.height * 0.7
        icon.color: "white"

        visible: !mediaView.visible

        background: Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        onClicked: {
            configBarDrawer.open()
        }

        anchors {
            top: window.bottom
            topMargin: 10
            horizontalCenter: parent.horizontalCenter
        }
    }
}
