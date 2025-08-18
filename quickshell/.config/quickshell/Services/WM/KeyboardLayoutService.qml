pragma Singleton
import Quickshell
import QtQuick
import qs.Services
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

// Backend-only service that exposes current keyboard layouts and active layout.
// Chooses a WM-specific implementation based on MainService.currentWM.
Singleton {
    id: keyboardLayoutService

    // Detect environment via MainService
    property var mainService: MainService

    // Selected implementation singleton (Hypr.KeyboardLayoutImpl or Niri.KeyboardLayoutImpl)
    property var impl: mainService.currentWM === "hyprland" ? Hypr.KeyboardLayoutImpl : mainService.currentWM === "niri" ? Niri.KeyboardLayoutImpl : null

    // Public API (bindings copy from impl to avoid cross-engine reassigns)
    property var layouts: impl ? copyArray(impl.layouts) : []
    property string currentLayout: impl ? copyString(impl.currentLayout) : ""
    readonly property bool hasMultipleLayouts: layouts.length > 1

    // Helpers to avoid cross-engine JSValue reassignments on reload
    function copyArray(a) {
        return Array.isArray(a) ? a.slice(0) : [];
    }
    function copyString(s) {
        return String(s || "");
    }

    // Enable the implementation when it becomes available
    onImplChanged: {
        if (impl)
            impl.enabled = true;
    }
}
