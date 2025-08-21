//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
import Quickshell
import QtQuick
import QtQml
import Quickshell.Wayland
import qs.Services.Utils
import qs.Services.SystemInfo
import qs.Components
import qs.Services.WM
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Modules.Bar
import qs.Modules.OSD
import qs.Modules.Notification

ShellRoot {
    id: root

    // property var main: MainService
    readonly property var wallpaper: WallpaperService
    readonly property var systemTray: SystemTrayService
    readonly property var network: NetworkService
    readonly property var monitor: MonitorService
    readonly property var bluetooth: BluetoothService
    readonly property var audio: AudioService
    readonly property var weather: WeatherService

    // System info services
    readonly property var notifs: NotificationService
    readonly property var osd: OSDService
    readonly property var keyboardLayout: KeyboardLayoutService
    readonly property var dateTime: TimeService
    readonly property var battery: BatteryService
    readonly property var updater: UpdateService
    readonly property bool _netInit: NetworkService.ready
    readonly property var workspaces: WorkspaceService
    readonly property var sysInfo: SystemInfoService
    readonly property var media: MediaService
    readonly property var ipc: IPC
    Bar {
        id: bar
    }
    Variants {
        model: Quickshell.screens

        delegate: Toasts {
            modelData: modelData
            visible: OSDService.toastVisible
        }
    }
    Notification {}
    // Your wallpapers (unchanged)
    Variants {
        model: root.wallpaper.wallpapersArray
        WlrLayershell {
            id: layerShell
            required property var modelData
            screen: Quickshell.screens.find(s => s && s.name === layerShell.modelData.name) || null
            layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Image {
                anchors.fill: parent
                source: layerShell.modelData.wallpaper
                fillMode: {
                    switch (layerShell.modelData.mode) {
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
            }
        }
    }

    Component.onCompleted: {
        // Touch services so they instantiate and log a concise status
        if (root.osd)
            Logger.log("Shell", "OSDService loaded; DND=", root.osd.doNotDisturb);
        if (root.notifs)
            Logger.log("Shell", "NotificationService loaded");
    }
    // Live clipboard
    Connections {
        target: ClipboardService
    }
    Connections {
        target: IdleService
    }
    // Instantiate lock service and lock screen component
    readonly property var lock: LockService
    LockScreen {}
}
