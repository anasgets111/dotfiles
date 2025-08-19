//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
import Quickshell
import QtQuick
import QtQml
import Quickshell.Wayland
import qs.Services
import qs.Services.SystemInfo
import qs.Components
import qs.Services.WM as WM
import qs.Services.Core as Core

ShellRoot {
    id: root

    // property var main: MainService
    property var wallpaper: Core.WallpaperService
    property var systemTray: Core.SystemTrayService
    property var network: Core.NetworkService
    property var monitor: WM.MonitorService
    // System info services
    property var notifs: NotificationService
    property var osd: OSDService
    property var keyboardLayout: WM.KeyboardLayoutService
    property var dateTime: TimeService
    // property var battery: BatteryService
    readonly property bool _netInit: Core.NetworkService.ready

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
            console.log("[Shell] OSDService loaded; DND=", root.osd.doNotDisturb);
        if (root.notifs)
            console.log("[Shell] NotificationService loaded");
    }
    // Live clipboard
    Connections {
        target: Core.ClipboardService
    }
    Connections {
        target: Core.IdleService
    }
    // Instantiate lock service and lock screen component
    property var lock: Core.LockService
    LockScreen {}
}
