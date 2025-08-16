pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import Quickshell.Wayland
import qs.Services as Services

WlSessionLockSurface {
    id: root
    required property WlSessionLock lock
    // Track ScreencopyView content for visibility logic
    // No screenshot caching, use live ScreencopyView for lock background

    property string lastWallpaper: "/home/anas/Pictures/3.jpg"
    color: "transparent"
    property bool showRawScreencopy: true // for diagnostics

    ScreencopyView {
        id: screencopy
        anchors.fill: parent
        captureSource: root.screen
        live: false
        paintCursor: false
        z: 0
        visible: hasContent
        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
        }
        onHasContentChanged: {
            console.debug("[LockSurface] ScreencopyView.hasContent changed:", hasContent, "for screen:", root.screen ? (root.screen.name || root.screen) : null);
        }
    }

    // Fallback wallpaper/blur if screencopy is not available
    Image {
        id: lockWpImage
        anchors.fill: parent
        source: root.lastWallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: !screencopy.hasContent
        z: 0
        onVisibleChanged: {
            console.debug("[LockSurface] lockWpImage.visible changed:", visible);
        }
    }
    MultiEffect {
        anchors.fill: parent
        visible: !screencopy.hasContent
        source: lockWpImage
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blurMultiplier: 1.0
        blur: 1.0
        z: 1
        onVisibleChanged: {
            console.debug("[LockSurface] MultiEffect.visible changed:", visible, "(wallpaper blur)");
        }
    }

    function updateWallpaper() {
        if (root.screen && Services.WallpaperService?.ready) {
            const wp = Services.WallpaperService.wallpaperFor(root.screen);
            if (wp?.wallpaper)
                lastWallpaper = wp.wallpaper;
        }
        console.debug("[LockSurface] updateWallpaper: screen:", root.screen ? (root.screen.name || root.screen) : null, "lastWallpaper:", lastWallpaper);
    }

    Component.onCompleted: {
        updateWallpaper();
    }
    onScreenChanged: updateWallpaper()
    onVisibleChanged: {
        console.debug("[LockSurface] LockSurface.visible changed:", visible, "for screen:", root.screen ? (root.screen.name || root.screen) : null);
    }
    // Diagnostic: solid color background to confirm surface is mapped
    Rectangle {
        anchors.fill: parent
        color: "#44ff0000" // semi-transparent red
        z: -100
        visible: true
    }

    // ScreencopyView for this lock surface
    // ScreencopyView temporarily removed for diagnostics

    // Blur effect removed for diagnostics

    Image {
        id: wpImage
        anchors.fill: parent
        source: root.lastWallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: !screencopy.hasContent
        onVisibleChanged: {
            console.debug("[LockSurface] wpImage.visible changed:", visible);
        }
    }
    MultiEffect {
        anchors.fill: parent
        visible: !screencopy.hasContent
        source: wpImage
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blurMultiplier: 1.0
        blur: 1.0
        onVisibleChanged: {
            console.debug("[LockSurface] MultiEffect.visible changed:", visible, "(wallpaper blur)");
        }
    }

    // Your existing PAM-based input
    // Diagnostic: highlight LockInput area
    Rectangle {
        id: lockInputBg
        width: 400
        height: 100
        color: "#4400ff00"
        anchors.centerIn: parent
        z: 1000
        visible: true
    }
    LockInput {
        anchors.centerIn: parent
        lock: root.lock
        z: 1100
        Component.onCompleted: {
            console.debug("[LockSurface] LockInput Component.onCompleted for screen:", root.screen ? (root.screen.name || root.screen) : null);
        }
        onVisibleChanged: {
            console.debug("[LockSurface] LockInput.visible changed:", visible, "for screen:", root.screen ? (root.screen.name || root.screen) : null);
        }
        Component.onDestruction: {
            console.debug("[LockSurface] LockInput destroyed for screen:", root.screen ? (root.screen.name || root.screen) : null);
        }
    }
    // Diagnostic: topmost Rectangle to confirm stacking
    Rectangle {
        width: 40
        height: 40
        color: "#88ff00ff"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 2000
        visible: true
    }
    Component.onDestruction: {
        console.debug("[LockSurface] LockSurface destroyed for screen:", root.screen ? (root.screen.name || root.screen) : null);
    }
}
