pragma Singleton
import Quickshell
import QtQuick
import qs.Services
import qs.Services.SystemInfo
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
    id: root
    readonly property var logger: LoggerService
    readonly property var mainService: MainService
    readonly property var wmImplementation: mainService.currentWM === "hyprland" ? Hypr.KeyboardLayoutImpl : mainService.currentWM === "niri" ? Niri.KeyboardLayoutImpl : null
    readonly property var layouts: wmImplementation ? wmImplementation.layouts.slice(0) : []
    readonly property string currentLayout: wmImplementation ? (wmImplementation.currentLayout || "") : ""
    readonly property bool hasMultipleLayouts: layouts.length > 1

    onWmImplementationChanged: {
        if (wmImplementation)
            wmImplementation.enabled = true;
    }
}
