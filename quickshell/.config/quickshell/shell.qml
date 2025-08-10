//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import QtQuick
import "./services" as Services

ShellRoot {
    id: root

    // Force singleton instantiation
    property var main: Services.MainService

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
