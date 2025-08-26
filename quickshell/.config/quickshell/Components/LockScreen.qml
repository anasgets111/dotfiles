pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Effects
import qs.Services.Core
import qs.Services.WM

Scope {
    id: root
    readonly property var theme: ({
            base: "#1e1e2e",
            mantle: "#181825",
            crust: "#11111b",
            surface0: "#313244",
            surface1: "#45475a",
            surface2: "#585b70",
            overlay0: "#6c7086",
            overlay1: "#7f849c",
            overlay2: "#9399b2",
            subtext0: "#a6adc8",
            subtext1: "#bac2de",
            text: "#cdd6f4",
            love: "#f38ba8",
            mauve: "#cba6f7"
        })

    QtObject {
        id: lockContextProxy
        property var theme: root.theme
        // forward LockService observable state via bindings; mutators provided below
        property string passwordBuffer: LockService.passwordBuffer
        property string authState: LockService.authState
        property bool authenticating: LockService.authenticating
        function setPasswordBuffer(v) {
            LockService.passwordBuffer = v;
        }
        function submitOrStart() {
            LockService.submitOrStart();
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: LockService.locked

        WlSessionLockSurface {
            id: lockSurface
            color: "transparent"
            readonly property var screenWallpaper: WallpaperService ? WallpaperService.wallpaperFor(lockSurface.screen) : null
            readonly property bool blurDisabled: Quickshell.env("QS_DISABLE_LOCK_BLUR") === "1"
            readonly property bool hasScreen: !!lockSurface.screen
            readonly property bool isMainMonitor: !!(lockSurface.screen && MonitorService && MonitorService.activeMain === lockSurface.screen.name)
            Image {
                anchors.fill: parent
                source: WallpaperService.ready && lockSurface.screenWallpaper && lockSurface.screenWallpaper.wallpaper ? lockSurface.screenWallpaper.wallpaper : ""
                fillMode: {
                    const mode = lockSurface.screenWallpaper ? lockSurface.screenWallpaper.mode : "fill";
                    switch (mode) {
                    case "fill":
                        return Image.PreserveAspectCrop;
                    case "fit":
                        return Image.PreserveAspectFit;
                    case "stretch":
                        return Image.Stretch;
                    case "center":
                        return Image.Pad;
                    case "tile":
                        return Image.Tile;
                    default:
                        return Image.PreserveAspectCrop;
                    }
                }
                visible: lockSurface.hasScreen
                layer.enabled: !lockSurface.blurDisabled
                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 0.75
                    blurMax: 48
                    blurMultiplier: 1
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                propagateComposedEvents: true
                onEntered: lockContent.forceActiveFocus()
            }
            // one day :D
            // ScreencopyView {
            //     id: background
            //     anchors.fill: parent
            //     captureSource: surface.screen
            //     layer.enabled: true
            //     layer.effect: MultiEffect {
            //         autoPaddingEnabled: false
            //         blurEnabled: true
            //         blur: 0.75
            //         blurMax: 48
            //         blurMultiplier: 1
            //     }
            // }

            LockContent {
                id: lockContent
                // Provide theme + LockService auth state/methods
                lockContext: lockContextProxy
                lockSurface: lockSurface
            }
        }
    }
}
