pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Effects
import Quickshell.Services.Pam
import qs.Services.Core as Core
import qs.Services.WM as WM
import qs.Services.SystemInfo

// SystemInfo already imported without alias for TimeService/WeatherService

Scope {
    id: root
    property var logger: LoggerService
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
    property var snapshotMonitorNames: []
    // Use SystemInfo.TimeService for date/time
    property string passwordBuffer: ""
    property string authState: ""
    function currentMonitorNames() {
        const monitors = WM.MonitorService;
        if (!(monitors && monitors.ready))
            return [];
        const arr = monitors.monitorsModelToArray ? monitors.monitorsModelToArray() : [];
        return arr.map(m => m && m.name).filter(n => !!n);
    }
    Connections {
        target: Core.LockService
        function onLockedChanged() {
            const names = root.currentMonitorNames();
            root.snapshotMonitorNames = Core.LockService.locked ? names : [];
        }
    }

    PamContext {
        id: pamAuth
        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.passwordBuffer);
                root.passwordBuffer = "";
                root.logger.log("LockScreen", "PAM response sent; buffer cleared");
            }
        }
        onCompleted: res => {
            if (res === PamResult.Success) {
                root.passwordBuffer = "";
                Core.LockService.locked = false;
                return;
            }
            if (res === PamResult.Error)
                root.authState = "error";
            else if (res === PamResult.MaxTries)
                root.authState = "max";
            else if (res === PamResult.Failed)
                root.authState = "fail";
            authStateResetTimer.restart();
        }
    }
    Timer {
        id: authStateResetTimer
        interval: 1000
        onTriggered: root.authState = ""
    }

    // Pass logger to WeatherService for unified logs
    Component.onCompleted: {
        try {
            if (root.logger && WeatherService) {
                WeatherService.logger = root.logger;
            }
        } catch (e) {}
    }

    WlSessionLock {
        id: sessionLock
        locked: Core.LockService.locked

        WlSessionLockSurface {
            id: lockSurface
            color: "transparent"
            readonly property var screenWallpaper: Core.WallpaperService ? Core.WallpaperService.wallpaperFor(lockSurface.screen) : null
            readonly property bool blurDisabled: Quickshell.env("QS_DISABLE_LOCK_BLUR") === "1"
            readonly property bool hasScreen: !!lockSurface.screen
            readonly property bool isLastMonitorBySnapshot: {
                const s = lockSurface.screen;
                if (!s)
                    return false;
                const names = (root.snapshotMonitorNames && root.snapshotMonitorNames.length) ? root.snapshotMonitorNames : root.currentMonitorNames();
                if (!names || names.length === 0)
                    return true;
                const idx = names.indexOf(s.name);
                return idx >= 0 && idx === names.length - 1;
            }
            Image {
                anchors.fill: parent
                source: Core.WallpaperService && Core.WallpaperService.ready && lockSurface.screenWallpaper && lockSurface.screenWallpaper.wallpaper ? lockSurface.screenWallpaper.wallpaper : ""
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
                id: panel
                ctx: root
                lockSurface: lockSurface
                pamAuth: pamAuth
            }
        }
    }
}
