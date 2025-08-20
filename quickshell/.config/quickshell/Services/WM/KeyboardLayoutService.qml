pragma Singleton
import Quickshell
import QtQuick
import QtQml
import Quickshell.Io
import qs.Services
import qs.Services.SystemInfo
import qs.Services.Core as Core
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
    id: root
    readonly property var logger: LoggerService
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
        root.logger.log("KeyboardLayoutService", "layout changed:", root.currentLayout);
        // Show the layout as the primary message for better visibility
        root.osd.showInfo(root.currentLayout);
    }

    // ----- Lock LEDs (Caps/Num/Scroll) monitoring -----
    // Aggregate state across all matching /sys/class/leds entries
    property bool capsOn: false
    property bool numOn: false
    property bool scrollOn: false

    // Discovered sysfs paths
    property var _capsPaths: []
    property var _numPaths: []
    property var _scrollPaths: []

    // Discover LED brightness files for each lock key (once at startup)
    // Note: we use FileSystemService helpers; no per-key Process objects are needed here.

    Component.onCompleted: {
        // Kick off discovery via FileSystemService
        Core.FileSystemService.listByGlob("/sys/class/leds/*::capslock/brightness", function (lines) {
            root._setLedPaths("caps", lines);
        });
        Core.FileSystemService.listByGlob("/sys/class/leds/*::numlock/brightness", function (lines) {
            root._setLedPaths("num", lines);
        });
        Core.FileSystemService.listByGlob("/sys/class/leds/*::scrolllock/brightness", function (lines) {
            root._setLedPaths("scroll", lines);
        });
    }

    function _setLedPaths(kind, paths) {
        var list = paths ? paths : [];
        if (kind === "caps")
            root._capsPaths = list;
        else if (kind === "num")
            root._numPaths = list;
        else
            root._scrollPaths = list;
    // After updates, next timer tick will poll initial state
    }

    // Timer-driven polling via FileSystemService
    Timer {
        id: ledPollTimer
        interval: 250
        repeat: true
        running: true
        onTriggered: {
            const groups = [root._capsPaths, root._numPaths, root._scrollPaths];
            Core.FileSystemService.pollGroupsAnyNonzero(groups, function (states) {
                if (states && states.length >= 3)
                    root._applyLedStates(!!states[0], !!states[1], !!states[2]);
            });
        }
    }

    function _applyLedStates(caps, num, scr) {
        if (caps !== root.capsOn) {
            root.capsOn = caps;
            root.osd.showInfo("Caps Lock " + (caps ? "On" : "Off"));
            root.logger.log("KeyboardLayoutService", "Caps Lock " + (caps ? "On" : "Off"));
        }
        if (num !== root.numOn) {
            root.numOn = num;
            root.osd.showInfo("Num Lock " + (num ? "On" : "Off"));
            root.logger.log("KeyboardLayoutService", "Num Lock " + (num ? "On" : "Off"));
        }
        if (scr !== root.scrollOn) {
            root.scrollOn = scr;
            root.osd.showInfo("Scroll Lock " + (scr ? "On" : "Off"));
            root.logger.log("KeyboardLayoutService", "Scroll Lock " + (scr ? "On" : "Off"));
        }
    }

    // Backend impls manage their own enablement via their `active` property.
}
