pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
    id: clip

    // Lifecycle/state
    readonly property bool ready: !clip._coldStart
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
        id: store
        reloadableId: "ClipboardService"
        property string textHistoryJson: "[]"
    }

    signal itemAdded(var entry)
    signal changed

    // Internal flags
    property bool _fetching: false
    property int _restartBackoffMs: 250
    property double _suppressUntilTs: 0
    property int _suppressBudget: 0
    property bool _persistInFlight: false
    property bool _coldStart: true
    property double _startupSkipUntilTs: 0

    // Helpers (centralize small decisions)
    function _shouldSkipStartup() {
        const now = Date.now();
        return (!clip.captureOnStartup && (clip._coldStart || now < clip._startupSkipUntilTs));
    }

    function _sanitizeMimeType(m) {
        // Use Utils implementation for consistency across services
        return Utils.sanitizeMimeType(m);
    }

    function _scheduleWatchRestart() {
        restartTimer.interval = clip._restartBackoffMs;
        restartTimer.start();
        clip._restartBackoffMs = Math.min(30000, clip._restartBackoffMs * 2);
    }

    // Debounce change notifications from the watcher
    Timer {
        id: changeDebounce
        interval: 100
        repeat: false
        onTriggered: clip._doFetch()
    }

    Process {
        id: watchProc
        // Avoid shell here; wl-paste --watch execs argv directly
        command: ["wl-paste", "--watch", "printf", "CHANGE\n"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (_) {
                if (!clip.enabled)
                    return;
                const now = Date.now();
                if (clip._suppressBudget > 0 || now < clip._suppressUntilTs) {
                    if (clip._suppressBudget > 0) {
                        clip._suppressBudget = Math.max(0, clip._suppressBudget - 1);
                    }
                    clip.logger.log("ClipboardService", "Watch: suppressed self-change");
                    return;
                }
                clip.logger.log("ClipboardService", "Watch: change signal");
                changeDebounce.restart();
            }
        }
        onRunningChanged: {
            clip.logger.log("ClipboardService", `Watch: running=${watchProc.running}`);
            if (!watchProc.running && clip.enabled) {
                clip._scheduleWatchRestart();
            }
        }
    }

    Timer {
        id: restartTimer
        repeat: false
        onTriggered: {
            if (!clip.enabled)
                return;
            clip.logger.log("ClipboardService", "Watch: restarting process");
            watchProc.running = true;
        }
    }

    // One-shot type lister
    Process {
        id: typeProc
        stdout: StdioCollector {
            id: typeOut
            onStreamFinished: {
                const out = (typeOut.text || "").trim();
                const types = out ? out.split(/\n+/).filter(t => !!t) : [];

                if (types.length === 0) {
                    // Fallback when type listing fails or is empty: try text
                    textProc.command = ["wl-paste", "-n", "-t", "text"];
                    clip.logger.log("ClipboardService", "Types unavailable; attempting text fallback");
                    textProc.running = true;
                    return;
                }

                clip.logger.log("ClipboardService", `Types: ${types.join(", ")}`);

                // Prefer image/* if present, else any text/*
                let imageType = types.find(t => /^image\//.test(t));
                imageType = clip._sanitizeMimeType(imageType);
                if (imageType) {
                    imageProc.mimeType = imageType;
                    // Use positional parameter to avoid injection (no direct interpolation)
                    imageProc.command = Utils.shCommand('mime="$1"; wl-paste -n -t "$mime" | base64 -w 0', [imageType]);
                    clip.logger.log("ClipboardService", `Fetching image: ${imageType}`);
                    imageProc.running = true;
                    return;
                }

                const hasText = types.some(t => t === "text" || /^text\//.test(t)) || false;
                if (hasText) {
                    textProc.command = ["wl-paste", "-n", "-t", "text"];
                    clip.logger.log("ClipboardService", "Fetching text");
                    textProc.running = true;
                    return;
                }

                // Last-resort: try plain text anyway
                textProc.command = ["wl-paste", "-n"];
                clip.logger.log("ClipboardService", "No image/text types; best-effort text");
                textProc.running = true;
            }
        }
    }

    // Text fetcher
    Process {
        id: textProc
        stdout: StdioCollector {
            id: textOut
            onStreamFinished: {
                // Do not trim payload; preserve exact content
                const content = String(textOut.text || "");
                if (content.length) {
                    if (clip._shouldSkipStartup()) {
                        clip.logger.log("ClipboardService", "Startup: skipping initial clipboard text");
                    } else {
                        const added = clip._addText(content);
                        if (added && clip.persistEnabled) {
                            const sizeBytes = Utils.utf8Size(content);
                            if (sizeBytes <= clip.maxPersistBytes) {
                                clip._startPersistPipeline("text/plain");
                            } else {
                                clip.logger.log("ClipboardService", `Persist skip: text too large (${sizeBytes} > ${clip.maxPersistBytes})`);
                            }
                        }
                    }
                } else {
                    clip.logger.log("ClipboardService", "Text fetch: empty");
                }
                clip._finishFetch();
            }
        }
    }

    // Image fetcher (session only)
    Process {
        id: imageProc
        property string mimeType: ""
        stdout: StdioCollector {
            id: imageOut
            onStreamFinished: {
                const base64 = String(imageOut.text || "").trim();
                if (base64) {
                    if (clip._shouldSkipStartup()) {
                        clip.logger.log("ClipboardService", "Startup: skipping initial image clipboard content");
                    } else {
                        const safeMime = clip._sanitizeMimeType(imageProc.mimeType);
                        const added = safeMime ? clip._setLastImage(safeMime, base64) : false;
                        clip.logger.log("ClipboardService", `Image fetch: ${safeMime || "invalid-mime"}, size=${base64.length}`);
                        if (added && clip.persistEnabled && !clip._coldStart) {
                            const sizeBytes = Utils.base64Size(base64);
                            if (sizeBytes <= clip.maxPersistBytes) {
                                clip._startPersistPipeline(safeMime);
                            } else {
                                clip.logger.log("ClipboardService", `Persist skip: image too large (${sizeBytes} > ${clip.maxPersistBytes})`);
                            }
                        }
                    }
                }
                clip._finishFetch();
            }
        }
    }

    // Persist pipeline: re-own clipboard via wl-paste | wl-copy
    Process {
        id: persistProc
        onRunningChanged: {
            if (!persistProc.running) {
                clip._persistInFlight = false;
                clip.logger.log("ClipboardService", "Persist: done");
            }
        }
    }

    // Public helpers
    function clear() {
        clip.history = [];
        store.textHistoryJson = JSON.stringify(_cloneTextHistory(clip.history));
        clip.changed();
    }

    function refresh() {
        _doFetch();
    }

    function _doFetch() {
        if (!clip.enabled || clip._fetching)
            return;
        clip._fetching = true;
        clip.logger.log("ClipboardService", "Fetch cycle start");
        typeProc.command = ["wl-paste", "-l"];
        typeProc.running = true;
    }

    function _finishFetch() {
        clip._fetching = false;
        clip._restartBackoffMs = 250;
        if (clip._coldStart)
            clip._coldStart = false;
    }

    // Add a text entry with duplicate-window logic (check only newest)
    function _addText(content) {
        const now = Date.now();
        const head = clip.history.length ? clip.history[0] : null;
        if (head && head.type === "text" && head.content === content && now - (head.ts || 0) <= clip.duplicateWindowMs) {
            clip.logger.log("ClipboardService", `Duplicate suppressed (within ${clip.duplicateWindowMs}ms)`);
            return false;
        }

        const entry = {
            type: "text",
            content: content,
            ts: now
        };
        clip.history = [entry, ...clip.history].slice(0, clip.maxItems);
        store.textHistoryJson = JSON.stringify(_cloneTextHistory(clip.history));

        // Privacy-friendly log
        clip.logger.log("ClipboardService", `Text added: len=${content.length}`);
        clip.itemAdded(entry);
        clip.changed();
        return true;
    }

    function _setLastImage(mimeType, base64) {
        const now = Date.now();
        const dataUrl = `data:${mimeType};base64,${base64}`;
        if (clip.lastImage && clip.lastImage.dataUrl === dataUrl && now - (clip.lastImage.ts || 0) <= clip.duplicateWindowMs) {
            return false;
        }
        clip.lastImage = {
            type: "image",
            mimeType: mimeType,
            dataUrl: dataUrl,
            ts: now
        };
        clip.changed();
        return true;
    }

    // Helpers
    // Size helpers moved to Utils

    function _startPersistPipeline(mimeType) {
        if (!clip.enabled || !clip.persistEnabled)
            return;
        if (clip._persistInFlight)
            return;

        const safeMime = clip._sanitizeMimeType(mimeType);
        const isText = Utils.isTextMime(safeMime);
        const isImage = Utils.isImageMime(safeMime);
        if (!isText && !isImage)
            return;

        // Build safe command: wl-paste -n -t <mime> | wl-copy -t <mime>
        // We can’t avoid the shell completely because Process doesn’t support pipes.
        if (!safeMime)
            return;

        let cmdArr;
        if (isText) {
            cmdArr = Utils.shCommand('wl-paste -n -t text | wl-copy -t text/plain');
        } else {
            cmdArr = Utils.shCommand('mime="$1"; wl-paste -n -t "$mime" | wl-copy -t "$mime"', [safeMime]);
        }

        clip._suppressBudget = Math.max(clip._suppressBudget, 2);
        clip._suppressUntilTs = Date.now() + 500;
        clip._persistInFlight = true;

        persistProc.command = cmdArr;
        clip.logger.log("ClipboardService", `Persist: ${safeMime}`);
        persistProc.running = true;
    }

    Component.onCompleted: {
        clip.logger.log("ClipboardService", `Init: enabled=${clip.enabled}`);

        // Restore persisted text history from JSON string
        const persisted = Utils.safeJsonParse(store.textHistoryJson, []);
        if (Array.isArray(persisted) && persisted.length) {
            clip.history = _cloneTextHistory(persisted);
        } else if (!Array.isArray(persisted)) {
            // Reset invalid data to a sane default
            clip.history = [];
            store.textHistoryJson = "[]";
        }

        if (clip.enabled) {
            watchProc.running = true;
            clip._startupSkipUntilTs = Date.now() + 1000;
            _doFetch();
        }
    }

    onEnabledChanged: {
        if (clip.enabled) {
            watchProc.running = true;
            clip._startupSkipUntilTs = Date.now() + 1000;
            _doFetch();
        } else {
            watchProc.running = false;
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
}
