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
    _stopLedMonitoring();
    _ledWatchers.splice(0, _ledWatchers.length);
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

    let done = 0;
    _ledKeys.forEach(k => {
      FileSystemService.listByGlob(`/sys/class/leds/*::${k}lock/brightness`, lines => {
        _ledPaths[k] = lines || [];
        if (++done === _ledKeys.length) {
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

    const blocks = ["caps", "num", "scroll"].map((k, i) => `
    g${i}=0; for p in ${toList(_ledPaths[k])}; do v=$(cat "$p" 2>/dev/null || echo 0); [ "$v" -gt 0 ] && { g${i}=1; break; }; done;`).join("");

    return `while true; do
    ${blocks}
    printf "%s %s %s\n" "$g0" "$g1" "$g2";
    sleep ${_ledIntervalSec};
  done`;
  }

  function _startLedMonitoring() {
    if (!_ledDiscovered || _ledStreamProc.running)
      return;
    if (!_ledKeys.some(k => (_ledPaths[k] || []).length))
      return;
    _ledStreamProc.command = ["sh", "-lc", _composeLedScript()];
    _ledStreamProc.running = true;
  }

  function _stopLedMonitoring() {
    if (!_ledStreamProc)
      return;
    try {
      if (_ledStreamProc.running)
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
    const onChange = options?.onChange;
    if (typeof onChange === "function" && _ledWatchers.indexOf(onChange) === -1)
      _ledWatchers.push(onChange);

    _detectLedPathsOnce(_startLedMonitoring);

    if (typeof onChange === "function") {
      try {
        onChange(getLockLedState());
      } catch (_) {}
    }

    return () => {
      if (typeof onChange !== "function")
        return;
      const idx = _ledWatchers.indexOf(onChange);
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

    const explicitProvided = arguments.length >= 3 ? providedOrFallback : null;
    const fallbackCandidate = arguments.length >= 3 ? maybeFallback : providedOrFallback;

    const entry = resolveDesktopEntry(key);
    const entryIcon = entry?.icon ? toIcon(entry.icon) : "";
    if (entryIcon)
      return entryIcon;

    const keyIcon = toIcon(key);
    if (keyIcon)
      return keyIcon;

    if (explicitProvided) {
      const providedIcon = toIcon(explicitProvided);
      if (providedIcon)
        return providedIcon;
    }

    const fallbackName = fallbackCandidate ?? "application-x-executable";
    return toIcon(fallbackName);
  }

  function runCmd(cmd, onDone, parent) {
    const onComplete = typeof onDone === "function" ? onDone : () => {};
    if (!cmd || !Array.isArray(cmd) || cmd.length === 0) {
      onComplete("");
      return;
    }

    const host = parent || utils;
    const proc = Qt.createQmlObject('import Quickshell.Io; Process {}', host);
    const stdio = Qt.createQmlObject('import Quickshell.Io; StdioCollector {}', proc);
    const watchdog = Qt.createQmlObject('import QtQuick; Timer { interval: 10000; repeat: false }', proc);

    const destroyAll = list => list.forEach(o => {
        try {
          o.destroy();
        } catch (_) {}
      });
    const finish = text => {
      onComplete(text);
      watchdog.stop();
      destroyAll([watchdog, stdio, proc]);
    };

    watchdog.triggered.connect(() => {
      try {
        proc.running = false;
      } catch (_) {}
      ;
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
    const cmd = ["sh", "-c", String(script), "x"];
    if (args !== undefined && args !== null) {
      const list = Array.isArray(args) ? args : [args];
      cmd.push(...list.map(String));
    }
    return cmd;
  }

  function stripAnsi(input) {
    const value = String(input || "");
    const ansiPattern = /\x1B(?:[@-Z\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07]*(\x07|\x1B\))/g;
    return value.replace(ansiPattern, "");
  }
}
