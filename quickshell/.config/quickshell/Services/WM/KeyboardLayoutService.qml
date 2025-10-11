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
  readonly property string currentLayout: backend ? (backend.currentLayout || "") : ""
  readonly property bool hasMultipleLayouts: layouts.length > 1

  // Two-letter uppercase code for UI (e.g., "US" for "English (US)", "AR" for "Arabic (Egypt)")
  readonly property string layoutShort: service.computeLayoutShort(service.currentLayout)
  readonly property var layouts: backend ? (backend.layouts || []) : []
  property var ledUnsub: null
  property bool numOn: false
  property bool scrollOn: false
  function applyLedStates(caps, num, scroll) {
    if (caps !== service.capsOn) {
      service.capsOn = caps;
      service.showToggle("Caps Lock", caps);
    }
    if (num !== service.numOn) {
      service.numOn = num;
      service.showToggle("Num Lock", num);
    }
    if (scroll !== service.scrollOn) {
      service.scrollOn = scroll;
      service.showToggle("Scroll Lock", scroll);
    }
  }
  function computeLayoutShort(s) {
    if (!s || typeof s !== "string")
      return "";

    // Prefer the first two letters from inside parentheses, e.g., (US)->US, (Egypt)->EG
    const paren = s.match(/\(([^)]+)\)/);
    if (paren && paren[1]) {
      const innerLetters = paren[1].replace(/[^A-Za-z]/g, "");
      if (innerLetters.length >= 2)
        return innerLetters.slice(0, 2).toUpperCase();
      if (innerLetters.length > 0)
        return innerLetters.toUpperCase();
    }

    // Fallback: take the first two letters from the whole string
    const letters = s.replace(/[^A-Za-z]/g, "");
    return letters.slice(0, 2).toUpperCase();
  }
  function showToggle(label, on) {
    const msg = label + " " + (on ? "On" : "Off");
    Logger.log("KeyboardLayoutService", msg);
  }
  function cycleLayout() {
    if (service.backend && typeof service.backend.cycleLayout === "function") {
      service.backend.cycleLayout();
    }
  }

  Component.onCompleted: {
    service.ledUnsub = Utils.startLockLedWatcher({
      "onChange": function (state) {
        service.applyLedStates(!!state.caps, !!state.num, !!state.scroll);
      }
    });
  }
  Component.onDestruction: {
    const unsub = service.ledUnsub;
    if (typeof unsub === "function") {
      try {
        unsub();
      } catch (_) {}
    }
    service.ledUnsub = null;
  }
  onCurrentLayoutChanged: {
    if (!service.backend || !service.currentLayout)
      return;

    Logger.log("KeyboardLayoutService", "layout changed:", service.currentLayout);
  }
}
