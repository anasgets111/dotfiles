pragma Singleton
import Quickshell
import qs.Services
import qs.Services.Utils
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.KeyboardLayoutImpl : MainService.currentWM === "niri" ? Niri.KeyboardLayoutImpl : null
  readonly property bool capsOn: Utils.capsLock
  readonly property string currentLayout: backend?.currentLayout ?? ""
  readonly property int currentLayoutIndex: backend?.currentLayoutIndex ?? -1
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

  function nextLayout(): void {
    backend?.nextLayout?.();
  }
  function setLayoutByIndex(targetIndex: int): void {
    if (targetIndex < 0 || targetIndex >= layouts.length || targetIndex === currentLayoutIndex)
      return;
    backend?.setLayoutByIndex?.(targetIndex);
  }

  onCurrentLayoutChanged: if (currentLayout)
    Logger.log("KeyboardLayoutService", `Layout: ${currentLayout}`)
}
