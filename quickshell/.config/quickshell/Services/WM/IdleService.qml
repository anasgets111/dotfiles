pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../" as Services

Singleton {
    id: idleService

    // config
    property int dimAfter: 150     // seconds
    property int lockAfter: 300
    property int offAfter: 330
    property int suspendAfter: 1800

    // runtime
    property string backend: "auto" // "ext-idle", "hyprland", "systemd", "poll"
    property bool isIdle: false
    property string stage: "active" // active|dim|locked|off|suspend

    // --- processes (top-level) ---
    // generic commands (fill command then run)
    Process {
        id: lockCmd
        // command set just before running
        stdout: StdioCollector {}
    }
    Process {
        id: dpmsCmd
        stdout: StdioCollector {}
    }
    Process {
        id: suspendCmd
        command: ["sh", "-c", "systemctl suspend"]
        stdout: StdioCollector {}
    }

    // helper: check inhibitors (loginctl list-inhibitors)
    Process {
        id: inhibitorsProc
        command: ["sh", "-c", "loginctl list-inhibitors --no-legend"]
        stdout: StdioCollector {
            onStreamFinished: {
                // empty => no inhibitors; otherwise parse lines to decide
                var out = text.trim();
                idleService._hasInhibitor = out.length > 0;
            }
        }
    }
    property bool _hasInhibitor: false

    // --- detection entry points (choose backend on startup) ---
    Component.onCompleted: {
        _chooseBackend();
        _startDetection();
    }

    function _chooseBackend() {
        // prefer compositor backends if you detect them
        if (Services.MainService.currentWM === "hyprland") {
            backend = "hyprland";
        } else {
            backend = "auto";
        }
    }

    function _startDetection() {
        if (backend === "hyprland") {
            // subscribe to hyprland events (implement HyprIdleService)
            // Hyprland-specific integration lives in services/wm/impl/hyprland
            Services.HyprIdleService.start();
        } else if (backend === "ext-idle") {
            // if you implement a Wayland ext-idle binding
            ExtIdle.bind(); // pseudocode — implement in C++/plugin if necessary
        } else {
            // fallback: use systemd/logind triggers (query) and rely on loginctl for lock/suspend
            // We'll call inhibitors check before each action
            checkAndAct("lock");
        }
    }

    // called by backend when the idle stage changes
    function onIdleStage(newStage) {
        if (_hasInhibitor)
            return;
        stage = newStage;
        switch (newStage) {
        case "dim":
            // ask compositor to reduce brightness or keyboard backlight
            dpmsCmd.command = ["sh", "-c", "brightnessctl set 10%"];
            dpmsCmd.running = true;
            break;
        case "lock":
            // prefer loginctl lock-session so logind / DM can handle
            lockCmd.command = ["sh", "-c", "loginctl lock-session"];
            lockCmd.running = true;
            Services.LockService.requestLock(); // local state
            break;
        case "off":
            // compositor DPMS; hyprland uses "hyprctl dispatch dpms off"
            if (Services.MainService.currentWM === "hyprland") {
                dpmsCmd.command = ["sh", "-c", "hyprctl dispatch dpms off"];
            } else {
                dpmsCmd.command = ["sh", "-c", "loginctl lock-session && xset dpms force off"]; // fallback
            }
            dpmsCmd.running = true;
            break;
        case "suspend":
            suspendCmd.running = true;
            break;
        }
    }

    function checkInhibitorsAndRun(cmdProc) {
        inhibitorsProc.running = true;
        inhibitorsProc.stdout.onStreamFinished = function () {
            if (!idleService._hasInhibitor)
                cmdProc.running = true;
        };
    }
}
