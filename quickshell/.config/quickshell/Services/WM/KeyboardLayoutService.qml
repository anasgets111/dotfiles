pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import qs.Services.Utils
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: service

  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.KeyboardLayoutImpl : MainService.currentWM === "niri" ? Niri.KeyboardLayoutImpl : null
  property bool capsOn: false
  readonly property string currentLayout: backend?.currentLayout ?? ""
  readonly property bool hasMultipleLayouts: layouts.length > 1
  // Two-letter uppercase code for UI (e.g., "US" for "English (US)", "AR" for "Arabic (Egypt)")
  readonly property string layoutShort: computeLayoutShort(currentLayout)
  readonly property var layouts: backend?.layouts ?? []
  property var ledUnsub: null
  property bool numOn: false
  property bool scrollOn: false

  function applyLedStates(caps, num, scroll) {
    capsOn = caps;
    numOn = num;
    scrollOn = scroll;
  }

  function computeLayoutShort(s) {
    if (!s)
      return "";

    // Extract letters from parentheses first, e.g., (US)->US, (Egypt)->EG
    const match = s.match(/\(([A-Za-z]+)\)|([A-Za-z]+)/);
    const letters = match ? (match[1] || match[2] || "") : "";
    return letters.slice(0, 2).toUpperCase();
  }

  function cycleLayout() {
    if (backend?.cycleLayout)
      backend.cycleLayout();
  }

  Component.onCompleted: {
    ledUnsub = Utils.startLockLedWatcher({
      onChange: state => applyLedStates(!!state.caps, !!state.num, !!state.scroll)
    });
  }
  Component.onDestruction: {
    const unsub = ledUnsub;
    if (typeof unsub === "function")
      unsub();

    ledUnsub = null;
  }
  onCurrentLayoutChanged: {
    if (currentLayout)
      Logger.log("KeyboardLayoutService", `Layout: ${currentLayout}`);
  }
}
