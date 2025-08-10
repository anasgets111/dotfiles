pragma Singleton
import QtQuick
import Quickshell
import "../" as Services

Singleton {
    id: monitorService
    property var mainService: Services.MainService
    property var monitors: []

    Component.onCompleted: {
        if (mainService.currentWM === "hyprland")
            impl = HyprMonitorService;
        else if (mainService.currentWM === "niri")
            impl = NiriMonitorService;

        monitors = impl.monitors;
        impl.monitorsChanged.connect(() => monitors = impl.monitors);
    }

    function setResolution(name, width, height) {
        impl.setResolution(name, width, height);
    }

    function setScale(name, scale) {
        impl.setScale(name, scale);
    }

    function setOrientation(name, orientation) {
        impl.setOrientation(name, orientation);
    }
}
