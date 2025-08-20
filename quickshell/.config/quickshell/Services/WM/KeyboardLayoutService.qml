pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import qs.Services.SystemInfo
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri
import qs.Services.Utils

Singleton {
    id: root
    // OSD for user feedback on layout changes
    readonly property var osd: OSDService
    readonly property var mainService: MainService
    readonly property var wmImplementation: mainService.currentWM === "hyprland" ? Hypr.KeyboardLayoutImpl : mainService.currentWM === "niri" ? Niri.KeyboardLayoutImpl : null
    readonly property var layouts: wmImplementation ? (wmImplementation.layouts || []) : []
    readonly property string currentLayout: wmImplementation ? (wmImplementation.currentLayout || "") : ""
    readonly property bool hasMultipleLayouts: layouts.length > 1

    // Notify on layout change
    onCurrentLayoutChanged: {
        if (!root.wmImplementation || !root.currentLayout)
            return;
        Logger.log("KeyboardLayoutService", "layout changed:", root.currentLayout);
        // Show the layout as the primary message for better visibility
        root.osd.showInfo(root.currentLayout);
    }

    // ----- Lock LEDs (Caps/Num/Scroll) monitoring -----
    // State surfaced publicly for consumers (e.g., UI elements)
    property bool capsOn: false
    property bool numOn: false
    property bool scrollOn: false

    // Subscription handle
    property var _ledUnsub: null

    Component.onCompleted: {
        // Subscribe to Utils watcher; immediate callback will sync initial state
        root._ledUnsub = Utils.startLockLedWatcher({
            onChange: function (state) {
                root._applyLedStates(!!state.caps, !!state.num, !!state.scroll);
            }
        });
    }

    Component.onDestruction: {
        var unsub = root._ledUnsub;
        if (unsub && typeof unsub === 'function') {
            try {
                unsub();
            } catch (e) {}
        }
        root._ledUnsub = null;
    }

    function _applyLedStates(caps, num, scr) {
        if (caps !== root.capsOn) {
            root.capsOn = caps;
            root.osd.showInfo("Caps Lock " + (caps ? "On" : "Off"));
            Logger.log("KeyboardLayoutService", "Caps Lock " + (caps ? "On" : "Off"));
        }
        if (num !== root.numOn) {
            root.numOn = num;
            root.osd.showInfo("Num Lock " + (num ? "On" : "Off"));
            Logger.log("KeyboardLayoutService", "Num Lock " + (num ? "On" : "Off"));
        }
        if (scr !== root.scrollOn) {
            root.scrollOn = scr;
            root.osd.showInfo("Scroll Lock " + (scr ? "On" : "Off"));
            Logger.log("KeyboardLayoutService", "Scroll Lock " + (scr ? "On" : "Off"));
        }
    }

    // Backend impls manage their own enablement via their `active` property.
}
