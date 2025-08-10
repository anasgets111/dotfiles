//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import QtQuick
import Quickshell.Wayland
import "./services" as Services

ShellRoot {
    id: root
    property var main: Services.MainService
    property var wallpaper: Services.WallpaperService

    Variants {
        model: root.wallpaper.monitors

        WlrLayershell {
            id: layerShell
            required property var modelData

            screen: Quickshell.screens.find(s => s.name === layerShell.modelData.name)
            layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore

            // Fill the entire monitor
            width: layerShell.modelData.width
            height: layerShell.modelData.height
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
                    }
                }
            }
        }
    }

    // Log once when MainService is ready
    Connections {
        target: root.main
        function onReadyChanged() {
            if (root.main.ready) {
                console.log("=== MainService Ready ===");
                console.log("isArchBased:", root.main.isArchBased);
                console.log("currentWM:", root.main.currentWM);
                console.log("hasBrightnessControl:", root.main.hasBrightnessControl);
                console.log("hasKeyboardBacklight:", root.main.hasKeyboardBacklight);
            }
        }
    }

    // Optional: log immediately if already ready (e.g., hot reload)
    Component.onCompleted: {
        if (root.main.ready) {
            console.log("=== MainService Already Ready ===");
            console.log("isArchBased:", root.main.isArchBased);
            console.log("currentWM:", root.main.currentWM);
            console.log("hasBrightnessControl:", root.main.hasBrightnessControl);
            console.log("hasKeyboardBacklight:", root.main.hasKeyboardBacklight);
        }
    }
}
