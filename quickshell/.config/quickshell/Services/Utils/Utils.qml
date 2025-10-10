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
  readonly property var _ledState: ({
      caps: false,
      num: false,
      scroll: false
    })

  readonly property Process ledMonitor: Process {
    command: ["sh", "-c", "set -- /sys/class/leds/*capslock/brightness;caps=$1;set -- /sys/class/leds/*numlock/brightness;num=$1;set -- /sys/class/leds/*scrolllock/brightness;scroll=$1;while :;do read c < \"$caps\" 2>/dev/null||c=0;read n < \"$num\" 2>/dev/null||n=0;read s < \"$scroll\" 2>/dev/null||s=0;printf '%s %s %s\\n' \"$c\" \"$n\" \"$s\";sleep 0.04;done"]
    running: true
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: line => {
        if (line.length < 5)
          return;

        const capsState = line[0] !== "0";
        const numState = line[2] !== "0";
        const scrollState = line[4] !== "0";

        if (capsState === utils.capsLock && numState === utils.numLock && scrollState === utils.scrollLock)
          return;

        utils.capsLock = capsState;
        utils.numLock = numState;
        utils.scrollLock = scrollState;

        if (utils.ledWatchers.length === 0)
          return;

        utils._ledState.caps = utils.capsLock;
        utils._ledState.num = utils.numLock;
        utils._ledState.scroll = utils.scrollLock;

        for (let i = utils.ledWatchers.length - 1; i >= 0; i--) {
          const watcher = utils.ledWatchers[i];
          if (typeof watcher !== "function") {
            utils.ledWatchers.splice(i, 1);
            continue;
          }
          try {
            watcher(utils._ledState);
          } catch (err) {
            console.warn("LED watcher error:", err);
            utils.ledWatchers.splice(i, 1);
          }
        }
      }
    }
    onRunningChanged: {
      if (!running) {
        // Process stopped unexpectedly, restart it
        console.warn("LED monitor stopped, restarting...");
        Qt.callLater(() => {
          if (utils.ledMonitor) {
            utils.ledMonitor.running = true;
          }
        });
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
      if (typeof callback === "function")
        try {
          callback(output);
        } catch (_) {}
    });

    return slot;
  })

  Component.onDestruction: {
    if (ledMonitor.running)
      ledMonitor.running = false;
    ledWatchers.length = 0;
    commandSlots.forEach(slot => {
      if (slot.process.running)
        slot.process.running = false;
    });
  }

  // ==================== Public API ====================
  function getLockLedState() {
    _ledState.caps = capsLock;
    _ledState.num = numLock;
    _ledState.scroll = scrollLock;
    return _ledState;
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
