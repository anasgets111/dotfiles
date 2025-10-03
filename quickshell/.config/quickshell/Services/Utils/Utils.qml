pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core

Singleton {
  id: utils

  // Slim LED monitor (same outcome, smaller surface)
  readonly property string _ledIntervalSec: "0.04"
  readonly property var _ledKeys: ["caps", "num", "scroll"]
  property var _ledPaths: ({
      caps: [],
      num: [],
      scroll: []
    })
  property bool _ledDiscovered: false
  property var _ledState: ({
      caps: false,
      num: false,
      scroll: false
    })
  property var _ledWatchers: []

  property Process _ledStreamProc: Process {
    stdout: utils._ledParser
  }
  property SplitParser _ledParser: SplitParser {
    splitMarker: "\n"
    onRead: line => utils._handleLedLine(line)
  }

  Component.onCompleted: _detectLedPathsOnce(_startLedMonitoring)
  Component.onDestruction: {
    if (_ledStreamProc) {
      _stopLedMonitoring();
    }
    _ledWatchers.length = 0;
  }

  function _handleLedLine(rawLine) {
    const parts = String(rawLine).trim().split(/\s+/, 3);
    if (parts.length !== 3)
      return;

    const next = {
      caps: parts[0] === "1",
      num: parts[1] === "1",
      scroll: parts[2] === "1"
    };
    if (next.caps === _ledState.caps && next.num === _ledState.num && next.scroll === _ledState.scroll)
      return;

    _ledState = next;
    const snapshot = getLockLedState();

    for (let i = _ledWatchers.length - 1; i >= 0; i--) {
      const fn = _ledWatchers[i];
      try {
        fn(snapshot);
      } catch (err) {
        console.warn("LED watcher removed after error:", err);
        _ledWatchers.splice(i, 1);
      }
    }
  }

  function _detectLedPathsOnce(onReady) {
    const readyCb = typeof onReady === "function" ? onReady : null;
    if (_ledDiscovered) {
      if (readyCb)
        readyCb();
      return;
    }

    let remaining = _ledKeys.length;
    _ledKeys.forEach(key => {
      FileSystemService.listByGlob(`/sys/class/leds/*::${key}lock/brightness`, lines => {
        _ledPaths[key] = lines || [];
        if (--remaining === 0) {
          _ledDiscovered = true;
          if (readyCb)
            readyCb();
        }
      });
    });
  }

  function _composeLedScript() {
    const toList = paths => {
      const quoted = FileSystemService._quotePaths(paths);
      return quoted && quoted.length ? quoted : ":"; // ":" is a no-op list
    };

    const blocks = _ledKeys.map((key, index) => `
    g${index}=0; for p in ${toList(_ledPaths[key])}; do v=$(cat "$p" 2>/dev/null || echo 0); [ "$v" -gt 0 ] && { g${index}=1; break; }; done;`).join("");

    return `while true; do
    ${blocks}
    printf "%s %s %s\n" "$g0" "$g1" "$g2";
    sleep ${_ledIntervalSec};
  done`;
  }

  function _startLedMonitoring() {
    if (!_ledDiscovered || _ledStreamProc.running || !_ledKeys.some(key => (_ledPaths[key] || []).length))
      return;
    _ledStreamProc.command = ["sh", "-lc", _composeLedScript()];
    _ledStreamProc.running = true;
  }

  function _stopLedMonitoring() {
    if (!_ledStreamProc)
      return;
    try {
      _ledStreamProc.running = false;
    } catch (_) {}
    _ledStreamProc.command = [];
  }

  function getLockLedState() {
    return {
      caps: !!_ledState.caps,
      num: !!_ledState.num,
      scroll: !!_ledState.scroll
    };
  }

  function startLockLedWatcher(options) {
    const handler = typeof options?.onChange === "function" ? options.onChange : null;
    if (handler && _ledWatchers.indexOf(handler) === -1)
      _ledWatchers.push(handler);

    _detectLedPathsOnce(_startLedMonitoring);

    if (handler) {
      try {
        handler(getLockLedState());
      } catch (_) {}
    }

    return () => {
      if (!handler)
        return;
      const idx = _ledWatchers.indexOf(handler);
      if (idx >= 0)
        _ledWatchers.splice(idx, 1);
    };
  }

  function resolveDesktopEntry(idOrName) {
    const key = String(idOrName || "");
    if (!key || typeof DesktopEntries === "undefined")
      return null;

    try {
      return DesktopEntries.heuristicLookup(key) || DesktopEntries.byId(key) || null;
    } catch (_) {
      return null;
    }
  }

  function resolveIconSource(key, providedOrFallback, maybeFallback) {
    const toIcon = candidate => {
      if (!candidate)
        return "";
      const value = String(candidate);
      if (value.startsWith("file:") || value.startsWith("data:") || value.startsWith("/") || value.startsWith("qrc:"))
        return value;

      if (typeof Quickshell === "undefined" || !Quickshell.iconPath)
        return "";
      try {
        return Quickshell.iconPath(value, true) || "";
      } catch (_) {
        return "";
      }
    };

    const hasFallback = arguments.length >= 3;
    const explicitProvided = hasFallback ? providedOrFallback : null;
    const fallbackCandidate = hasFallback ? maybeFallback : providedOrFallback;

    const entry = resolveDesktopEntry(key);
    const resolved = toIcon(entry?.icon) || toIcon(key) || toIcon(explicitProvided);
    if (resolved)
      return resolved;

    return toIcon(fallbackCandidate ?? "application-x-executable");
  }

  function runCmd(cmd, onDone, parent) {
    const onComplete = typeof onDone === "function" ? onDone : () => {};
    if (!Array.isArray(cmd) || cmd.length === 0) {
      onComplete("");
      return;
    }

    const host = parent || utils;
    const proc = Qt.createQmlObject('import Quickshell.Io; Process {}', host);
    const stdio = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc);
    const watchdog = Qt.createQmlObject('import QtQuick; Timer { interval: 10000; repeat: false }', proc);

    const safeDestroy = obj => {
      if (!obj)
        return;
      try {
        if (obj && typeof obj.destroy === 'function')
          obj.destroy();
      } catch (_) {}
    };
    const finish = text => {
      try {
        onComplete(text);
      } finally {
        if (watchdog)
          watchdog.stop();
        [watchdog, stdio, proc].forEach(safeDestroy);
      }
    };

    watchdog.triggered.connect(() => {
      try {
        proc.running = false;
      } catch (_) {}
      finish(stdio.text || "");
    });
    stdio.onStreamFinished.connect(() => finish(stdio.text));

    proc.stdout = stdio;
    proc.command = cmd;
    watchdog.start();
    proc.running = true;
  }

  function safeJsonParse(str, fallback) {
    try {
      return JSON.parse(String(str ?? ""));
    } catch (_) {
      return fallback;
    }
  }

  function shCommand(script, args) {
    const extras = args == null ? [] : (Array.isArray(args) ? args : [args]);
    return ["sh", "-c", String(script), "x", ...extras.map(String)];
  }

  function stripAnsi(input) {
    const value = String(input || "");
    const ansiPattern = /\x1B(?:[@-Z\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07]*(\x07|\x1B\))/g;
    return value.replace(ansiPattern, "");
  }
}
