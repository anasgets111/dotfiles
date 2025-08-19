pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.SystemInfo

// Minimal, robust OSD/toast service for transient in-shell messages.
// Features:
// - Queue-based toasts with configurable durations by level
// - Simple dedupe: repeating the same message+level bumps a counter and restarts timer
// - Error-with-details sticks longer (extended duration); pause/resume controls
// - Do Not Disturb for toasts (suppresses showing but keeps queue)
// - IPC for show/info/warn/error/hide/clear/dnd/status
Singleton {
    id: root
    readonly property var logger: LoggerService

    // ----- Levels -----
    readonly property int levelInfo: 0
    readonly property int levelWarn: 1
    readonly property int levelError: 2

    // ----- State -----
    property string currentMessage: ""
    property int currentLevel: levelInfo
    property string currentDetails: ""
    readonly property bool hasDetails: root.currentDetails.length > 0
    property int currentRepeatCount: 0

    property bool toastVisible: false
    property var toastQueue: []

    // Suppress showing new toasts; queue is retained
    property bool doNotDisturb: false

    // Durations (ms)
    property int durationInfo: 3000
    property int durationWarn: 4000
    property int durationError: 5000
    property int durationErrorWithDetails: 8000

    // When true, identical message+level coalesces by incrementing repeat count
    property bool dedupe: true

    // Signal the UI to reset animations/positioning when a new toast shows
    signal resetToastState

    // ----- API -----
    function showToast(message, level = levelInfo, details = "") {
        if (message === null || message === undefined)
            return;
        const msg = String(message);
        const det = details === undefined || details === null ? "" : String(details);
        root.logger.log("OSDService", `showToast: level=${level}, msg='${msg}'`);

        // If the current toast matches and dedupe is on, bump the counter and refresh timer
        if (root.toastVisible && root.dedupe && msg === root.currentMessage && level === root.currentLevel) {
            root.currentRepeatCount += 1;
            root._restartTimerForCurrent();
            return;
        }

        // If the last queued message matches, merge by increasing a repeat counter
        if (root.dedupe && root.toastQueue.length > 0) {
            const last = root.toastQueue[root.toastQueue.length - 1];
            if (last && last.message === msg && last.level === level) {
                const q = root.toastQueue.slice();
                q[q.length - 1] = {
                    message: last.message,
                    level: last.level,
                    details: last.details,
                    repeat: (last.repeat || 0) + 1
                };
                root.toastQueue = q;
                root.logger.log("OSDService", `dedupe: bumped repeat to ${q[q.length - 1].repeat}`);
            } else {
                root.toastQueue = root.toastQueue.concat([
                    {
                        message: msg,
                        level: level,
                        details: det,
                        repeat: 0
                    }
                ]);
                root.logger.log("OSDService", `enqueued: level=${level}`);
            }
        } else {
            root.toastQueue = root.toastQueue.concat([
                {
                    message: msg,
                    level: level,
                    details: det,
                    repeat: 0
                }
            ]);
            root.logger.log("OSDService", `enqueued: level=${level}`);
        }

        if (!root.toastVisible && !root.doNotDisturb)
            root._processQueue();
    }

    function showInfo(message, details = "") {
        showToast(message, levelInfo, details);
    }
    function showWarning(message, details = "") {
        showToast(message, levelWarn, details);
    }
    function showError(message, details = "") {
        showToast(message, levelError, details);
    }

    function hideToast() {
        root.toastVisible = false;
        root.currentMessage = "";
        root.currentDetails = "";
        root.currentLevel = levelInfo;
        root.currentRepeatCount = 0;
        toastTimer.stop();
        root.resetToastState();
        if (!root.doNotDisturb)
            root._processQueue();
        root.logger.log("OSDService", "hideToast");
    }

    function clearQueue() {
        root.toastQueue = [];
    }

    function stopTimer() {
        toastTimer.stop();
    }

    function restartTimer() {
        root._restartTimerForCurrent();
    }

    function setDoNotDisturb(enabled) {
        const e = !!enabled;
        if (root.doNotDisturb === e)
            return;
        root.doNotDisturb = e;
        if (e) {
            // Hide immediately and stop timer
            toastTimer.stop();
            root.toastVisible = false;
            root.resetToastState();
        } else {
            root._processQueue();
        }
        root.logger.log("OSDService", `DND=${root.doNotDisturb}`);
    }

    // Optional external status (e.g., wallpaper failure)
    property string wallpaperErrorStatus: ""
    function clearWallpaperError() {
        root.wallpaperErrorStatus = "";
    }

    // ----- Internals -----
    function _processQueue() {
        if (root.toastVisible)
            return;
        if (root.doNotDisturb)
            return;
        if (root.toastQueue.length === 0)
            return;
        const q = root.toastQueue.slice();
        const toast = q.shift();
        root.toastQueue = q;
        root.currentMessage = toast.message;
        root.currentLevel = toast.level;
        root.currentDetails = toast.details || "";
        root.currentRepeatCount = toast.repeat || 0;
        root.toastVisible = true;
        root.resetToastState();
        root._applyTimerFor(toast.level, root.hasDetails);
        root.logger.log("OSDService", `show: level=${root.currentLevel}, repeats=${root.currentRepeatCount}`);
    }

    function _applyTimerFor(level, hasDetails) {
        if (level === levelError && hasDetails) {
            toastTimer.interval = root.durationErrorWithDetails;
        } else if (level === levelError) {
            toastTimer.interval = root.durationError;
        } else if (level === levelWarn) {
            toastTimer.interval = root.durationWarn;
        } else {
            toastTimer.interval = root.durationInfo;
        }
        toastTimer.restart();
    }

    function _restartTimerForCurrent() {
        root._applyTimerFor(root.currentLevel, root.hasDetails);
    }

    // Timer driving toast lifetime
    Timer {
        id: toastTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: root.hideToast()
    }

    // ----- IPC -----
    IpcHandler {
        target: "osd"
        // Single-argument friendly variants
        function info(message: string): string {
            root.showInfo(message, "");
            return "ok";
        }
        function warn(message: string): string {
            root.showWarning(message, "");
            return "ok";
        }
        function error(message: string): string {
            root.showError(message, "");
            return "ok";
        }
        // Use 'showlvl' to avoid potential CLI parsing conflicts with 'show'
        function showlvl(message: string, level: int): string {
            root.showToast(message, level, "");
            return "ok";
        }
        // With-details variants
        function infod(message: string, details: string): string {
            root.showInfo(message, details);
            return "ok";
        }
        function warnd(message: string, details: string): string {
            root.showWarning(message, details);
            return "ok";
        }
        function errord(message: string, details: string): string {
            root.showError(message, details);
            return "ok";
        }
        function showlvld(message: string, level: int, details: string): string {
            root.showToast(message, level, details);
            return "ok";
        }
        function hide(): string {
            root.hideToast();
            return "hidden";
        }
        function clear(): string {
            root.clearQueue();
            return "cleared";
        }
        function dnd(state: string): string {
            if (typeof state === "string")
                root.setDoNotDisturb(state.toLowerCase() === "on" || state.toLowerCase() === "true");
            else
                root.setDoNotDisturb(!!state);
            return "DND=" + root.doNotDisturb;
        }
        function status(): string {
            return `OSD: visible=${root.toastVisible}, queued=${root.toastQueue.length}, level=${root.currentLevel}, repeats=${root.currentRepeatCount}, DND=${root.doNotDisturb}`;
        }
    }
}
