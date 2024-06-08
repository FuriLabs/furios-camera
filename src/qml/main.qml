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
    property var gps_icon_source: ""

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
                    next_state_right: "QRC"
                }
            },
            State {
                name : "QRC"

                PropertyChanges {
                    target: window
                    next_state_left: "VideoCapture"
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
        anchors.verticalCenterOffset: -16
        height: videoFrame.height
        width: window.width

        source: camera
        autoOrientation: true
        filters: cslate.state === "QRC" ? [qrCodeComponent.qrcode] : []

        Rectangle {
            id: focusPointRect
            border {
                width: 3
                color: "#000000"
            }

            color: "transparent"
            radius: 90
            width: 80
            height: 80
            visible: false

            Timer {
                id: visTm
                interval: 500; running: false; repeat: false
                onTriggered: focusPointRect.visible = false
            }
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
            focusMode: Camera.FocusMacro
            focusPointMode: Camera.FocusPointCustom
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

                if (settings.hideTimerInfo == 0) {
                    tmDrawer.open()
                }

                if (mediaView.index < 0) {
                    mediaView.folder = StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/droidian-camera"
                }
            }

            onImageSaved: {
                if (settings.gpsOn === 1 ) {
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
                                            "/droidian-camera/video" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmsszzz") + ".mkv"

        Component.onCompleted: {
            fileManager.createDirectory("/Videos/droidian-camera");
        }

        property var backends: [
            {
                front: "gst-pipeline: droidcamsrc mode=2 camera-device=1 ! video/x-raw ! videoconvert ! qtvideosink",
                frontRecord: "gst-pipeline: droidcamsrc camera_device=1 mode=2 ! tee name=t t. ! queue ! video/x-raw, width=" + camera.viewfinder.resolution.width + ", height=" + camera.viewfinder.resolution.height + " ! videoconvert ! videoflip video-direction=2 ! qtvideosink t. ! queue ! video/x-raw, width=" + camera.viewfinder.resolution.width + ", height=" + camera.viewfinder.resolution.height + " ! videoconvert ! videoflip video-direction=auto ! jpegenc ! mkv. autoaudiosrc ! queue ! audioconvert ! droidaenc ! mkv. matroskamux name=mkv ! filesink location=" + outputPath,
                back: "gst-pipeline: droidcamsrc mode=2 camera-device=" + camera.deviceId + " ! video/x-raw ! videoconvert ! qtvideosink",
                backRecord: "gst-pipeline: droidcamsrc camera_device=" + camera.deviceId + " mode=2 ! tee name=t t. ! queue ! video/x-raw, width=" + camera.viewfinder.resolution.width + ", height=" + camera.viewfinder.resolution.height + " ! videoconvert ! qtvideosink t. ! queue ! video/x-raw, width=" + camera.viewfinder.resolution.width + ", height=" + camera.viewfinder.resolution.height + " ! videoconvert ! videoflip video-direction=auto ! jpegenc ! mkv. autoaudiosrc ! queue ! audioconvert ! droidaenc ! mkv. matroskamux name=mkv ! filesink location=" + outputPath
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
                                            "/droidian-camera/video" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmsszzz") + ".mkv"

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
            videoBtn.rotation += 180
            shutterBtn.rotation += 180

            if (window.swipeDirection != 2){
                cslate.state = (swipeDirection == 0) ? window.next_state_left : window.next_state_right;
            }
            
            window.blurView = 0
        }
    }

    PinchArea {
        id: pinchArea
        width: parent.width
        height: parent.height * 0.85
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

            onPressed: {
                startX = mouse.x
                startY = mouse.y
            }

            onReleased: {
                var deltaX = mouse.x - startX
                var deltaY = mouse.y - startY

                if (Math.abs(deltaX) > Math.abs(deltaY)) {
                    if (deltaX > 0 && window.next_state_left != "Empty") {
                        window.blurView = 1
                        window.swipeDirection = 0
                        swappingDelay.start()
                    } else if (deltaX < 0 && window.next_state_right != "Empty") {
                        window.blurView = 1
                        videoBtn.rotation += 180
                        shutterBtn.rotation += 180
                        window.swipeDirection = 1
                        swappingDelay.start()
                    }
                } else {
                    camera.focus.customFocusPoint = Qt.point(mouse.x / dragArea.width, mouse.y / dragArea.height)
                    camera.focus.focusMode = Camera.FocusMacro
                    focusPointRect.width = 60
                    focusPointRect.height = 60
                    focusPointRect.visible = true
                    focusPointRect.x = mouse.x - (focusPointRect.width / 2)
                    focusPointRect.y = mouse.y - (focusPointRect.height / 2)
                    visTm.start()
                    camera.searchAndLock()
                }
            }
        }

        onPinchUpdated: {
            camZoom.zoom = pinch.scale * camZoom.zoomFactor
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
                id: camSwitchBtn

                height: width
                Layout.alignment: Qt.AlignHCenter
                icon.name: "camera-switch-symbolic"
                icon.height: 40
                icon.width: 40
                icon.color: "white"
                visible: camera.position !== Camera.UnspecifiedPosition && !window.videoCaptured

                background: Rectangle {
                    anchors.fill: parent
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
                    delayTime.visible = false
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

            Button {
                id: aspectRatioButton
                Layout.preferredWidth: 60
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignHCenter
                palette.buttonText: "white"

                font.pixelSize: 14
                font.bold: true
                text: camera.aspWide ? "16:9" : "4:3"

                visible: !window.videoCaptured

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 2
                    border.color: "white"
                    radius: 8
                }

                onClicked: {
                    if (!camera.aspWide) {
                        drawer.close()
                        camera.aspWide = 1;
                        camera.imageCapture.resolution = camera.firstSixteenNineResolution
                    } else {
                        drawer.close()
                        camera.aspWide = 0;
                        camera.imageCapture.resolution = camera.firstFourThreeResolution
                    }
                }
            }

            Button {
                id: gpsDataSwitch

                icon.source: "icons/gps.svg"
                icon.width: 60
                icon.height: 50
                icon.color: "white"

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                onClicked: {
                    settings.gpsOn = settings.gpsOn === 1 ? 0 : 1;

                    if (settings.gpsOn === 1) {
                        fileManager.turnOnGps();
                    } else {
                        fileManager.turnOffGps();
                        window.gps_icon_source = "";
                    }
                }

                Text {
                    text: settings.gpsOn === 1 ? "" : "\u2718"
                    color: "white"
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -12
                    font.pixelSize: 32
                    font.bold: true
                    style: Text.Outline;
                    styleColor: "black"
                    bottomPadding: 9
                }
            }

            Button {
                id: soundButton

                height: width
                Layout.alignment: Qt.AlignHCenter
                icon.name: settings.soundOn === 1 ? "audio-volume-high-symbolic" : "audio-volume-muted-symbolic"
                icon.height: 40
                icon.width: 40
                icon.color: "white"

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                onClicked: {
                    settings.soundOn = settings.soundOn === 1 ? 0 : 1;
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

            Tumbler {
                id: delayTime

                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.9
                model: 60

                delegate: Text {
                    text: modelData == 0 ? "Off" : modelData
                    color: "white"
                    font.bold: true
                    font.pixelSize: 42
                    horizontalAlignment: Text.AlignHCenter
                    style: Text.Outline;
                    styleColor: "black"
                    opacity: 0.4 + Math.max(0, 1 - Math.abs(Tumbler.displacement)) * 0.6
                }
            }

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
        id: mainBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 35
        height: 80
        width: parent.width
        visible: !mediaView.visible

        Rectangle {
            id: menuBtnFrame
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            height: 60
            width: 60
            color: "transparent"
            anchors.rightMargin: 50
            anchors.bottomMargin: 5
            visible: !window.videoCaptured

            Button {
                id: menuBtn
                anchors.fill: parent
                icon.name: "open-menu-symbolic"
                icon.color: "white"
                icon.width: 35
                icon.height: 35
                enabled: !window.videoCaptured
                visible: drawer.position == 0.0 && optionContainer.state == "closed"

                background: Rectangle {
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

        Rectangle {
            id: reviewBtnFrame
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            height: 45
            radius: 5
            width: 45
            anchors.leftMargin: 50
            anchors.bottomMargin: 10
            enabled: !window.videoCaptured && cslate.state != "QRC"
            visible: !window.videoCaptured && cslate.state != "QRC"

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
            id: videoBtnFrame
            height: 70
            width: 70
            radius: 35
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            visible: cslate.state == "VideoCapture"

            Button {
                id: videoBtn
                anchors.fill: parent
                enabled: cslate.state == "VideoCapture" && !mediaView.visible

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

        Rectangle {
            id: shutterBtnFrame
            height: 70
            width: 70
            radius: 70
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter

            visible: cslate.state == "PhotoCapture"

            Button {
                id: shutterBtn
                anchors.fill: parent.fill
                anchors.centerIn: parent
                enabled: cslate.state == "PhotoCapture" && !mediaView.visible
                icon.name: preCaptureTimer.running ? "" :
                                optionContainer.state == "opened" && delayTime.currentIndex < 1 ||
                                optionContainer.state == "opened" && backCamSelect.visible ? "window-close-symbolic" :
                                cslate.state == "VideoCapture" ? "media-playback-stop-symbolic" : "shutter"

                icon.source: preCaptureTimer.running ? "" :
                                    optionContainer.state == "opened" && delayTime.currentIndex > 0 ? "icons/timer.svg" : "icons/shutter.svg"

                icon.color: "white"
                icon.width: shutterBtnFrame.width
                icon.height: shutterBtnFrame.height

                text: preCaptureTimer.running ? countDown : ""

                palette.buttonText: "red"

                font.pixelSize: 64
                font.bold: true
                visible: true

                background: Rectangle {
                    anchors.centerIn: parent
                    width: shutterBtnFrame.width
                    height: shutterBtnFrame.height
                    color: "black"
                    radius: shutterBtnFrame.radius
                }

                onClicked: {
                    pinchArea.enabled = true
                    window.blurView = 0
                    shutterBtn.rotation += optionContainer.state == "opened" ? 0 : 180

                    if (optionContainer.state == "opened" && delayTime.currentIndex > 0 && !backCamSelect.visible) {
                        optionContainer.state = "closed"
                        countDown = delayTime.currentIndex
                        preCaptureTimer.start()
                    } else if (optionContainer.state == "opened" && delayTime.currentIndex < 1 ||
                                optionContainer.state == "opened" && backCamSelect.visible) {
                        optionContainer.state = "closed"
                    } else {
                        camera.imageCapture.capture()
                    }
                }

                onPressAndHold: {
                    optionContainer.state = "opened"
                    pinchArea.enabled = false
                    window.blurView = 1
                    shutterBtn.rotation = 0
                    delayTime.visible = true
                    backCamSelect.visible = false
                }

                Behavior on rotation {
                    RotationAnimation {
                        duration: (shutterBtn.rotation >= 180 && optionContainer.state == "opened") ? 0 : 250
                        direction: RotationAnimation.Counterclockwise
                    }
                }
            }
        }

        Rectangle {
            id: qrcBtnFrame
            height: 70
            width: 70
            radius: 70
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            visible: cslate.state == "QRC"

            Button {
                id: qrcButton
                anchors.fill: qrcBtnFrame
                anchors.centerIn: parent
                enabled: cslate.state == "QRC"

                icon.name: qrCodeComponent.newURLDetected ? "qrc" : ""

                icon.source: qrCodeComponent.newURLDetected ? "icons/qrc.svg" : ""

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
                    QRCodeHandler.openUrlInFirefox(qrCodeComponent.urlResult)
                }
            }
        }

        Button {
            id: readerResultButton

            text: qrCodeComponent.urlResult
            visible: cslate.state === "QRC" && qrCodeComponent.newURLDetected

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 100
            anchors.horizontalCenter: parent.horizontalCenter

            onClicked: QRCodeHandler.openUrlInFirefox(qrCodeComponent.urlResult)

            background: Rectangle {
                implicitWidth: 100
                implicitHeight: 40
                color: "white"
                radius: 10
            }
        }

        Rectangle {
            id: stateContainer
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
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
                                videoBtn.rotation += 180
                                shutterBtn.rotation += 180
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
                        text: "QR Code"
                        font.bold: true
                        color: cslate.state == "QRC" ? "orange" : "lightgray"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (cslate.state != "QRC") {
                                optionContainer.state = "closed"
                                window.swipeDirection = 2
                                cslate.state = "QRC"
                                window.blurView = 1
                                videoBtn.rotation += 180
                                shutterBtn.rotation += 180
                                swappingDelay.start()
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
    }

    QrCode {
        id: qrCodeComponent
        viewfinder: viewfinder
    }

    Rectangle {
        id: statusBar
        width: window.width
        anchors.bottom: parent.bottom
        height: 33
        color: "black"
        visible: !mediaView.visible

        RowLayout {
            spacing: -10
            anchors.left: parent.left

            Button {
                id: flashStatus
                icon.name: flashButton.state === "flashOn" || flashButton.state === "flashAuto" ? "thunderbolt-symbolic" : ""
                icon.height: 15
                icon.width: 15
                icon.color: "white"

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                Text {
                    anchors.centerIn: flashStatus
                    anchors.horizontalCenterOffset: 7
                    anchors.verticalCenterOffset: 5
                    text: flashButton.state === "flashAuto" ? "A" : ""
                    color: "white"
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            Button {
                id: soundStatus
                icon.name: settings.soundOn === 1 ? "audio-volume-high-symbolic" : ""
                icon.height: 15
                icon.width: 15
                icon.color: "white"

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }
            }

            Button {
                id: gpsStatus
                icon.source: gps_icon_source
                icon.height: 15
                icon.width: 20
                icon.color: "white"

                background: Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                Connections {
                    target: fileManager

                    function onGpsDataReady() {
                        window.gps_icon_source = "icons/gps.svg";
                    }
                }
            }
        }
    }
}