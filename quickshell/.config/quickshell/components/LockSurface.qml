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

    // Source content to be blurred
    Item {
        id: wallpaperContainer
        anchors.fill: parent

        // Crucial: render this item as a layer and apply the effect there
        layer.enabled: true
        layer.effect: MultiEffect {
            // No source needed when using layer.effect; it's implicit
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blurMultiplier: 2.0
            blur: root.locked ? 1.0 : 0.0

            Behavior on blur {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }
        }

        Image {
            id: wallpaperImage
            anchors.fill: parent
            source: root.lastWallpaper
            fillMode: Image.PreserveAspectCrop
        }
    }

    // Lock input stays above
    LockInput {
        anchors.centerIn: parent
        lock: root.lock
    }
}
