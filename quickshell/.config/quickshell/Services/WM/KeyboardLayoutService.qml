pragma Singleton
import Quickshell
import QtQuick
import qs.Services
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
    id: root

    property var mainService: MainService
    property var wmImplementation: mainService.currentWM === "hyprland" ? Hypr.KeyboardLayoutImpl : mainService.currentWM === "niri" ? Niri.KeyboardLayoutImpl : null
    property var layouts: wmImplementation ? wmImplementation.layouts.slice(0) : []
    property string currentLayout: wmImplementation ? (wmImplementation.currentLayout || "") : ""
    readonly property bool hasMultipleLayouts: layouts.length > 1

    onWmImplementationChanged: {
        if (wmImplementation)
            wmImplementation.enabled = true;
    }
}
