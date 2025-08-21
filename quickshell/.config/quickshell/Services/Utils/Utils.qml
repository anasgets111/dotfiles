// Utils.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core

Singleton {
    id: utils

    // Run a command and collect stdout; optionally parent the Process
    function runCmd(cmd, onDone, parent) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process { }', parent || utils);
        var c = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', p);
        p.stdout = c;
        c.onStreamFinished.connect(function () {
            try {
                if (onDone)
                    onDone(c.text);
            } finally {
                // Clean up transient objects to avoid leaks
                try {
                    c.destroy();
                } catch (e) {}
                try {
                    p.destroy();
                } catch (e2) {}
            }
        });
        p.command = cmd;
        p.running = true;
    }

    // Remove ANSI escape sequences
    function stripAnsi(str) {
        return String(str).replace(/\x1B\[[0-9;]*[A-Za-z]/g, "");
    }

    // Shallow merge (b overrides a)
    function mergeObjects(a, b) {
        var out = {};
        for (var k in a)
            out[k] = a[k];
        for (var k2 in b)
            out[k2] = b[k2];
        return out;
    }

    // Validate and sanitize a MIME type string; returns "" if invalid
    function sanitizeMimeType(m) {
        var s = String(m || "");
        return s.match(/^[a-z0-9][a-z0-9+.-]*\/[a-z0-9][a-z0-9+.-]*$/i) ? s : "";
    }

    // Predicate helpers for common MIME families
    function isTextMime(m) {
        var s = sanitizeMimeType(m);
        return s === "text" || s === "text/plain" || s.indexOf("text/") === 0;
    }

    function isImageMime(m) {
        var s = sanitizeMimeType(m);
        return s.indexOf("image/") === 0;
    }

    // Compute UTF-8 byte length of a JS string
    function utf8Size(str) {
        try {
            return unescape(encodeURIComponent(String(str))).length;
        } catch (e) {
            var s = String(str);
            return s.length * 3;
        }
    }

    // Compute decoded size in bytes from base64 text
    function base64Size(b64) {
        var len = String(b64 || "").length;
        var pad = (len >= 2 && b64.endsWith("==")) ? 2 : (len >= 1 && b64.endsWith("=")) ? 1 : 0;
        return Math.floor((len * 3) / 4) - pad;
    }

    // Safe JSON.parse with fallback on error
    function safeJsonParse(str, fallback) {
        try {
            var s = (str === undefined || str === null) ? "" : String(str);
            return JSON.parse(s);
        } catch (e) {
            return fallback;
        }
    }

    // Build a safe ["sh", "-c", script, "$0", ...args] array
    // Use $1..$N inside 'script' to reference provided args.
    function shCommand(script, args) {
        var cmd = ["sh", "-c", String(script), "x"]; // $0 placeholder
        if (args) {
            var list = args;
            if (list instanceof Array === false) {
                list = [args];
            }
            for (var i = 0; i < list.length; i++)
                cmd.push(String(list[i]));
        }
        return cmd;
    }

    // =====================
    // Lock LED Watcher API
    // =====================
    // Public:
    // - startLockLedWatcher({ onChange: fn }) -> function unsubscribe()
    // - getLockLedState() -> { caps: bool, num: bool, scroll: bool }

    // Internal state
    property var _ledCapsPaths: []
    property var _ledNumPaths: []
    property var _ledScrollPaths: []
    property bool _ledDiscovered: false
    property var _ledState: ({
            caps: false,
            num: false,
            scroll: false
        })
    property var _ledWatchers: [] // array of functions
    property bool _ledUdevActive: false
    property int _ledRestartBackoffMs: 250

    function getLockLedState() {
        // Return a shallow copy to avoid accidental mutation by callers
        return {
            caps: !!utils._ledState.caps,
            num: !!utils._ledState.num,
            scroll: !!utils._ledState.scroll
        };
    }

    function startLockLedWatcher(opts) {
        var cb = opts && opts.onChange ? opts.onChange : null;
        if (cb)
            utils._ledWatchers.push(cb);
        // Ensure discovery and backend running
        if (!utils._ledDiscovered)
            utils._ledDiscover();
        utils._ensureLedBackend();
        // Fire immediately with current state so UI can sync
        if (cb)
            try {
                cb(utils.getLockLedState());
            } catch (e) {}
        // Return unsubscribe function
        return function () {
            var idx = utils._ledWatchers.indexOf(cb);
            if (idx >= 0)
                utils._ledWatchers.splice(idx, 1);
            // Stop backends if no watchers
            utils._maybeStopLedBackend();
        };
    }

    function _ledDiscover() {
        var pending = 3;
        function doneOne() {
            pending -= 1;
            if (pending <= 0) {
                utils._ledDiscovered = true;
                utils._refreshLedState();
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
        if (!groups[0].length && !groups[1].length && !groups[2].length) {
            // Nothing to read; keep defaults
            return;
        }
        FileSystemService.pollGroupsAnyNonzero(groups, function (states) {
            if (!states || states.length < 3)
                return;
            const next = {
                caps: !!states[0],
                num: !!states[1],
                scroll: !!states[2]
            };
            utils._emitLedIfChanged(next);
        });
    }

    function _emitLedIfChanged(next) {
        const cur = utils._ledState || {
            caps: false,
            num: false,
            scroll: false
        };
        if (cur.caps === next.caps && cur.num === next.num && cur.scroll === next.scroll)
            return;
        utils._ledState = next;
        // Notify all watchers; guard each callback
        for (var i = 0; i < utils._ledWatchers.length; i++) {
            var fn = utils._ledWatchers[i];
            try {
                fn(utils.getLockLedState());
            } catch (e) {}
        }
    }

    // Backend management
    function _ensureLedBackend() {
        // Prefer udev event stream; fallback to polling
        if (udevDebounce.running)
            udevDebounce.stop();
        // Start udev monitor; on failure, _udevProc.running will be false and we switch to polling.
        if (!_udevProc.running) {
            _udevProc.running = true;
        }
        // Start a safety poll at a low cadence until we confirm udev events (first line)
        _pollTimer.interval = 500;
        _pollTimer.start();
    }

    function _maybeStopLedBackend() {
        if (utils._ledWatchers.length > 0)
            return;
        // No watchers: stop processes/timers
        if (_udevProc.running)
            _udevProc.running = false;
        _pollTimer.stop();
        udevDebounce.stop();
        utils._ledRestartBackoffMs = 250;
    }

    Timer {
        id: udevDebounce
        interval: 75
        repeat: false
        onTriggered: utils._refreshLedState()
    }

    // Polling fallback (also initial safety poll)
    Timer {
        id: _pollTimer
        interval: 250
        repeat: true
        running: false
        onTriggered: utils._refreshLedState()
    }

    Process {
        id: _udevProc
        // Use both --kernel and --udev to catch all change events on LED subsystem
        command: ["udevadm", "monitor", "--kernel", "--udev", "--subsystem-match=leds"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                var s = String(line || "").trim();
                if (!s)
                    return;
                // Only treat actual event lines as a signal. udevadm prints a banner at startup.
                if (!(/^KERNEL\[/i.test(s) || /^UDEV\[/i.test(s)))
                    return;
                if (!utils._ledUdevActive) {
                    utils._ledUdevActive = true;
                    _pollTimer.stop();
                }
                udevDebounce.restart();
            }
        }
        onRunningChanged: {
            // If udev monitor exits unexpectedly and we still have watchers, fallback and schedule restart
            if (!_udevProc.running) {
                utils._ledUdevActive = false;
                if (utils._ledWatchers.length > 0) {
                    // Ensure polling is running
                    _pollTimer.interval = 300;
                    _pollTimer.start();
                    // Attempt restart with backoff
                    _udevRestartTimer.interval = utils._ledRestartBackoffMs;
                    _udevRestartTimer.start();
                    utils._ledRestartBackoffMs = Math.min(30000, Math.max(250, utils._ledRestartBackoffMs * 2));
                }
            } else {
                // Reset backoff when successfully running
                utils._ledRestartBackoffMs = 250;
            }
        }
    }

    Timer {
        id: _udevRestartTimer
        repeat: false
        onTriggered: {
            if (utils._ledWatchers.length > 0 && !_udevProc.running) {
                _udevProc.running = true;
            }
        }
    }
}
