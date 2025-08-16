//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
import Quickshell
import QtQuick
import Quickshell.Wayland
import qs.Services as Services
import qs.Components as Components

ShellRoot {
    id: root

    property var main: Services.MainService
    property var wallpaper: Services.WallpaperService
    property var systemTray: Services.SystemTrayService
    property var network: Services.NetworkService
    // property var dateTime: Services.TimeService
    // property var battery: Services.BatteryService

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
        // access network service to ensure it is instantiated and log
        if (root.network) {
            console.log("[Shell] NetworkService instance present, ready=", root.network.ready);
            try {
                root.network.dumpState();
            } catch (e) {
                console.log("[Shell] failed to call dumpState:", e);
            }
        } else {
            console.log("[Shell] NetworkService not present (null)");
        }
    }
}
