pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // --- Internals ---

  // Process Pool
  property list<Process> _processPool: [p1, p2, p3]

  // --- LED State ---
  property bool capsLock: false
  property bool numLock: false
  property bool scrollLock: false

  // --- Icon Resolution ---
  function resolveIconSource(key: var, arg2: var, arg3: var): string {
    const provided = (arg3 !== undefined && arg3 !== null) ? arg2 : null;
    const fallback = (arg3 !== undefined && arg3 !== null) ? arg3 : arg2;
    const candidates = [provided, key, fallback, "application-x-executable"];

    for (const c of candidates) {
      if (!c)
        continue;
      const str = String(c);
      if (str.includes("/") || str.startsWith("file:") || str.startsWith("data:") || str.startsWith("qrc:")) {
        return str;
      }

      // Try DesktopEntries
      if (typeof DesktopEntries !== "undefined") {
        const entry = DesktopEntries.heuristicLookup?.(str) || DesktopEntries.byId?.(str);
        if (entry?.icon) {
          const path = Quickshell.iconPath(entry.icon, false);
          if (path)
            return path;
        }
      }

      // Try Quickshell icon lookup
      const path = Quickshell.iconPath(str, false);
      if (path)
        return path;
    }

    return "";
  }

  // --- Command Execution ---
  function runCmd(cmd: var, onDone: var): void {
    if (!cmd || (Array.isArray(cmd) && cmd.length === 0)) {
      if (typeof onDone === "function")
        onDone("");
      return;
    }

    // Find free slot
    let proc = null;
    for (let i = 0; i < _processPool.length; i++) {
      if (!_processPool[i].running) {
        proc = _processPool[i];
        break;
      }
    }
    // Fallback to first slot if all busy
    if (!proc)
      proc = _processPool[0];

    proc.callback = (typeof onDone === "function") ? onDone : null;
    proc.command = cmd;
    proc.running = true;
  }

  // --- Deprecated / Compatibility ---
  function startLockLedWatcher(options) {
    const handler = options?.onChange;
    if (typeof handler !== "function")
      return () => {};

    const cb = () => handler({
        caps: root.capsLock,
        num: root.numLock,
        scroll: root.scrollLock
      });

    // Initial call
    cb();

    capsLockChanged.connect(cb);
    numLockChanged.connect(cb);
    scrollLockChanged.connect(cb);

    return () => {
      try {
        capsLockChanged.disconnect(cb);
        numLockChanged.disconnect(cb);
        scrollLockChanged.disconnect(cb);
      } catch (_) {}
    };
  }

  Process {
    id: p1

    property var callback: null

    stdout: StdioCollector {
      onStreamFinished: {
        const cb = p1.callback;
        if (typeof cb === "function")
          cb(text);
        p1.callback = null;
      }
    }
  }

  Process {
    id: p2

    property var callback: null

    stdout: StdioCollector {
      onStreamFinished: {
        const cb = p2.callback;
        if (typeof cb === "function")
          cb(text);
        p2.callback = null;
      }
    }
  }

  Process {
    id: p3

    property var callback: null

    stdout: StdioCollector {
      onStreamFinished: {
        const cb = p3.callback;
        if (typeof cb === "function")
          cb(text);
        p3.callback = null;
      }
    }
  }

  // LED Monitor
  Process {
    id: ledMonitor

    command: ["sh", "-c", `
      get_val() {
        for f in /sys/class/leds/*$1/brightness; do
          [ -f "$f" ] || continue
          # Use timeout + cat for safety against hanging drivers (common after sleep)
          v=$(timeout 0.1 cat "$f" 2>/dev/null)
          [ "$v" != "0" ] && echo 1 && return
        done
        echo 0
      }

      check() {
        c=$(get_val "capslock")
        n=$(get_val "numlock")
        s=$(get_val "scrolllock")
        cur="$c $n $s"

        if [ "$cur" != "$last" ]; then
          echo "$cur"
          last="$cur"
        fi
      }

      last=""
      check # Initial check

      # Wait for input (newline) from QML Timer to trigger check
      # This avoids spawning 'sleep' processes
      while read -r _; do
        check
      done
    `]
    running: true

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: line => {
        const parts = line.trim().split(" ");
        if (parts.length === 3) {
          root.capsLock = (parts[0] === "1");
          root.numLock = (parts[1] === "1");
          root.scrollLock = (parts[2] === "1");
        }
      }
    }

    onRunningChanged: {
      if (!running) {
        console.warn("LED monitor stopped, restarting...");
        restartTimer.start();
      }
    }
  }

  Timer {
    id: pollTimer

    interval: 100
    repeat: true
    running: ledMonitor.running

    onTriggered: {
      if (ledMonitor.running)
        ledMonitor.write("\n");
    }
  }

  Timer {
    id: restartTimer

    interval: 1000

    onTriggered: ledMonitor.running = true
  }
}
