pragma Singleton
import Quickshell
import qs.Services
import qs.Services.Utils
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: service

  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.KeyboardLayoutImpl : MainService.currentWM === "niri" ? Niri.KeyboardLayoutImpl : null
  readonly property bool capsOn: Utils.capsLock
  readonly property string currentLayout: backend?.currentLayout ?? ""
  readonly property bool hasMultipleLayouts: layouts.length > 1
  readonly property string layoutShort: {
    if (!currentLayout)
      return "";
    const match = currentLayout.match(/\(([A-Za-z]+)\)|([A-Za-z]+)/);
    return (match?.[1] || match?.[2] || "").slice(0, 2).toUpperCase();
  }
  readonly property var layouts: backend?.layouts ?? []
  readonly property bool numOn: Utils.numLock
  readonly property bool scrollOn: Utils.scrollLock

  function cycleLayout() {
    backend?.cycleLayout?.();
  }

  onCurrentLayoutChanged: {
    if (currentLayout)
      Logger.log("KeyboardLayoutService", `Layout: ${currentLayout}`);
  }
}
