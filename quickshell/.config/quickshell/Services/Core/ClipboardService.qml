pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.SystemInfo

// ClipboardService: Wayland clipboard watcher (text + images)
// - Clipboard only (no primary selection)
// - Event-driven via wl-paste --watch, with auto-restart on failure
// - Text history persisted; images are session-only (last image only)
// - De-dupe: exact match within a time window (default 1 minute)
// - No privacy filtering: all non-empty text is recorded
Singleton {
    id: clip

    // Lifecycle/state
    readonly property bool ready: !clip._coldStart
    property bool enabled: true
    property var logger: LoggerService

    // Config
    property int maxItems: 50
    property int duplicateWindowMs: 60 * 1000 // 1 minute
    // Persist config (wl-clip-persist style)
    // - Clipboard only (no primary selection)
    // - Do not re-offer on startup
    // - Persist only up to 1 MiB
    property bool persistEnabled: true
    property int maxPersistBytes: 1 * 1024 * 1024
    // Do not record the initial clipboard content on startup by default
    property bool captureOnStartup: false

    // Data
    // Text history only; newest first. Each entry: { type: 'text', content, ts }
    property var history: []
    // Session-only last image entry: { type: 'image', mimeType, dataUrl, ts }
    property var lastImage: null

    // Persistence: text history only
    PersistentProperties {
        id: store
        reloadableId: "ClipboardService"
        property var textHistory: []
    }

    // Public signals
    signal itemAdded(var entry)
    signal changed

    // Internal flags
    property bool _fetching: false
    property int _restartBackoffMs: 250
    // Suppress self-trigger loops after re-offer (time window + event budget)
    property double _suppressUntilTs: 0
    property int _suppressBudget: 0
    // Track persist pipeline state
    property bool _persistInFlight: false
    // Skip persist on first fetch after startup
    property bool _coldStart: true
    // Short window to avoid recording initial clipboard content even if a second
    // fetch is triggered immediately by a watcher event
    property double _startupSkipUntilTs: 0

    // Debounce change notifications from the watcher
    Timer {
        id: changeDebounce
        interval: 100
        repeat: false
        onTriggered: clip._doFetch()
    }

    Process {
        id: watchProc
        command: ["wl-paste", "--watch", "sh", "-c", "echo CHANGE"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (_) {
                if (!clip.enabled)
                    return;
                const now = Date.now();
                if (clip._suppressBudget > 0 || now < clip._suppressUntilTs) {
                    if (clip._suppressBudget > 0)
                        clip._suppressBudget = Math.max(0, clip._suppressBudget - 1);
                    clip.logger.log("ClipboardService", "Watch: suppressed self-change");
                    return;
                }
                clip.logger.log("ClipboardService", "Watch: change signal");
                changeDebounce.restart();
            }
        }
        onRunningChanged: {
            clip.logger.log("ClipboardService", `Watch: running=${watchProc.running}`);
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

                clip.logger.log("ClipboardService", `Types: ${types.join(', ')}`);

                // Prefer image/* if present, else any text/*
                const imageType = types.find(t => /^image\//.test(t));
                if (imageType) {
                    imageProc.mimeType = imageType;
                    imageProc.command = ["sh", "-c", `wl-paste -n -t "${imageType}" | base64 -w 0`];
                    clip.logger.log("ClipboardService", `Fetching image: ${imageType}`);
                    imageProc.running = true;
                    return;
                }

                const hasText = types.some(t => t === "text" || /^text\//.test(t));
                if (hasText) {
                    // Use the generic 'text' alias to avoid charset mismatches (e.g., text/plain;charset=utf-8)
                    textProc.command = ["wl-paste", "-n", "-t", "text"];
                    clip.logger.log("ClipboardService", "Fetching text");
                    textProc.running = true;
                    return;
                }

                // Last-resort: try plain text anyway
                textProc.command = ["wl-paste", "-n"]; // best-effort
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
                const content = String(textOut.text || "").trim();
                if (content) {
                    const now = Date.now();
                    if (!clip.captureOnStartup && (clip._coldStart || now < clip._startupSkipUntilTs)) {
                        clip.logger.log("ClipboardService", "Startup: skipping initial clipboard content");
                    } else {
                        const added = clip._addText(content);
                        // Persist (re-offer) text only if actually added and within size limit
                        if (added && clip.persistEnabled && !clip._coldStart) {
                            const sizeBytes = clip._utf8Size(content);
                            if (sizeBytes <= clip.maxPersistBytes) {
                                clip._startPersistPipeline("text/plain");
                            } else {
                                clip.logger.log("ClipboardService", `Persist skip: text too large (${sizeBytes} > ${clip.maxPersistBytes})`);
                            }
                        }
                    }
                } else {
                    clip.logger.log("ClipboardService", "Text fetch: empty/whitespace");
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
                    const now = Date.now();
                    if (!clip.captureOnStartup && (clip._coldStart || now < clip._startupSkipUntilTs)) {
                        clip.logger.log("ClipboardService", "Startup: skipping initial image clipboard content");
                    } else {
                        const added = clip._setLastImage(imageProc.mimeType, base64);
                        clip.logger.log("ClipboardService", `Image fetch: ${imageProc.mimeType}, size=${base64.length}`);
                        // Persist (re-offer) image only if actually added and within size limit
                        if (added && clip.persistEnabled && !clip._coldStart) {
                            const sizeBytes = clip._base64Size(base64);
                            if (sizeBytes <= clip.maxPersistBytes) {
                                clip._startPersistPipeline(imageProc.mimeType);
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
        try {
            store.textHistory = JSON.parse(JSON.stringify(clip.history));
        } catch (e) {
            store.textHistory = clip.history.slice();
        }
        clip.changed();
    }

    // Manual refresh (one shot)
    function refresh() {
        _doFetch();
    }

    // Internal: start a fresh fetch cycle
    function _doFetch() {
        if (!clip.enabled)
            return;
        if (clip._fetching)
            return;
        clip._fetching = true;
        clip.logger.log("ClipboardService", "Fetch cycle start");
        typeProc.command = ["wl-paste", "-l"];
        typeProc.running = true;
    }

    // Common tail for a successful fetch cycle
    function _finishFetch() {
        clip._fetching = false;
        // Reset watcher backoff on successful cycle
        clip._restartBackoffMs = 250;
        if (clip._coldStart)
            clip._coldStart = false;
    }

    // Add a text entry with duplicate-window logic
    function _addText(content) {
        const now = Date.now();
        const recentSame = clip.history.find(e => e && e.type === 'text' && e.content === content);
        if (recentSame && (now - (recentSame.ts || 0)) <= clip.duplicateWindowMs) {
            clip.logger.log("ClipboardService", `Duplicate suppressed (within ${clip.duplicateWindowMs}ms)`);
            return false; // skip within window
        }

        const entry = {
            type: 'text',
            content: content,
            ts: now
        };
        const newHist = [entry, ...clip.history];
        clip.history = newHist.slice(0, clip.maxItems);
        try {
            store.textHistory = JSON.parse(JSON.stringify(clip.history));
        } catch (e) {
            store.textHistory = clip.history.slice();
        }
        // Log newly added text entries (images are not logged)
        const preview = content.length > 160 ? content.slice(0, 157) + "..." : content;
        clip.logger.log("ClipboardService", `Text added: ${preview}`);
        clip.itemAdded(entry);
        clip.changed();
        return true;
    }

    // Maintain only last image in session, with duplicate-window logic
    function _setLastImage(mimeType, base64) {
        const now = Date.now();
        const dataUrl = `data:${mimeType};base64,${base64}`;
        if (clip.lastImage && clip.lastImage.dataUrl === dataUrl && (now - (clip.lastImage.ts || 0)) <= clip.duplicateWindowMs) {
            return false; // skip within window
        }
        clip.lastImage = {
            type: 'image',
            mimeType: mimeType,
            dataUrl: dataUrl,
            ts: now
        };
        clip.changed();
        return true;
    }

    // Helpers
    function _utf8Size(str) {
        // Approximate UTF-8 byte length
        try {
            return unescape(encodeURIComponent(str)).length;
        } catch (e) {
            // Fallback worst-case: 3 bytes per code unit
            return str.length * 3;
        }
    }

    function _base64Size(b64) {
        const len = b64.length;
        const pad = b64.endsWith("==") ? 2 : (b64.endsWith("=") ? 1 : 0);
        return Math.floor(len * 3 / 4) - pad;
    }

    function _startPersistPipeline(mimeType) {
        if (!clip.enabled || !clip.persistEnabled)
            return;
        if (clip._persistInFlight)
            return;
        // Only handle text/* and image/* types as requested
        const isText = (mimeType === "text" || mimeType === "text/plain" || (mimeType && mimeType.indexOf("text/") === 0));
        const isImage = (mimeType && mimeType.indexOf("image/") === 0);
        if (!isText && !isImage)
            return;

        let cmd;
        if (isText) {
            // Use explicit text/plain for reliability
            cmd = 'wl-paste -n -t text | wl-copy -t text/plain';
        } else {
            cmd = `wl-paste -n -t "${mimeType}" | wl-copy -t "${mimeType}"`;
        }
        // Suppress multiple quick watch events that wl-copy may cause
        clip._suppressBudget = Math.max(clip._suppressBudget, 2);
        clip._suppressUntilTs = Date.now() + 500;
        clip._persistInFlight = true;
        persistProc.command = ["sh", "-c", cmd];
        clip.logger.log("ClipboardService", `Persist: ${isText ? 'text/plain' : mimeType}`);
        persistProc.running = true;
    }

    Component.onCompleted: {
        clip.logger.log("ClipboardService", `Init: enabled=${clip.enabled}`);
        // Restore persisted text history
        if (store.textHistory && store.textHistory.length) {
            // Clone to current engine to avoid cross-engine JSValue warning
            try {
                clip.history = JSON.parse(JSON.stringify(store.textHistory));
            } catch (e) {
                // Fallback: shallow copy
                clip.history = store.textHistory.slice();
            }
        }

        // Start watcher and fetch current content once
        if (clip.enabled) {
            watchProc.running = true;
            // Allow a short grace period to avoid recording initial clipboard content
            // (covers a second immediate fetch from a watch event)
            clip._startupSkipUntilTs = Date.now() + 1000;
            _doFetch();
        }
    }
}
