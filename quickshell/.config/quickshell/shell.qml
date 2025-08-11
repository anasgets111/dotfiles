//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import QtQuick
import Quickshell.Wayland
import "./services" as Services
import "./components" as Components

ShellRoot {
    id: root

    property var main: Services.MainService
    property var wallpaper: Services.WallpaperService
    property var dateTime: Services.TimeService
    property var battery: Services.BatteryService
    Components.LockScreen {}

    // Render wallpapers only when ready
    Variants {
        model: root.wallpaper.wallpapersArray

        WlrLayershell {
            id: layerShell
            required property var modelData

            screen: {
                const scr = Quickshell.screens.find(s => s.name === layerShell.modelData.name);
                return scr || null;
            }
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
}
