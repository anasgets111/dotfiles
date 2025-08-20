pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
    id: clipboard

    // Lifecycle/state
    readonly property bool ready: !clipboard._isColdStart
    property bool enabled: true
    property var logger: LoggerService

    // Config
    property int maxItems: 10
    property int duplicateWindowMs: 60 * 1000 // 1 minute
    property bool persistEnabled: true
    property int maxPersistBytes: 1 * 1024 * 1024
    property bool captureOnStartup: false

    // Data
    property var history: []
    property var lastImage: null

    PersistentProperties {
        id: persistentStore
        reloadableId: "ClipboardService"
        property string textHistoryJson: "[]"
    }

    signal itemAdded(var entry)
    signal changed

    // Internal flags
    property bool _isFetching: false
    property int _watchRestartBackoffMs: 250
    property double _suppressUntilTimestamp: 0
    property int _suppressEventBudget: 0
    property bool _persistOperationInFlight: false
    property bool _isColdStart: true
    property double _startupIgnoreUntilTimestamp: 0

    // === REFACTORED: Smaller, focused functions ===

    // Lifecycle management
    function _shouldIgnoreStartupClipboard() {
        const now = Date.now();
        return (!clipboard.captureOnStartup && (clipboard._isColdStart || now < clipboard._startupIgnoreUntilTimestamp));
    }

    function _sanitizeMimeType(m) {
        return Utils.sanitizeMimeType(m);
    }

    function _scheduleWatcherRestart() {
        watcherRestartTimer.interval = clipboard._watchRestartBackoffMs;
        watcherRestartTimer.start();
        clipboard._watchRestartBackoffMs = Math.min(30000, clipboard._watchRestartBackoffMs * 2);
    }

    // Process management
    function _startMimeTypeDetection() {
        typeDetectionProcess.command = ["wl-paste", "-l"];
        typeDetectionProcess.running = true;
    }

    function _startTextRead() {
        textFetchProcess.command = ["wl-paste", "-n", "-t", "text"];
        textFetchProcess.running = true;
    }

    function _startImageRead(mimeType) {
        imageFetchProcess.mimeType = mimeType;
        imageFetchProcess.command = Utils.shCommand('mime="$1"; wl-paste -n -t "$mime" | base64 -w 0', [mimeType]);
        imageFetchProcess.running = true;
    }

    function _startPersistClipboardPipeline(mimeType) {
        if (!clipboard.enabled || !clipboard.persistEnabled || clipboard._persistOperationInFlight)
            return;

        const safeMime = clipboard._sanitizeMimeType(mimeType);
        const isText = Utils.isTextMime(safeMime);
        const isImage = Utils.isImageMime(safeMime);
        if (!isText && !isImage)
            return;

        clipboard._suppressEventBudget = Math.max(clipboard._suppressEventBudget, 2);
        clipboard._suppressUntilTimestamp = Date.now() + 500;
        clipboard._persistOperationInFlight = true;

        let cmdArr;
        if (isText) {
            cmdArr = Utils.shCommand('wl-paste -n -t text | wl-copy -t text/plain');
        } else {
            cmdArr = Utils.shCommand('mime="$1"; wl-paste -n -t "$mime" | wl-copy -t "$mime"', [safeMime]);
        }

        persistProcess.command = cmdArr;
        clipboard.logger.log("ClipboardService", `Persist: ${safeMime}`);
        persistProcess.running = true;
    }

    // History management
    function _appendTextToHistory(content) {
        const now = Date.now();
        const head = clipboard.history.length ? clipboard.history[0] : null;

        if (head && head.type === "text" && head.content === content && now - (head.ts || 0) <= clipboard.duplicateWindowMs) {
            clipboard.logger.log("ClipboardService", `Duplicate suppressed (within ${clipboard.duplicateWindowMs}ms)`);
            return false;
        }

        const entry = {
            type: "text",
            content: content,
            ts: now
        };

        clipboard.history = [entry, ...clipboard.history].slice(0, clipboard.maxItems);
        clipboard._saveTextHistory();

        clipboard.logger.log("ClipboardService", `Text added: len=${content.length}`);
        clipboard.itemAdded(entry);
        clipboard.changed();
        return true;
    }

    function _updateLastImageFromBase64(mimeType, base64) {
        const now = Date.now();
        const dataUrl = `data:${mimeType};base64,${base64}`;

        if (clipboard.lastImage && clipboard.lastImage.dataUrl === dataUrl && now - (clipboard.lastImage.ts || 0) <= clipboard.duplicateWindowMs) {
            return false;
        }

        clipboard.lastImage = {
            type: "image",
            mimeType: mimeType,
            dataUrl: dataUrl,
            ts: now
        };

        clipboard.changed();
        return true;
    }

    // Persistence management
    function _saveTextHistory() {
        persistentStore.textHistoryJson = JSON.stringify(_cloneTextHistory(clipboard.history));
    }

    function _loadTextHistory() {
        const persisted = Utils.safeJsonParse(persistentStore.textHistoryJson, []);
        if (Array.isArray(persisted) && persisted.length) {
            clipboard.history = _cloneTextHistory(persisted);
        } else if (!Array.isArray(persisted)) {
            clipboard.history = [];
            persistentStore.textHistoryJson = "[]";
        }
    }

    function _cloneTextHistory(arr) {
        const out = [];
        if (!arr || typeof arr.length !== "number")
            return out;
        for (let i = 0; i < arr.length; i++) {
            const e = arr[i] || {};
            if (e.type === "text") {
                out.push({
                    type: "text",
                    content: String(e.content || ""),
                    ts: Number(e.ts || Date.now())
                });
            }
        }
        return out;
    }

    // Fetch cycle management
    function _startFetchCycle() {
        if (!clipboard.enabled || clipboard._isFetching)
            return;

        clipboard._isFetching = true;
        clipboard.logger.log("ClipboardService", "Fetch cycle start");
        _startMimeTypeDetection();
    }

    function _finishFetchCycle() {
        clipboard._isFetching = false;
        clipboard._watchRestartBackoffMs = 250;
        if (clipboard._isColdStart)
            clipboard._isColdStart = false;
    }

    // === END REFACTORED FUNCTIONS ===

    // Debounce change notifications from the watcher
    Timer {
        id: changeDebounceTimer
        interval: 100
        repeat: false
        onTriggered: clipboard._startFetchCycle()
    }

    // Watcher process
    Process {
        id: watcherProcess
        command: ["wl-paste", "--watch", "printf", "CHANGE\n"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (_) {
                if (!clipboard.enabled)
                    return;
                const now = Date.now();
                if (clipboard._suppressEventBudget > 0 || now < clipboard._suppressUntilTimestamp) {
                    if (clipboard._suppressEventBudget > 0) {
                        clipboard._suppressEventBudget = Math.max(0, clipboard._suppressEventBudget - 1);
                    }
                    clipboard.logger.log("ClipboardService", "Watch: suppressed self-change");
                    return;
                }
                clipboard.logger.log("ClipboardService", "Watch: change signal");
                changeDebounceTimer.restart();
            }
        }
        onRunningChanged: {
            clipboard.logger.log("ClipboardService", `Watch: running=${watcherProcess.running}`);
            if (!watcherProcess.running && clipboard.enabled) {
                clipboard._scheduleWatcherRestart();
            }
        }
    }

    Timer {
        id: watcherRestartTimer
        repeat: false
        onTriggered: {
            if (!clipboard.enabled)
                return;
            clipboard.logger.log("ClipboardService", "Watch: restarting process");
            watcherProcess.running = true;
        }
    }

    // Type detection process
    Process {
        id: typeDetectionProcess
        stdout: StdioCollector {
            id: typeStdout
            onStreamFinished: {
                const out = (typeStdout.text || "").trim();
                const types = out ? out.split(/\n+/).filter(t => !!t) : [];

                if (types.length === 0) {
                    clipboard.logger.log("ClipboardService", "Types unavailable; attempting text fallback");
                    clipboard._startTextRead();
                    return;
                }

                clipboard.logger.log("ClipboardService", `Types: ${types.join(", ")}`);

                let imageType = types.find(t => /^image\//.test(t));
                imageType = clipboard._sanitizeMimeType(imageType);

                if (imageType) {
                    clipboard._startImageRead(imageType);
                    return;
                }

                const hasText = types.some(t => t === "text" || /^text\//.test(t));
                if (hasText) {
                    clipboard._startTextRead();
                    return;
                }

                clipboard.logger.log("ClipboardService", "No image/text types; best-effort text");
                clipboard._startTextRead();
            }
        }
    }

    // Text fetch process
    Process {
        id: textFetchProcess
        stdout: StdioCollector {
            id: textStdout
            onStreamFinished: {
                const content = String(textStdout.text || "");
                if (content.length) {
                    if (clipboard._shouldIgnoreStartupClipboard()) {
                        clipboard.logger.log("ClipboardService", "Startup: skipping initial clipboard text");
                    } else {
                        const added = clipboard._appendTextToHistory(content);
                        if (added && clipboard.persistEnabled) {
                            const sizeBytes = Utils.utf8Size(content);
                            if (sizeBytes <= clipboard.maxPersistBytes) {
                                clipboard._startPersistClipboardPipeline("text/plain");
                            } else {
                                clipboard.logger.log("ClipboardService", `Persist skip: text too large (${sizeBytes} > ${clipboard.maxPersistBytes})`);
                            }
                        }
                    }
                } else {
                    clipboard.logger.log("ClipboardService", "Text fetch: empty");
                }
                clipboard._finishFetchCycle();
            }
        }
    }

    // Image fetch process
    Process {
        id: imageFetchProcess
        property string mimeType: ""
        stdout: StdioCollector {
            id: imageStdout
            onStreamFinished: {
                const base64 = String(imageStdout.text || "").trim();
                if (base64) {
                    if (clipboard._shouldIgnoreStartupClipboard()) {
                        clipboard.logger.log("ClipboardService", "Startup: skipping initial image clipboard content");
                    } else {
                        const safeMime = clipboard._sanitizeMimeType(imageFetchProcess.mimeType);
                        const added = safeMime ? clipboard._updateLastImageFromBase64(safeMime, base64) : false;
                        clipboard.logger.log("ClipboardService", `Image fetch: ${safeMime || "invalid-mime"}, size=${base64.length}`);
                        if (added && clipboard.persistEnabled && !clipboard._isColdStart) {
                            const sizeBytes = Utils.base64Size(base64);
                            if (sizeBytes <= clipboard.maxPersistBytes) {
                                clipboard._startPersistClipboardPipeline(safeMime);
                            } else {
                                clipboard.logger.log("ClipboardService", `Persist skip: image too large (${sizeBytes} > ${clipboard.maxPersistBytes})`);
                            }
                        }
                    }
                }
                clipboard._finishFetchCycle();
            }
        }
    }

    // Persist process
    Process {
        id: persistProcess
        onRunningChanged: {
            if (!persistProcess.running) {
                clipboard._persistOperationInFlight = false;
                clipboard.logger.log("ClipboardService", "Persist: done");
            }
        }
    }

    // Public methods
    function clear() {
        clipboard.history = [];
        _saveTextHistory();
        clipboard.changed();
    }

    function refresh() {
        _startFetchCycle();
    }

    // Initialization
    Component.onCompleted: {
        clipboard.logger.log("ClipboardService", `Init: enabled=${clipboard.enabled}`);
        _loadTextHistory();

        if (clipboard.enabled) {
            watcherProcess.running = true;
            clipboard._startupIgnoreUntilTimestamp = Date.now() + 1000;
            _startFetchCycle();
        }
    }

    onEnabledChanged: {
        if (clipboard.enabled) {
            watcherProcess.running = true;
            clipboard._startupIgnoreUntilTimestamp = Date.now() + 1000;
            _startFetchCycle();
        } else {
            watcherProcess.running = false;
        }
    }
}
