pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

// Minimal, robust OSD/toast service for transient in-shell messages.
// Features:
// - Queue-based toasts with configurable durations by level
// - Simple dedupe: repeating the same message+level bumps a counter and restarts timer
// - Error-with-details sticks longer (extended duration); pause/resume controls
// - Do Not Disturb for toasts (suppresses showing but keeps queue)
// - IPC for show/info/warn/error/hide/clear/dnd/status
Singleton {
    id: root

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

    // When enabled, if a new toast arrives while one is visible and the level matches,
    // the current toast content is replaced and the timer restarts instead of queueing/hide-show cycling.
    property bool replaceWhileVisible: true

    // Max time a toast can remain visible even if it keeps being replaced/reset (ms)
    property int maxVisibleMs: 5000
    property double _currentStartAt: 0

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
        Logger.log("OSDService", `showToast: level=${level}, msg='${msg}'`);

        // If the current toast matches and dedupe is on, bump the counter and refresh timer
        if (root.toastVisible && root.dedupe && msg === root.currentMessage && level === root.currentLevel) {
            root.currentRepeatCount += 1;
            root._restartTimerForCurrent();
            return;
        }

        // Live replace with escalation: update if visible and new level >= current level
        if (root.toastVisible && root.replaceWhileVisible && level >= root.currentLevel) {
            root.currentMessage = msg;
            root.currentDetails = det;
            root.currentLevel = level;
            // Keep repeat count as-is; this is a replacement, not a duplicate
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
                Logger.log("OSDService", `dedupe: bumped repeat to ${q[q.length - 1].repeat}`);
            } else {
                root.toastQueue = root.toastQueue.concat([
                    {
                        message: msg,
                        level: level,
                        details: det,
                        repeat: 0
                    }
                ]);
                Logger.log("OSDService", `enqueued: level=${level}`);
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
            Logger.log("OSDService", `enqueued: level=${level}`);
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
        root._currentStartAt = 0;
        toastTimer.stop();
        root.resetToastState();
        if (!root.doNotDisturb)
            root._processQueue();
        Logger.log("OSDService", "hideToast");
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
        Logger.log("OSDService", `DND=${root.doNotDisturb}`);
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
        root._currentStartAt = Date.now ? Date.now() : new Date().getTime();
        root.resetToastState();
        root._applyTimerFor(toast.level, root.hasDetails);
        Logger.log("OSDService", `show: level=${root.currentLevel}, repeats=${root.currentRepeatCount}`);
    }

    function _applyTimerFor(level, hasDetails) {
        var baseInterval = 0;
        if (level === levelError && hasDetails) {
            baseInterval = root.durationErrorWithDetails;
        } else if (level === levelError) {
            baseInterval = root.durationError;
        } else if (level === levelWarn) {
            baseInterval = root.durationWarn;
        } else {
            baseInterval = root.durationInfo;
        }
        var now = Date.now ? Date.now() : new Date().getTime();
        var remainingCap = (root.toastVisible && root._currentStartAt > 0) ? Math.max(0, root.maxVisibleMs - (now - root._currentStartAt)) : -1;
        if (remainingCap === 0) {
            root.hideToast();
            return;
        }
        toastTimer.interval = remainingCap > 0 ? Math.min(baseInterval, remainingCap) : baseInterval;
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
}
