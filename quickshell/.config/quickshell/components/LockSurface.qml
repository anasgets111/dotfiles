pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import "../services" as Services

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock

    property bool thisLocked
    readonly property bool locked: thisLocked && lock.locked

    property string lastWallpaper: "/home/anas/Pictures/3.jpg"

    function unlock(): void {
        lock.unlocked = true;
        animDelay.start();
    }

    Component.onCompleted: {
        thisLocked = true;
        root.updateWallpaper();
    }

    Connections {
        target: Services.WallpaperService
        function onReadyChanged() {
            root.updateWallpaper();
        }
    }
    Connections {
        target: Services.MonitorService
        function onMonitorsChanged() {
            root.updateWallpaper();
        }
    }
    onScreenChanged: root.updateWallpaper()

    function updateWallpaper() {
        if (root.screen && Services.WallpaperService.ready) {
            const wp = Services.WallpaperService.wallpaperFor(root.screen.name);
            if (wp && wp.wallpaper)
                lastWallpaper = wp.wallpaper;
        }
    }

    color: "transparent"

    Timer {
        id: animDelay
        interval: 300
        onTriggered: root.lock.locked = false
    }

    // Pre-blur pipeline (visible but offscreen)
    Item {
        id: blurPipeline
        x: -root.width
        y: -root.height
        width: root.width
        height: root.height

        // The actual image
        Image {
            id: srcImage
            anchors.fill: parent
            source: root.lastWallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }

        // Apply blur as a visible effect item
        MultiEffect {
            id: blurEffect
            anchors.fill: parent
            source: srcImage
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blurMultiplier: 1.0
            blur: 1.0
        }
    }

    // Display the blurred texture
    ShaderEffectSource {
        id: blurredSource
        anchors.fill: parent
        sourceItem: blurPipeline
        live: false
        hideSource: false
    }

    // Lock input stays above
    LockInput {
        anchors.centerIn: parent
        lock: root.lock
    }
}
