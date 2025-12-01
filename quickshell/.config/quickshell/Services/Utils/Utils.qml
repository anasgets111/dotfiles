pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool capsLock: false
  property bool numLock: false
  property bool scrollLock: false

  function resolveIconSource(key, arg2, arg3) {
    const hasThirdArg = arg3 !== undefined && arg3 !== null;
    const candidates = hasThirdArg ? [arg2, key, arg3]                        // provided, key, fallback
    : [key, arg2, "application-x-executable"]; // key, fallback, default

    for (const c of candidates) {
      if (!c)
        continue;
      const s = String(c);

      if (s.includes("/") || /^(file|data|qrc):/.test(s))
        return s;

      if (typeof DesktopEntries !== "undefined") {
        const entry = DesktopEntries.heuristicLookup?.(s) || DesktopEntries.byId?.(s);
        if (entry?.icon) {
          const p = Quickshell.iconPath(entry.icon, false);
          if (p)
            return p;
        }
      }

      const p = Quickshell.iconPath(s, false);
      if (p)
        return p;
    }
    return "";
  }

  Process {
    id: ledMonitor

    command: ["sh", "-c", `
      get(){ for f in /sys/class/leds/*$1/brightness; do [ -f "$f" ] && v=$(timeout 0.1 cat "$f" 2>/dev/null) && [ "$v" != "0" ] && echo 1 && return; done; echo 0; }
      last=""; while :; do cur="$(get capslock) $(get numlock) $(get scrolllock)"; [ "$cur" != "$last" ] && echo "$cur" && last="$cur"; read -r _ || break; done
    `]
    running: true

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: line => {
        const p = line.trim().split(" ");
        if (p.length === 3) {
          root.capsLock = p[0] === "1";
          root.numLock = p[1] === "1";
          root.scrollLock = p[2] === "1";
        }
      }
    }

    onRunningChanged: if (!running)
      restartTimer.start()
  }

  Timer {
    id: pollTimer

    interval: 100
    repeat: true
    running: ledMonitor.running

    onTriggered: if (ledMonitor.running)
      ledMonitor.write("\n")
  }

  Timer {
    id: restartTimer

    interval: 1000

    onTriggered: ledMonitor.running = true
  }
}
