pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var commandSlots: null
  property bool destroyed: false
  property list<var> ledWatchers: []

  function initializeCommandSlots() {
    if (commandSlots || destroyed)
      return;
    commandSlots = Array.from({
      length: 3
    }, () => {
      const p = Qt.createQmlObject("import Quickshell.Io; Process {}", root);
      const c = Qt.createQmlObject("import Quickshell.Io; StdioCollector { waitForEnd: true }", p);
      p.stdout = c;
      const slot = {
        process: p,
        collector: c,
        busy: false,
        callback: null,
        handler: null
      };
      slot.handler = () => {
        if (!slot.busy || destroyed)
          return;
        const cb = slot.callback;
        slot.busy = false;
        slot.callback = null;
        if (typeof cb === "function")
          try {
            cb(c?.text ?? "");
          } catch (_) {}
      };
      c.onStreamFinished.connect(slot.handler);
      return slot;
    });
  }

  function initializeLedMonitor() {
    if (!destroyed && !ledMonitor.running)
      ledMonitor.running = true;
  }

  function resolveIconSource(key, providedOrFallback, maybeFallback) {
    const has3Args = arguments.length >= 3;
    const provided = has3Args ? providedOrFallback : null;
    const fallback = has3Args ? maybeFallback : providedOrFallback;

    const resolveIcon = val => {
      if (!val)
        return "";
      const str = String(val);

      if (str.startsWith("file:") || str.startsWith("data:") || str.startsWith("/") || str.startsWith("qrc:"))
        return str;

      try {
        if (typeof DesktopEntries !== "undefined") {
          const entry = DesktopEntries.heuristicLookup?.(str) || DesktopEntries.byId?.(str);
          if (entry?.icon) {
            const result = Quickshell.iconPath(entry.icon, false) ?? "";
            if (result)
              return result;
          }
        }

        return Quickshell.iconPath(str, false) ?? "";
      } catch (_) {
        return "";
      }
    };

    return resolveIcon(provided) || resolveIcon(key) || resolveIcon(fallback ?? "application-x-executable");
  }

  function runCmd(cmd, onDone) {
    if (destroyed || !Array.isArray(cmd) || cmd.length === 0) {
      if (typeof onDone === "function")
        onDone("");
      return;
    }
    if (!commandSlots)
      initializeCommandSlots();
    if (!commandSlots || destroyed)
      return;
    const slot = commandSlots.find(s => !s.busy) ?? commandSlots[0];
    if (!slot)
      return;
    if (slot.process?.running)
      slot.process.running = false;
    slot.busy = true;
    slot.callback = typeof onDone === "function" ? onDone : null;
    slot.process.command = cmd;
    slot.process.running = true;
  }

  function shCommand(script, ...args) {
    return ["sh", "-c", String(script), "x", ...args.map(String)];
  }

  function startLockLedWatcher(options) {
    const handler = options?.onChange;
    if (typeof handler !== "function" || destroyed)
      return () => {};
    if (!ledMonitor.running)
      initializeLedMonitor();
    if (!ledWatchers.includes(handler)) {
      ledWatchers.push(handler);
      try {
        handler({
          caps: ledMonitor.lastCaps,
          num: ledMonitor.lastNum,
          scroll: ledMonitor.lastScroll
        });
      } catch (_) {}
    }
    return () => {
      const idx = ledWatchers.indexOf(handler);
      if (idx >= 0)
        ledWatchers.splice(idx, 1);
    };
  }

  Component.onDestruction: {
    destroyed = true;
    if (ledMonitor?.running)
      ledMonitor.running = false;
    ledWatchers.splice(0, ledWatchers.length);
    if (commandSlots) {
      commandSlots.forEach(slot => {
        if (!slot)
          return;
        if (slot.handler && slot.collector?.onStreamFinished) {
          try {
            slot.collector.onStreamFinished.disconnect(slot.handler);
          } catch (_) {}
        }
        if (slot.process?.running)
          slot.process.running = false;
        Qt.callLater(() => {
          try {
            if (slot.collector)
              slot.collector.destroy();
            if (slot.process)
              slot.process.destroy();
          } catch (_) {}
        });
      });
      commandSlots = null;
    }
  }

  Process {
    id: ledMonitor

    property bool lastCaps: false
    property bool lastNum: false
    property bool lastScroll: false

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
    running: false

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: line => {
        if (root.destroyed)
          return;
        const parts = line.trim().split(/\s+/);
        if (parts.length !== 3)
          return;
        const caps = parts[0] !== "0", num = parts[1] !== "0", scroll = parts[2] !== "0";
        if (caps === ledMonitor.lastCaps && num === ledMonitor.lastNum && scroll === ledMonitor.lastScroll)
          return;
        ledMonitor.lastCaps = caps;
        ledMonitor.lastNum = num;
        ledMonitor.lastScroll = scroll;
        if (root.ledWatchers.length === 0)
          return;
        const state = {
          caps,
          num,
          scroll
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
      if (!running && !root.destroyed && root.ledWatchers.length > 0) {
        console.warn("LED monitor stopped, restarting...");
        Qt.callLater(() => {
          if (ledMonitor && !root.destroyed)
            ledMonitor.running = true;
        });
      }
    }
  }
}
