pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: sys

  readonly property string currentWM: (function () {
      const desktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase();
      return (desktop === "hyprland" || desktop === "niri") ? desktop : "other";
    })()
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
    // Shell helper: "yn <cmd>" returns yes/no based on <cmd> exit code
    const shLines = ['yn(){ "$@" >/dev/null 2>&1 && echo yes || echo no; }',
      // Checks (booleans rendered as yes/no)
      'isArchBased=$(yn command -v pacman)', 'hasBrightnessControl=$(yn [ -d /sys/class/backlight ])', "hasKeyboardBacklight=$(yn sh -c 'ls -1 /sys/class/leds 2>/dev/null | grep -q kbd_backlight')", "isLaptop=$(yn sh -c '[ -d /proc/acpi/button/lid ] && ls /proc/acpi/button/lid/*/state >/dev/null 2>&1 || grep -q SW_LID /proc/bus/input/devices')",
      // User info
      'username=$USER', 'fullName="$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)"', 'hostname=$HOSTNAME',
      // Emit key=value pairs expected by this service's properties
      "printf '%s=%s\\n' " + "isArchBased \"$isArchBased\" " + "hasBrightnessControl \"$hasBrightnessControl\" " + "hasKeyboardBacklight \"$hasKeyboardBacklight\" " + "isLaptop \"$isLaptop\" " + "username \"$username\" " + "fullName \"$fullName\" " + "hostname \"$hostname\"",];
    return ["sh", "-c", shLines.join("; ")];
  }

  function yes(text) {
    return (text || "").trim() === "yes";
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
        const output = (text || "").trim();
        const outputLines = output.split("\n");
        const isBooleanProperty = name => {
          return name.startsWith("is") || name.startsWith("has");
        };
        for (let i = 0; i < outputLines.length; i++) {
          const kvLine = outputLines[i];
          const equalsIndex = kvLine.indexOf("=");
          if (equalsIndex <= 0)
            continue;

          const propertyName = kvLine.slice(0, equalsIndex);
          const rawValue = kvLine.slice(equalsIndex + 1);
          if (propertyName in sys)
            sys[propertyName] = isBooleanProperty(propertyName) ? sys.yes(rawValue) : (rawValue || "");

          Logger.log("MainService", `Detected ${propertyName} = ${sys[propertyName]}`);
        }
        sys.ready = true;
        Logger.log("MainService", "All checks complete, ready = true");
      }
    }
  }
}
