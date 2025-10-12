pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool capsLock: false
  readonly property int commandSlotCount: 3
  readonly property var commandSlots: Array.from({
    length: root.commandSlotCount
  }, () => {
    const process = Qt.createQmlObject("import Quickshell.Io; Process {}", root);
    const collector = Qt.createQmlObject("import Quickshell.Io; StdioCollector { waitForEnd: true }", process);
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
      if (typeof callback === "function") {
        try {
          callback(output);
        } catch (_) {}
      }
    });
    return slot;
  })
  readonly property Process ledMonitor: Process {
    command: ["sh", "-c", `
      caps_glob=/sys/class/leds/*capslock/brightness
      num_glob=/sys/class/leds/*numlock/brightness
      scroll_glob=/sys/class/leds/*scrolllock/brightness
      set -- $caps_glob; caps=$1
      set -- $num_glob; num=$1
      set -- $scroll_glob; scroll=$1
      last=""
      while :; do
        c=$(cat "$caps" 2>/dev/null || echo 0)
        n=$(cat "$num" 2>/dev/null || echo 0)
        s=$(cat "$scroll" 2>/dev/null || echo 0)
        cur="$c $n $s"
        if [ "$cur" != "$last" ]; then
          printf '%s\\n' "$cur"
          last="$cur"
        fi
        sleep 0.1
      done
    `]
    running: true

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: line => {
        const capsState = line[0] !== "0";
        const numState = line[2] !== "0";
        const scrollState = line[4] !== "0";

        if (capsState === root.capsLock && numState === root.numLock && scrollState === root.scrollLock)
          return;
        root.capsLock = capsState;
        root.numLock = numState;
        root.scrollLock = scrollState;

        if (root.ledWatchers.length === 0)
          return;
        const state = {
          caps: capsState,
          num: numState,
          scroll: scrollState
        };

        for (let i = root.ledWatchers.length - 1; i >= 0; i--) {
          const watcher = root.ledWatchers[i];
          if (typeof watcher !== "function") {
            root.ledWatchers.splice(i, 1);
            continue;
          }
          try {
            watcher(state);
          } catch (err) {
            console.warn("LED watcher error:", err);
            root.ledWatchers.splice(i, 1);
          }
        }
      }
    }

    onRunningChanged: {
      if (!running) {
        console.warn("LED monitor stopped, restarting...");
        Qt.callLater(() => {
          if (root.ledMonitor)
            root.ledMonitor.running = true;
        });
      }
    }
  }
  property list<var> ledWatchers: []
  property bool numLock: false
  property bool scrollLock: false

  function getLockLedState() {
    return {
      caps: root.capsLock,
      num: root.numLock,
      scroll: root.scrollLock
    };
  }

  function resolveDesktopEntry(idOrName) {
    const key = String(idOrName ?? "");
    if (!key || typeof DesktopEntries === "undefined")
      return null;
    try {
      return DesktopEntries.heuristicLookup(key) ?? DesktopEntries.byId(key) ?? null;
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
        return Quickshell.iconPath(value, true) ?? "";
      } catch (_) {
        return "";
      }
    };

    const hasFallback = arguments.length >= 3;
    const explicitProvided = hasFallback ? providedOrFallback : null;
    const fallbackCandidate = hasFallback ? maybeFallback : providedOrFallback;

    const entry = root.resolveDesktopEntry(key);
    const resolved = toIcon(entry?.icon) || toIcon(key) || toIcon(explicitProvided);
    return resolved || toIcon(fallbackCandidate ?? "application-x-executable");
  }

  function runCmd(cmd, onDone) {
    if (!Array.isArray(cmd) || cmd.length === 0) {
      if (typeof onDone === "function")
        onDone("");
      return;
    }
    const slot = root.commandSlots.find(s => !s.busy) ?? root.commandSlots[0];
    if (slot.process.running)
      slot.process.running = false;
    slot.busy = true;
    slot.callback = typeof onDone === "function" ? onDone : null;
    slot.process.command = cmd;
    slot.process.running = true;
  }

  function safeJsonParse(str, fallback) {
    try {
      return JSON.parse(String(str ?? ""));
    } catch (_) {
      return fallback;
    }
  }

  function shCommand(script, ...args) {
    return ["sh", "-c", String(script), "x", ...args.map(String)];
  }

  function startLockLedWatcher(options) {
    const handler = options?.onChange;
    if (typeof handler !== "function")
      return () => {};
    if (!root.ledWatchers.includes(handler)) {
      root.ledWatchers.push(handler);
      try {
        handler(root.getLockLedState());
      } catch (_) {}
    }
    return () => {
      const idx = root.ledWatchers.indexOf(handler);
      if (idx >= 0)
        root.ledWatchers.splice(idx, 1);
    };
  }

  function stripAnsi(input) {
    return String(input ?? "").replace(/\x1B(?:[@-Z\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07]*(\x07|\x1B\))/g, "");
  }

  Component.onDestruction: {
    if (root.ledMonitor.running)
      root.ledMonitor.running = false;
    root.ledWatchers.length = 0;
    root.commandSlots.forEach(slot => {
      if (slot.process.running)
        slot.process.running = false;
      slot.collector.destroy();
      slot.process.destroy();
    });
  }
}
