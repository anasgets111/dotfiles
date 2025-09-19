pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core

Singleton {
  id: utils

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
  readonly property string _ledIntervalSec: "0.04"

  // Reusable LED monitoring components
  property Process _ledStreamProc: Process {
    id: ledProc
    onRunningChanged: if (!running)
      utils._handleLedProcStopped()
  }

  property SplitParser _ledParser: SplitParser {
    id: ledParser
    splitMarker: "\n"
    onRead: line => utils._parseLedLine(line)
  }

  // Utility functions
  function _destroy(obj) {
    try {
      if (obj?.destroy)
        obj.destroy();
    } catch (_) {}
  }

  function _stopProc(proc) {
    try {
      if (proc)
        proc.running = false;
    } catch (_) {}
  }

  // LED discovery and monitoring
  function _discoverLedPaths() {
    let pending = 3;
    const doneOne = () => {
      if (--pending <= 0) {
        _ledDiscovered = true;
        _maybeStartOrStopStream();
      }
    };

    FileSystemService.listByGlob("/sys/class/leds/*::capslock/brightness", lines => {
      _ledCapsPaths = lines || [];
      doneOne();
    });
    FileSystemService.listByGlob("/sys/class/leds/*::numlock/brightness", lines => {
      _ledNumPaths = lines || [];
      doneOne();
    });
    FileSystemService.listByGlob("/sys/class/leds/*::scrolllock/brightness", lines => {
      _ledScrollPaths = lines || [];
      doneOne();
    });
  }

  function _haveAnyLedPaths() {
    return _ledCapsPaths.length || _ledNumPaths.length || _ledScrollPaths.length;
  }

  function _parseLedLine(line) {
    const parts = String(line).trim().split(/\s+/);
    if (parts.length >= 3) {
      _emitLedIfChanged({
        caps: parts[0] === "1",
        num: parts[1] === "1",
        scroll: parts[2] === "1"
      });
    }
  }

  function _emitLedIfChanged(next) {
    const current = _ledState;
    if (current.caps === next.caps && current.num === next.num && current.scroll === next.scroll)
      return;

    _ledState = next;

    for (let i = _ledWatchers.length - 1; i >= 0; i--) {
      try {
        _ledWatchers[i](getLockLedState());
      } catch (err) {
        console.warn("LED watcher callback removed due to error:", err);
        _ledWatchers.splice(i, 1);
      }
    }
    _maybeStartOrStopStream();
  }

  function _composeLedLoopScript() {
    const quotePaths = paths => FileSystemService._quotePaths(paths);
    const capsList = quotePaths(_ledCapsPaths) || ":";
    const numList = quotePaths(_ledNumPaths) || ":";
    const scrollList = quotePaths(_ledScrollPaths) || ":";

    return `while true; do
            g0=0; for p in ${capsList}; do v=$(cat "$p" 2>/dev/null || echo 0); if [ "$v" -gt 0 ]; then g0=1; break; fi; done;
            g1=0; for p in ${numList}; do v=$(cat "$p" 2>/dev/null || echo 0); if [ "$v" -gt 0 ]; then g1=1; break; fi; done;
            g2=0; for p in ${scrollList}; do v=$(cat "$p" 2>/dev/null || echo 0); if [ "$v" -gt 0 ]; then g2=1; break; fi; done;
            printf "%s %s %s\n" "$g0" "$g1" "$g2";
            sleep ${_ledIntervalSec};
        done`;
  }

  function _startLedStream() {
    if (_ledStreamProc.running || !_haveAnyLedPaths())
      return;

    _ledStreamProc.command = ["sh", "-lc", _composeLedLoopScript()];
    _ledStreamProc.stdout = _ledParser;
    _ledStreamProc.running = true;
  }

  function _stopLedStream() {
    _stopProc(_ledStreamProc);
  }

  function _handleLedProcStopped() {
    if (_ledWatchers.length > 0 && _haveAnyLedPaths()) {
      _startLedStream();
    }
  }

  function _maybeStartOrStopStream() {
    if (_ledWatchers.length > 0 && _ledDiscovered && _haveAnyLedPaths()) {
      _startLedStream();
    } else if (_ledWatchers.length === 0) {
      _stopLedStream();
    }
  }

  function getLockLedState() {
    return {
      caps: !!_ledState.caps,
      num: !!_ledState.num,
      scroll: !!_ledState.scroll
    };
  }

  function startLockLedWatcher(options) {
    const onChange = options?.onChange;
    if (onChange)
      _ledWatchers.push(onChange);
    if (!_ledDiscovered)
      _discoverLedPaths();
    _maybeStartOrStopStream();
    if (onChange) {
      try {
        onChange(getLockLedState());
      } catch (_) {}
    }
    return () => {
      const idx = _ledWatchers.indexOf(onChange);
      if (idx >= 0)
        _ledWatchers.splice(idx, 1);
      _maybeStartOrStopStream();
    };
  }

  function base64Size(b64) {
    const str = String(b64 || "");
    const len = str.length;
    const pad = str.endsWith("==") ? 2 : str.endsWith("=") ? 1 : 0;
    return Math.floor((len * 3) / 4) - pad;
  }

  function isImageMime(mime) {
    return sanitizeMimeType(mime).indexOf("image/") === 0;
  }

  function isRawSource(source) {
    if (!source)
      return false;
    const value = String(source);
    return value.startsWith("file:") || value.startsWith("data:") || value.startsWith("/") || value.startsWith("qrc:");
  }

  function isTextMime(mime) {
    const sanitized = sanitizeMimeType(mime);
    return sanitized === "text" || sanitized === "text/plain" || sanitized.indexOf("text/") === 0;
  }

  function mergeObjects(objA, objB) {
    const out = {};
    for (const prop in objA) {
      if (Object.prototype.hasOwnProperty.call(objA, prop))
        out[prop] = objA[prop];
    }
    for (const prop in objB) {
      if (Object.prototype.hasOwnProperty.call(objB, prop))
        out[prop] = objB[prop];
    }
    return out;
  }

  function resolveDesktopEntry(idOrName) {
    const key = String(idOrName || "");
    if (!key || typeof DesktopEntries === "undefined")
      return null;
    try {
      return (DesktopEntries.heuristicLookup(key)) || (DesktopEntries.byId(key)) || null;
    } catch (_) {
      return null;
    }
  }

  function resolveIconSource(key, providedOrFallback, maybeFallback) {
    const haveProvided = arguments.length >= 3;
    const providedIcon = haveProvided ? providedOrFallback : null;
    const fallbackCandidate = haveProvided ? maybeFallback : providedOrFallback;

    const entry = resolveDesktopEntry(key);
    const fromEntry = entry?.icon ? safeIconPath(entry.icon) : "";
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

    const fallbackName = fallbackCandidate ?? "application-x-executable";
    return fallbackName ? safeIconPath(fallbackName) : "";
  }

  function runCmd(cmd, onDone, parent) {
    if (!cmd || !Array.isArray(cmd) || cmd.length === 0) {
      onDone("");
      return;
    }

    const host = parent || utils;
    const proc = Qt.createQmlObject('import Quickshell.Io; Process {}', host);
    const stdio = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc);
    const watchdog = Qt.createQmlObject('import QtQuick; Timer { interval: 10000; repeat: false }', proc);

    proc.stdout = stdio;

    const cleanup = () => {
      watchdog.stop();
      _destroy(watchdog);
      _destroy(stdio);
      _destroy(proc);
    };

    watchdog.triggered.connect(() => {
      _stopProc(proc);
      onDone(stdio.text || "");
      cleanup();
    });

    stdio.onStreamFinished.connect(() => {
      onDone(stdio.text);
      cleanup();
    });

    watchdog.start();
    proc.command = cmd;
    proc.running = true;
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

  function safeJsonParse(str, fallback) {
    try {
      return JSON.parse(str === undefined || str === null ? "" : String(str));
    } catch (err) {
      return fallback;
    }
  }

  function sanitizeMimeType(input) {
    const value = String(input || "");
    const mimePattern = new RegExp('^[a-z0-9](?:[a-z0-9.+\\-])*/[a-z0-9](?:[a-z0-9.+\\-])*$', 'i');
    return mimePattern.test(value) ? value : "";
  }

  function shCommand(script, args) {
    const cmd = ["sh", "-c", String(script), "x"];
    if (args !== undefined && args !== null) {
      const list = Array.isArray(args) ? args : [args];
      cmd.push(...list.map(String));
    }
    return cmd;
  }

  function stripAnsi(input) {
    const value = String(input);
    const ansiPattern = /\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07]*(\x07|\x1B\\))/g;
    return value.replace(ansiPattern, "");
  }

  function themedOrRaw(source) {
    const value = String(source || "");
    return value ? (isRawSource(value) ? value : safeIconPath(value)) : "";
  }

  function utf8Size(input) {
    try {
      return unescape(encodeURIComponent(String(input))).length;
    } catch (_) {
      return String(input || "").length * 3;
    }
  }
}
