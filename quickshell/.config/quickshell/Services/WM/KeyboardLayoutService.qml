pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import qs.Services.SystemInfo
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

    // Prefer a two-letter code inside parentheses, e.g., (US), (UK), (DE)
    const m = s.match(/\(([A-Za-z]{2})\)/);
    if (m && m[1])
      return m[1].toUpperCase();

    // Fallback: take the first two letters of the leading word (before any parentheses)
    const name = s.split("(")[0].trim();
    const letters = name.replace(/[^A-Za-z]/g, "");
    return letters.slice(0, 2).toUpperCase();
  }
  function showToggle(label, on) {
    const msg = label + " " + (on ? "On" : "Off");
    OSDService.showInfo(msg);
    Logger.log("KeyboardLayoutService", msg);
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
    OSDService.showInfo(service.currentLayout);
  }
}
