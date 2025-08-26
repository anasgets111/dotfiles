pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import qs.Services.SystemInfo
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri
import qs.Services.Utils

Singleton {
    id: service

    readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.KeyboardLayoutImpl : MainService.currentWM === "niri" ? Niri.KeyboardLayoutImpl : null
    readonly property var layouts: backend ? (backend.layouts || []) : []
    readonly property string currentLayout: backend ? (backend.currentLayout || "") : ""
    readonly property bool hasMultipleLayouts: layouts.length > 1
    property bool capsOn: false
    property bool numOn: false
    property bool scrollOn: false
    property var ledUnsub: null

    onCurrentLayoutChanged: {
        if (!service.backend || !service.currentLayout)
            return;
        Logger.log("KeyboardLayoutService", "layout changed:", service.currentLayout);
        OSDService.showInfo(service.currentLayout);
    }

    Component.onCompleted: {
        service.ledUnsub = Utils.startLockLedWatcher({
            onChange: function (state) {
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

    function showToggle(label, on) {
        const msg = label + " " + (on ? "On" : "Off");
        OSDService.showInfo(msg);
        Logger.log("KeyboardLayoutService", msg);
    }

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
}
