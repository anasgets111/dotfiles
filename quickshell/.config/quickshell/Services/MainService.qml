pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: sys

  readonly property string currentWM: {
    const desktop = Quickshell.env("XDG_CURRENT_DESKTOP")?.toLowerCase() ?? "";
    return ["hyprland", "niri"].includes(desktop) ? desktop : "other";
  }
  property string fullName: ""
  property bool hasBrightnessControl: false
  property bool hasKeyboardBacklight: false
  property string hostname: ""
  property bool isArchBased: false
  property bool isLaptop: false
  readonly property string mainMon: Quickshell.env("MAINMON") || ""
  property bool ready: false
  property string username: ""

  function buildSystemInfoCommand() {
    return ["sh", "-c", `
      yn(){ "$@" >/dev/null 2>&1 && echo yes || echo no; }
      printf '%s=%s\\n' \
        isArchBased "$(yn command -v pacman)" \
        hasBrightnessControl "$(yn [ -d /sys/class/backlight ])" \
        hasKeyboardBacklight "$(yn sh -c 'ls /sys/class/leds 2>/dev/null | grep -q kbd_backlight')" \
        isLaptop "$(yn sh -c '[ -d /proc/acpi/button/lid ] || grep -q SW_LID /proc/bus/input/devices')" \
        username "$USER" \
        fullName "$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)" \
        hostname "$HOSTNAME"
    `.trim()];
  }

  function yes(text) {
    return text?.trim() === "yes";
  }

  Component.onCompleted: {
    sys.ready = false;
    systemInfoProc.running = true;
  }

  Process {
    id: systemInfoProc

    command: sys.buildSystemInfoCommand()

    stdout: StdioCollector {
      onStreamFinished: {
        text.trim().split("\n").forEach(line => {
          const [key, value] = line.split("=");
          if (!key || !(key in sys))
            return;

          const isBool = key.startsWith("is") || key.startsWith("has");
          sys[key] = isBool ? sys.yes(value) : value;
          Logger.log("MainService", `Detected ${key} = ${sys[key]}`);
        });

        sys.ready = true;
        Logger.log("MainService", "All checks complete, ready = true");
      }
    }
  }
}
