pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: utils

  // ==================== LED Lock State Monitoring ====================

  property bool capsLock: false
  property bool numLock: false
  property bool scrollLock: false
  property var ledWatchers: []
  property var _cachedState: ({
      caps: false,
      num: false,
      scroll: false
    })

  property string capsPath: ""
  property string numPath: ""
  property string scrollPath: ""

  readonly property Process capsReader: Process {
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => {
        const newState = parseInt(line.trim() || "0") > 0;
        if (newState !== utils.capsLock) {
          utils.capsLock = newState;
          utils.notifyWatchers();
        }
      }
    }
  }

  readonly property Process numReader: Process {
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => {
        const newState = parseInt(line.trim() || "0") > 0;
        if (newState !== utils.numLock) {
          utils.numLock = newState;
          utils.notifyWatchers();
        }
      }
    }
  }

  readonly property Process scrollReader: Process {
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => {
        const newState = parseInt(line.trim() || "0") > 0;
        if (newState !== utils.scrollLock) {
          utils.scrollLock = newState;
          utils.notifyWatchers();
        }
      }
    }
  }

  readonly property Timer ledMonitor: Timer {
    interval: 40
    running: false
    repeat: true
    onTriggered: {
      if (utils.capsPath && !utils.capsReader.running)
        utils.capsReader.running = true;
      if (utils.numPath && !utils.numReader.running)
        utils.numReader.running = true;
      if (utils.scrollPath && !utils.scrollReader.running)
        utils.scrollReader.running = true;
    }
  }

  Component.onCompleted: {
    runCmd(["sh", "-c", "ls /sys/class/leds/*capslock/brightness 2>/dev/null | head -1"], path => {
      capsPath = path.trim();
      if (capsPath)
        capsReader.command = ["cat", capsPath];
    });
    runCmd(["sh", "-c", "ls /sys/class/leds/*numlock/brightness 2>/dev/null | head -1"], path => {
      numPath = path.trim();
      if (numPath)
        numReader.command = ["cat", numPath];
    });
    runCmd(["sh", "-c", "ls /sys/class/leds/*scrolllock/brightness 2>/dev/null | head -1"], path => {
      scrollPath = path.trim();
      if (scrollPath)
        scrollReader.command = ["cat", scrollPath];
      ledMonitor.running = true;
    });
  }

  function notifyWatchers() {
    _cachedState.caps = capsLock;
    _cachedState.num = numLock;
    _cachedState.scroll = scrollLock;

    for (let i = ledWatchers.length - 1; i >= 0; i--) {
      try {
        ledWatchers[i](_cachedState);
      } catch (err) {
        console.warn("LED watcher error:", err);
        ledWatchers.splice(i, 1);
      }
    }
  }

  // ==================== Command Execution ====================

  readonly property var commandSlots: Array.from({
    length: 3
  }, () => {
    const process = Qt.createQmlObject('import Quickshell.Io; Process {}', utils);
    const collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { waitForEnd: true }', process);
    process.stdout = collector;

    const slot = {
      process,
      collector,
      busy: false,
      callback: null
    };
    collector.onStreamFinished.connect(() => {
      if (!slot.busy)
        return;
      const output = collector.text;
      const callback = slot.callback;
      slot.busy = false;
      slot.callback = null;
      if (callback)
        try {
          callback(output);
        } catch (_) {}
    });

    return slot;
  })

  Component.onDestruction: {
    ledWatchers.length = 0;
    ledMonitor.running = false;
    capsReader.running = false;
    numReader.running = false;
    scrollReader.running = false;
    commandSlots.forEach(slot => {
      if (slot.process.running)
        slot.process.running = false;
    });
  }

  // ==================== Public API ====================

  function getLockLedState() {
    return {
      caps: capsLock,
      num: numLock,
      scroll: scrollLock
    };
  }

  function startLockLedWatcher(options) {
    const handler = options?.onChange;
    if (typeof handler !== "function")
      return () => {};

    if (!ledWatchers.includes(handler)) {
      ledWatchers.push(handler);
      try {
        handler(getLockLedState());
      } catch (_) {}
    }

    return () => {
      const idx = ledWatchers.indexOf(handler);
      if (idx >= 0)
        ledWatchers.splice(idx, 1);
    };
  }

  function runCmd(cmd, onDone) {
    if (!Array.isArray(cmd) || cmd.length === 0) {
      if (typeof onDone === "function")
        onDone("");
      return;
    }

    const slot = commandSlots.find(s => !s.busy) || commandSlots[0];
    if (slot.process.running)
      slot.process.running = false;

    slot.busy = true;
    slot.callback = typeof onDone === "function" ? onDone : null;
    slot.process.command = cmd;
    slot.process.running = true;
  }

  function shCommand(script, ...args) {
    return ["sh", "-c", String(script), "x", ...args.map(String)];
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

  function safeJsonParse(str, fallback) {
    try {
      return JSON.parse(String(str ?? ""));
    } catch (_) {
      return fallback;
    }
  }

  function stripAnsi(input) {
    return String(input || "").replace(/\x1B(?:[@-Z\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07]*(\x07|\x1B\))/g, "");
  }
}
