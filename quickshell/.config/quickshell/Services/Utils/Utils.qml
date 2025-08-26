pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core

Singleton {
    id: utils

    function runCmd(cmd, onDone, parent) {
        if (!cmd || !Array.isArray(cmd) || cmd.length === 0) {
            if (onDone)
                onDone("");
            return;
        }
        const host = parent || utils;
        const proc = Qt.createQmlObject('import Quickshell.Io; Process {}', host);
        const stdio = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc);
        proc.stdout = stdio;
        stdio.onStreamFinished.connect(function () {
            try {
                if (onDone)
                    onDone(stdio.text);
            } finally {
                try {
                    stdio.destroy();
                } catch (err) {}
                try {
                    proc.destroy();
                } catch (err) {}
            }
        });
        proc.command = cmd;
        proc.running = true;
    }

    function stripAnsi(input) {
        const value = String(input);
        const ansiPattern = new RegExp("\\x1B(?:[@-Z\\\\-_]|\\[[0-\\?]*[ -/]*[@-~]|\\][^\\x07]*(\\x07|\\x1B\\\\))", "g");
        return value.replace(ansiPattern, "");
    }

    function mergeObjects(objA, objB) {
        const out = {};
        for (const prop in objA)
            if (Object.prototype.hasOwnProperty.call(objA, prop))
                out[prop] = objA[prop];
        for (const prop in objB)
            if (Object.prototype.hasOwnProperty.call(objB, prop))
                out[prop] = objB[prop];
        return out;
    }

    function sanitizeMimeType(input) {
        const value = String(input || "");
        const mimePattern = new RegExp("^[a-z0-9](?:[a-z0-9.+-])*/[a-z0-9](?:[a-z0-9.+-])*$", "i");
        return mimePattern.test(value) ? value : "";
    }

    function isTextMime(mime) {
        const sanitized = sanitizeMimeType(mime);
        return sanitized === "text" || sanitized === "text/plain" || sanitized.indexOf("text/") === 0;
    }

    function isImageMime(mime) {
        const sanitized = sanitizeMimeType(mime);
        return sanitized.indexOf("image/") === 0;
    }

    function utf8Size(input) {
        try {
            return unescape(encodeURIComponent(String(input))).length;
        } catch (_) {
            const str = String(input || "");
            return str.length * 3;
        }
    }

    function base64Size(b64) {
        const str = String(b64 || "");
        const len = str.length;
        const pad = str.endsWith("==") ? 2 : str.endsWith("=") ? 1 : 0;
        return Math.floor((len * 3) / 4) - pad;
    }

    function safeJsonParse(str, fallback) {
        try {
            const jsonStr = str === undefined || str === null ? "" : String(str);
            return JSON.parse(jsonStr);
        } catch (err) {
            return fallback;
        }
    }

    function shCommand(script, args) {
        const cmd = ["sh", "-c", String(script), "x"];
        if (args !== undefined && args !== null) {
            const list = Array.isArray(args) ? args : [args];
            for (let idx = 0; idx < list.length; idx++)
                cmd.push(String(list[idx]));
        }
        return cmd;
    }

    function isRawSource(source) {
        if (!source)
            return false;
        const value = String(source);
        return value.startsWith("file:") || value.startsWith("data:") || value.startsWith("/") || value.startsWith("qrc:");
    }

    function safeIconPath(name) {
        if (!name || typeof Quickshell === "undefined" || !Quickshell.iconPath)
            return "";
        try {
            return Quickshell.iconPath(String(name), true) || "";
        } catch (_) {
            return "";
        }
    }

    function resolveDesktopEntry(idOrName) {
        const key = String(idOrName || "");
        if (!key || typeof DesktopEntries === "undefined")
            return null;
        try {
            return (DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(key) : null) || (DesktopEntries.byId ? DesktopEntries.byId(key) : null) || null;
        } catch (_) {
            return null;
        }
    }

    function themedOrRaw(source) {
        const value = String(source || "");
        if (!value)
            return "";
        return isRawSource(value) ? value : safeIconPath(value);
    }

    function resolveIconSource(key, providedOrFallback, maybeFallback) {
        const haveProvided = arguments.length >= 3;
        const providedIcon = haveProvided ? providedOrFallback : null;
        const fallbackCandidate = haveProvided ? maybeFallback : providedOrFallback;

        const entry = resolveDesktopEntry(key);
        const fromEntry = entry && entry.icon ? safeIconPath(entry.icon) : "";
        if (fromEntry)
            return fromEntry;

        const fromKey = themedOrRaw(key);
        if (fromKey)
            return fromKey;

        if (providedIcon) {
            const fromProvided = themedOrRaw(providedIcon);
            if (fromProvided)
                return fromProvided;
        }

        const fallbackName = fallbackCandidate == null ? "application-x-executable" : String(fallbackCandidate);
        return fallbackName ? safeIconPath(fallbackName) : "";
    }

    property var _ledCapsPaths: []
    property var _ledNumPaths: []
    property var _ledScrollPaths: []
    property bool _ledDiscovered: false
    property var _ledState: ({
            caps: false,
            num: false,
            scroll: false
        })
    property var _ledWatchers: []
    property int _pollIntervalNormalMs: 120
    property int _pollIntervalFastMs: 40

    function getLockLedState() {
        return {
            caps: !!utils._ledState.caps,
            num: !!utils._ledState.num,
            scroll: !!utils._ledState.scroll
        };
    }

    function startLockLedWatcher(options) {
        const onChange = options && options.onChange ? options.onChange : null;
        if (onChange)
            utils._ledWatchers.push(onChange);
        if (!utils._ledDiscovered)
            _discoverLedPaths();
        _ensurePolling();
        if (onChange) {
            try {
                onChange(utils.getLockLedState());
            } catch (_) {}
        }
        return function unsubscribe() {
            const idx = utils._ledWatchers.indexOf(onChange);
            if (idx >= 0)
                utils._ledWatchers.splice(idx, 1);
            _maybeStopPolling();
        };
    }

    function _discoverLedPaths() {
        let pending = 3;
        function doneOne() {
            pending -= 1;
            if (pending <= 0) {
                utils._ledDiscovered = true;
                _refreshLedState();
            }
        }
        FileSystemService.listByGlob("/sys/class/leds/*::capslock/brightness", function (lines) {
            utils._ledCapsPaths = lines || [];
            doneOne();
        });
        FileSystemService.listByGlob("/sys/class/leds/*::numlock/brightness", function (lines) {
            utils._ledNumPaths = lines || [];
            doneOne();
        });
        FileSystemService.listByGlob("/sys/class/leds/*::scrolllock/brightness", function (lines) {
            utils._ledScrollPaths = lines || [];
            doneOne();
        });
    }

    function _refreshLedState() {
        const groups = [utils._ledCapsPaths, utils._ledNumPaths, utils._ledScrollPaths];
        const haveAny = (groups[0] && groups[0].length) || (groups[1] && groups[1].length) || (groups[2] && groups[2].length);
        if (!haveAny)
            return;

        FileSystemService.pollGroupsAnyNonzero(groups, function (states) {
            if (!states || states.length < 3)
                return;
            const next = {
                caps: !!states[0],
                num: !!states[1],
                scroll: !!states[2]
            };
            _emitLedIfChanged(next);
        });
    }

    function _emitLedIfChanged(next) {
        const current = utils._ledState || {
            caps: false,
            num: false,
            scroll: false
        };
        if (current.caps === next.caps && current.num === next.num && current.scroll === next.scroll)
            return;

        utils._ledState = next;
        // burst faster briefly to capture rapid toggles
        _fastBurstTimer.restart();

        for (let idx = 0; idx < utils._ledWatchers.length; idx++) {
            const watcher = utils._ledWatchers[idx];
            try {
                watcher(utils.getLockLedState());
            } catch (_) {}
        }
    }

    function _ensurePolling() {
        _pollTimer.interval = utils._pollIntervalNormalMs;
        if (!_pollTimer.running)
            _pollTimer.start();
    }

    function _maybeStopPolling() {
        if (utils._ledWatchers.length > 0)
            return;
        _pollTimer.stop();
        _fastBurstTimer.stop();
        _pollTimer.interval = utils._pollIntervalNormalMs;
    }

    Timer {
        id: _pollTimer
        interval: 100
        repeat: true
        running: false
        onTriggered: utils._refreshLedState()
    }

    Timer {
        id: _fastBurstTimer
        interval: 500
        repeat: false
        onTriggered: {
            _pollTimer.interval = utils._pollIntervalNormalMs;
        }
        onRunningChanged: {
            if (_fastBurstTimer.running) {
                _pollTimer.interval = utils._pollIntervalFastMs;
            }
        }
    }
}
