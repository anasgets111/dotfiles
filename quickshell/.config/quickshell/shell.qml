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

    // Per-screen pre-lock capture (persistent, invisible)
    Variants {
        model: Quickshell.screens

        WlrLayershell {
            id: capWin
            required property var modelData
            screen: modelData
            layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore

            // Keep the window mapped but tiny and transparent
            implicitWidth: 1
            implicitHeight: 1
            anchors.top: true
            anchors.left: true

            // Ensure there is content in the window
            Item {
                anchors.fill: parent

                // Your persistent capture item per screen
                Components.DesktopCapture {
                    anchors.fill: parent
                    screen: capWin.modelData
                }

                // Fully transparent rectangle to guarantee a draw call
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }
            }
        }
    }

    // The actual lock implementation
    Components.LockScreen {}

    // Your wallpapers (unchanged)
    Variants {
        model: root.wallpaper.wallpapersArray
        WlrLayershell {
            id: layerShell
            required property var modelData
            screen: Quickshell.screens.find(s => s && layerShell.modelData && s === layerShell.modelData.screen) || null
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
