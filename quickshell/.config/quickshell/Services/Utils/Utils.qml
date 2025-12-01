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
    const candidates = hasThirdArg ? [arg2, key, arg3] : [key, arg2, "application-x-executable"];

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
    id: ledProc

    command: ["sh", "-c", `
      check() { for f in /sys/class/leds/*"$1"/brightness; do [ -f "$f" ] && [ "$(cat "$f" 2>/dev/null)" != "0" ] && echo 1 && return; done; echo 0; }
      last=""
      while read -r _; do
        cur="$(check capslock) $(check numlock) $(check scrolllock)"
        [ "$cur" != "$last" ] && echo "$cur" && last="$cur"
      done
    `]
    running: true

    stdout: SplitParser {
      onRead: line => {
        const [caps, num, scroll] = line.trim().split(" ");
        root.capsLock = caps === "1";
        root.numLock = num === "1";
        root.scrollLock = scroll === "1";
      }
    }

    onRunningChanged: if (!running)
      restartTimer.start()
  }

  Timer {
    interval: 100
    repeat: true
    running: ledProc.running

    onTriggered: ledProc.write("\n")
  }

  Timer {
    id: restartTimer

    interval: 1000

    onTriggered: ledProc.running = true
  }
}
