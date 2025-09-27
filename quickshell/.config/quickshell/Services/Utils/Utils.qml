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

  function _handleLedLine(rawLine) {
    const [c, n, s] = String(rawLine).trim().split(/\s+/);
    if (c === undefined || n === undefined || s === undefined)
      return;

    const next = {
      caps: c === "1",
      num: n === "1",
      scroll: s === "1"
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

    let pending = _ledKeys.length;
    for (const k of _ledKeys) {
      FileSystemService.listByGlob(`/sys/class/leds/*::${k}lock/brightness`, lines => {
        _ledPaths[k] = lines || [];
        if (--pending === 0) {
          _ledDiscovered = true;
          if (readyCb)
            readyCb();
        }
      });
    }
  }

  function _composeLedScript() {
    const toList = paths => {
      const quoted = FileSystemService._quotePaths(paths);
      return quoted && quoted.length ? quoted : ":"; // ":" is a no-op list
    };

    return `while true; do
    g0=0; for p in ${toList(_ledPaths.caps)}; do v=$(cat "$p" 2>/dev/null || echo 0); [ "$v" -gt 0 ] && { g0=1; break; }; done;
    g1=0; for p in ${toList(_ledPaths.num)}; do v=$(cat "$p" 2>/dev/null || echo 0); [ "$v" -gt 0 ] && { g1=1; break; }; done;
    g2=0; for p in ${toList(_ledPaths.scroll)}; do v=$(cat "$p" 2>/dev/null || echo 0); [ "$v" -gt 0 ] && { g2=1; break; }; done;
    printf "%s %s %s\\n" "$g0" "$g1" "$g2";
    sleep ${_ledIntervalSec};
  done`;
  }

  function _startLedMonitoring() {
    if (!_ledDiscovered || _ledStreamProc.running)
      return;
    if (!(_ledPaths.caps.length || _ledPaths.num.length || _ledPaths.scroll.length))
      return;
    _ledStreamProc.command = ["sh", "-lc", _composeLedScript()];
    _ledStreamProc.running = true;
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

    const cleanup = () => {
      watchdog.stop();
      try {
        watchdog.destroy();
      } catch (_) {}
      try {
        stdio.destroy();
      } catch (_) {}
      try {
        proc.destroy();
      } catch (_) {}
    };

    watchdog.triggered.connect(() => {
      try {
        proc.running = false;
      } catch (_) {}
      onComplete(stdio.text || "");
      cleanup();
    });

    stdio.onStreamFinished.connect(() => {
      onComplete(stdio.text);
      cleanup();
    });

    watchdog.start();
    proc.stdout = stdio;
    proc.command = cmd;
    proc.running = true;
  }

  function safeJsonParse(str, fallback) {
    try {
      return JSON.parse(str === undefined || str === null ? "" : String(str));
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
    const ansiPattern = /\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07]*(\x07|\x1B\\))/g;
    return value.replace(ansiPattern, "");
  }
}
