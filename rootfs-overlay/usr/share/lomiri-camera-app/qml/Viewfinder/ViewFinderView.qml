/*
 * Copyright 2014 Canonical Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.12
import QtQuick.Window 2.2
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtMultimedia 5.9
import CameraApp 0.1
//import QtGraphicalEffects 1.0
import Lomiri.Content 1.3

import "../components"

FocusScope {
    id: viewFinderView

    property bool overlayVisible: true
    property bool optionValueSelectorVisible: false
    property bool touchAcquired: viewFinderOverlay.touchAcquired || camera.videoRecorder.recorderState == CameraRecorder.RecordingState
    property bool inView
    property alias captureMode: camera.captureMode
    property alias finderOverlay: viewFinderOverlay
    property real aspectRatio: viewFinder.sourceRect.height != 0 ? viewFinder.sourceRect.width / viewFinder.sourceRect.height : 1.0
    property bool readOnly : false
    property var cameraFilters : []
    property string recentlyScannedTag: ""
    signal photoTaken(string filePath)
    signal videoShot(string filePath)

    Connections {
        target: viewFinderOverlay
        onStatusChanged: decideCameraState()
    }
    Connections {
        target: Qt.application
        onActiveChanged: if (Qt.application.active && camera.failedToConnect) decideCameraState()
    }

    function decideCameraState() {
        if (viewFinderOverlay.status == Loader.Ready) {
            camera.cameraState = Camera.ActiveState;
        }
    }

    property Camera camera: Camera {
        id: camera
        captureMode: Camera.CaptureStillImage
        cameraState: Camera.UnloadedState
        StateSaver.properties: "captureMode, position"
        property bool failedToConnect: false
        // m52xq: the libcamera camera in use (camera.position stays unknown with libcamerasrc) and its mounting:
        // libcamerasrc reports no rotation; with the window turned by Lomiri the main sensor needs 270 and the front
        // one 90 (anti-clockwise VideoOutput terms) plus the window angle, neither of them is mirrored (tried on the phone)
        property bool m52xqFront: false
        readonly property int m52xqSensorAngle: camera.orientation !== 0 ? camera.orientation : (m52xqFront ? 90 : 270)

        // m52xq: tap to focus. The software autofocus lives in the camera source (m52xqcamsrc: contrast search with
        // the lens of the rear camera on the frames that pass through it); the tap is handed over as a file with
        // the point in frame coordinates (0..1). Needs QML_XHR_ALLOW_FILE_WRITE=1 in the launcher.
        function m52xqFocusAt(u, v) {
            if (camera.m52xqFront) {
                return;
            }
            var xhr = new XMLHttpRequest();
            xhr.open("PUT", "file:///run/user/10000/m52xq-focus");
            xhr.send(u.toFixed(4) + " " + v.toFixed(4));
        }

        function manualFocus(x, y) {
            // the viewfinder item is turned (rotation) and cropped: through the item to the frame
            var normalizedPoint = viewFinder.mapPointToSourceNormalized(viewFinder.mapFromItem(viewFinderOverlay, x, y));
            if (normalizedPoint.x >= 0.0 && normalizedPoint.x <= 1.0 &&
                normalizedPoint.y >= 0.0 && normalizedPoint.y <= 1.0) {
                viewFinderOverlay.showFocusRing(x, y);
                m52xqFocusAt(normalizedPoint.x, normalizedPoint.y);
                autoFocusTimer.restart();
                focus.focusMode = Camera.FocusAuto;
                focus.customFocusPoint = normalizedPoint;
                focus.focusPointMode = Camera.FocusPointCustom;

                searchAndLock();
            }
        }

        function autoFocus() {
            unlock();

            focus.focusMode = Camera.FocusContinuous;
            focus.focusPointMode = Camera.FocusPointAuto;
        }

        property var autoFocusTimer: Timer {
            interval: 5000
            onTriggered: camera.autoFocus();
        }

        focus {
            focusMode: Camera.FocusContinuous
            focusPointMode: Camera.FocusPointAuto
        }

        property AdvancedCameraSettings advanced: AdvancedCameraSettings {
            id: advancedCamera
            camera: camera
        }

        /* Use only digital zoom for now as it's what phone cameras mostly use.
               TODO: if optical zoom is available, maximumZoom should be the combined
               range of optical and digital zoom and currentZoom should adjust the two
               transparently based on the value. */
        // m52xq: camerabin's digital zoom crops with videocrop, which crashed (SIGSEGV) on the libcamerasrc frames.
        // classic в8: the camera source (m52xqcamsrc) zooms itself: it crops the middle of every frame and scales it up
        // (viewfinder, photo, video). The factor 1 + currentZoom (up to 4x) goes to it as the file /run/user/10000/m52xq-zoom;
        // written at the start too (1.000), so a factor left by an earlier run is never applied.
        property real currentZoom: 0.0
        readonly property real maximumZoom: 3.0
        function m52xqWriteZoom() {
            var xhr = new XMLHttpRequest();
            xhr.open("PUT", "file:///run/user/10000/m52xq-zoom");
            xhr.send((1.0 + currentZoom).toFixed(3));
        }
        onCurrentZoomChanged: m52xqWriteZoom()
        Component.onCompleted: m52xqWriteZoom()
        property bool switchInProgress: false
        property bool photoCaptureInProgress: false
        property bool timedCaptureInProgress: false

        onPhotoCaptureInProgressChanged: {
            if (main.contentExportMode && camera.photoCaptureInProgress) {
                viewFinderExportConfirmation.photoCaptureStarted();
            }
        }

        imageCapture {
            onImageCaptured: {
                if (camera.photoCaptureInProgress) {
                    if (photoRollHint.necessary && !main.transfer) photoRollHint.enable();
                    camera.photoCaptureInProgress = false;
                }
            }

            onCaptureFailed: {
                console.log("Image capture failed for request " + requestId + ": " + message);
                camera.photoCaptureInProgress = false;
                viewFinderOverlay.visible = true;
                PopupUtils.open(captureFailedDialogComponent);
            }

            onImageSaved: {
                if(!viewFinderOverlay.settings.hasEXIF) {
                    // TODO: make this operation asynchronous.
                    postProcessOperations.deleteEXIFdata(path);
                }

                if(viewFinderOverlay.settings.dateStampImages && !main.contentExportMode) {
                    postProcessOperations.addDateStamp(path,
                                                       viewFinderOverlay.settings.dateStampFormat,
                                                       viewFinderOverlay.settings.dateStampColor,
                                                       viewFinderOverlay.settings.dateStampOpacity,
                                                       viewFinderOverlay.settings.dateStampAlign);
                }

                // TODO: make it so that asynchronous operations signals to us
                // on finished and only then proceed to the code below.

                if (main.contentExportMode)
                    viewFinderExportConfirmation.mediaPath = path;

                viewFinderView.photoTaken(path);
                metricPhotos.increment();
                console.log("Picture saved as " + path);
                // m52xq: denoise / sharpen / quality 92 in the background (as Megapixels does)
                if (!main.contentExportMode)
                    application.m52xqPostprocess(path);
            }
        }

        videoRecorder {
            // m52xq: no container was set: the file got the extension ".ubports" (players / Gallery did not open it);
            // MP4 (H.264 + AAC, what encodebin made anyway) gives ".mp4"
            mediaContainer: "video/quicktime, variant=(string)iso"
            videoCodec: "video/x-h264"
            audioCodec: "audio/mpeg, mpegversion=(int)4"
            onRecorderStateChanged: {
                if (videoRecorder.recorderState === CameraRecorder.StoppedState) {
                    metricVideos.increment()
                    // "actualLocation" is a URL string. Get only path from it
                    // before passing on.
                    var videoPath = videoRecorder.actualLocation.replace("file://", "");
                    viewFinderView.videoShot(videoPath);
                    if (main.contentExportMode) {
                        viewFinderExportConfirmation.mediaPath = videoRecorder.actualLocation
                    } else if (photoRollHint.necessary) {
                        photoRollHint.enable();
                    }
                }
            }
            onErrorCodeChanged: {
                if (videoRecorder.errorCode !== CameraRecorder.NoError) {
                    PopupUtils.open(captureFailedDialogComponent);
                }
            }
        }
    }

    Item {
        id: viewFinderSwitcher
        anchors.fill: parent
        visible: true //!viewFinderSwitcherBlurred.visible

        ShaderEffectSource {
            id: viewFinderGrab
            rotation: (360 - viewFinder.rotation) % 360	// m52xq: the snapshot shown during a camera switch is turned like the viewfinder (it lay on its side in portrait); it is mirrored by its Y flip, so the opposite angle
            live: false
            sourceItem: viewFinder

            onScheduledUpdateCompleted: {
                if (camera.switchInProgress) {
                    // FIXME: hack to make viewFinder invisible
                    // 'viewFinder.visible = false' prevents the camera switching
                    viewFinder.width = 1;
                    viewFinder.height = 1;
                    camera.cameraState = Camera.LoadedState;
                    // m52xq: switch the libcamera camera, then another deviceId makes camerabin build its source again
                    camera.m52xqFront = !camera.m52xqFront;
                    application.selectLibcamera(camera.m52xqFront);
                    var cams = QtMultimedia.availableCameras;
                    for (var c = 0; c < cams.length; c++) {
                        if (cams[c].deviceId !== camera.deviceId) {
                            camera.deviceId = cams[c].deviceId;
                            break;
                        }
                    }
                    decideCameraState();
                    viewFinderSwitcherRotation.angle = 180;
                }
            }
            transform: Rotation {
                origin.x: viewFinderGrab.width/2
                origin.y: viewFinderGrab.height/2
                axis.x: 0; axis.y: 1; axis.z: 0
                angle: 180
            }
        }

        transform: [
            Scale {
                id: viewFinderSwitcherScale
                origin.x: viewFinderSwitcher.width/2
                origin.y: viewFinderSwitcher.height/2
                xScale: 1
                yScale: xScale
            },
            Rotation {
                id: viewFinderSwitcherRotation
                origin.x: viewFinderSwitcher.width/2
                origin.y: viewFinderSwitcher.height/2
                axis.x: 0; axis.y: 1; axis.z: 0
                angle: 0
            }
        ]


        SequentialAnimation {
            id: viewFinderSwitcherAnimation

            SequentialAnimation {
                ParallelAnimation {
                    LomiriNumberAnimation {target: viewFinderSwitcherScale; property: "xScale"; from: 1.0; to: 0.8; duration: LomiriAnimation.BriskDuration ; easing: LomiriAnimation.StandardEasing}
                    LomiriNumberAnimation {
                        target: viewFinderSwitcherRotation
                        property: "angle"
                        from: 180
                        to: 90
                        duration: LomiriAnimation.BriskDuration
                        easing: LomiriAnimation.StandardEasing
                    }
                }
                ScriptAction {
                    script: {
                        viewFinder.width = Qt.binding(function () {return viewFinder.feedTurned ? viewFinderSwitcher.height : viewFinderSwitcher.width;});
                        viewFinder.height = Qt.binding(function () {return viewFinder.feedTurned ? viewFinderSwitcher.width : viewFinderSwitcher.height;});
                    }
                }
                PropertyAction { target: viewFinderGrab; property: "visible"; value: false }
                ParallelAnimation {
                    LomiriNumberAnimation {target: viewFinderSwitcherScale; property: "xScale"; from: 0.8; to: 1.0; duration: LomiriAnimation.BriskDuration; easing: LomiriAnimation.StandardEasingReverse}
                    LomiriNumberAnimation {
                        target: viewFinderSwitcherRotation
                        property: "angle"
                        from: 90
                        to: 0
                        duration: LomiriAnimation.BriskDuration
                        easing: LomiriAnimation.StandardEasingReverse
                    }
                }
            }
        }

        VideoOutput {
            id: viewFinder

            // m52xq: Qt 5 VideoOutput turned by its own "orientation" fits the frame into a rectangle with swapped
            // sides (a squeezed picture that did not reach the bottom): orientation stays 0 and the item itself is
            // turned by feedAngle, with width / height swapped for 90 / 270
            readonly property bool feedTurned: feedAngle === 90 || feedAngle === 270
            anchors.centerIn: parent
            width: feedTurned ? parent.height : parent.width
            height: feedTurned ? parent.width : parent.height
            rotation: (360 - feedAngle) % 360	// "orientation" is anti-clockwise, "rotation" clockwise
            orientation: 0
            source: camera
            filters: cameraFilters
            // m52xq: with PreserveAspectFit the frame came out ~2.6 times too small (a strip): fill the viewfinder
            fillMode: VideoOutput.PreserveAspectCrop

            // m52xq: at start the window gets its final size only after the first frames and the feed stayed
            // distorted until something moved (a swipe): lay the frame out again once the sizes settle
            function m52xqRelayout() {
                fillMode = VideoOutput.Stretch;
                fillMode = VideoOutput.PreserveAspectCrop;
            }
            onWidthChanged: m52xqRelayoutTimer.restart()
            onHeightChanged: m52xqRelayoutTimer.restart()
            onSourceRectChanged: m52xqRelayoutTimer.restart()
            Timer {
                id: m52xqRelayoutTimer
                interval: 300
                onTriggered: viewFinder.m52xqRelayout()
            }
            Connections {
                target: camera
                function onCameraStatusChanged() { m52xqRelayoutTimer.restart(); }
            }
            opacity: ((main.contentExportMode && viewFinderExportConfirmation.waitingForPictureCapture) ||
                      (!main.contentExportMode && camera.photoCaptureInProgress && !camera.imageCapture.ready))
                      ? 0.1 : 1.0

            property int feedAngle: {
                // Camera-app uses X-Lomiri-Rotates-Window-Contents, which means we're always in
                // native orientation. Thus, Screen.orientation isn't used here.

                // m52xq: libcamerasrc reports no sensor rotation (0), the sensors are mounted turned by 90 degrees
                // (m52xq-virtualcam rotates them clockwise): a sideways viewfinder
                // m52xq: the window follows the screen, the sensor stays with the device: turn back by the device angle
                // (the front feed turns the other way: its window angle is subtracted - tried on the phone)
                var sensorAngle = camera.m52xqFront
                        ? (camera.m52xqSensorAngle + 360 - main.m52xqWindowAngle) % 360
                        : (camera.m52xqSensorAngle + main.m52xqWindowAngle) % 360;
                // m52xq: the front feed is not mirrored (m52xq-virtualcam: front counterclockwise, no flip): its own
                // angle as it is, the UT "360 - angle" for mirrored front sensors turned it sideways
                return sensorAngle;
            }

            transform: Rotation {
                origin.x: viewFinder.width / 2
                origin.y: viewFinder.height / 2
                axis.x: 0; axis.y: 1; axis.z: 0
                angle: application.desktopMode ? 180 : 0
            }
        }

        /* Convenience item tracking the real position and size of the real video feed.
           Having this helps since these values depend on a lot of rules:
           - the feed is automatically scaled to fit the viewfinder
           - the viewfinder might apply a rotation to the feed, depending on device orientation
           - the resolution and aspect ratio of the feed changes depending on the active camera
           The item is also separated in a component so it can be unit tested.
         */
        ViewFinderGeometry {
            id: viewFinderGeometry
            anchors.centerIn: parent

            cameraResolution: camera.viewfinder.resolution
            viewFinderHeight: viewFinderSwitcher.height
            viewFinderWidth: viewFinderSwitcher.width
            viewFinderOrientation: viewFinder.feedAngle
        }

        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            width: viewFinderGeometry.width
            height: viewFinderGeometry.height
            visible: viewFinderOverlay.settings != undefined && viewFinderOverlay.settings.gridEnabled
            source: "GridLines.qml"
            asynchronous: true
        }

        Connections {
            target: viewFinderView
            onInViewChanged: if (!viewFinderView.inView) viewFinderOverlay.controls.cancelTimedShoot()
        }

        TimedShootFeedback {
            id: timedShootFeedback
            anchors.fill: parent
            automaticOrientation: false
            customRotation: main.staticRotationAngle
        }

        ShootFeedback {
            id: shootFeedback
            anchors.fill: parent
        }
    }


    PhotoRollHint {
        id: photoRollHint
        objectName: "photoRollHint"
        anchors.fill: parent
        visible: enabled

        Connections {
            target: viewFinderView
            onInViewChanged: if (!viewFinderView.inView) photoRollHint.disable()
        }
    }


    ViewFinderOverlayLoader {
        id: viewFinderOverlay

        anchors.fill: parent
        asynchronous: true
        camera: camera
        readOnly: viewFinderView.readOnly
        // m52xq: photo rotation (tried on the phone): main camera device rotation + 270 (in landscape the frame is
        // upright already: EXIF 0), front camera 360 - device rotation + 90
        sensorOrientation: camera.m52xqFront ? 90 : 270
        opacity: status == Loader.Ready && overlayVisible && !photoRollHint.enabled ? 1.0 : 0.0
        readyForCapture: main.contentExportMode &&
                         viewFinderExportConfirmation.waitingForPictureCapture ? false : camera.imageCapture.ready

        Behavior on opacity {
            enabled: !photoRollHint.enabled
            LomiriNumberAnimation {duration: LomiriAnimation.SnapDuration}
        }

        // Tapping anywhere on the screen should not trigger any camera
        // controls while PhotoRoll hint is visible 
        MouseArea {
            anchors.fill: parent
            enabled: photoRollHint.visible
        }
    }

    Loader {
        id: viewFinderExportConfirmationLoader
        asynchronous: true
        anchors.fill: parent
        sourceComponent: viewFinderExportConfirmationComp
    }

    PostProcessOperations {
        id: postProcessOperations
    }

    property alias viewFinderExportConfirmation: viewFinderExportConfirmationLoader.item

    Component {
        id: viewFinderExportConfirmationComp
        ViewFinderExportConfirmation {
            id: viewFinderExportConfirmation
            anchors.fill: parent

            isVideo: main.transfer && main.transfer.contentType == ContentType.Videos
            geometry: viewFinderGeometry

            onShowRequested: {
                viewFinder.visible = false;
                viewFinderOverlay.visible = false;
                visible = true;
            }

            onHideRequested: {
                viewFinder.visible = true;
                viewFinderOverlay.visible = true;
                visible = false;
            }
        }
    }

    Component {
         id: captureFailedDialogComponent
         Dialog {
             id: captureFailedDialog
             objectName: "captureFailedDialog"
             title: i18n.tr("Capture failed")

             // If we are capturing to an SD card the problem can be a broken card, otherwise it is probably a
             // crash in the driver and a reboot might fix things.
             text: StorageLocations.removableStorageLocation && viewFinderOverlay.settings.preferRemovableStorage ?
                   i18n.tr("Replacing your external media, formatting it, or restarting the device might fix the problem.") :
                   i18n.tr("Restarting your device might fix the problem.")

             Button {
                 text: i18n.tr("Cancel")
                 onClicked: PopupUtils.close(captureFailedDialog)
             }
         }
    }
}
