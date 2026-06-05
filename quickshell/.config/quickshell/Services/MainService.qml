pragma Singleton
import QtQuick
import Quickshell
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
  readonly property string mainMon: Quickshell.env("MAINMON") ?? ""
  property bool ready: false
  property string username: ""

  Component.onCompleted: Command.run(["sh", "-c", `
      yn(){ "$@" >/dev/null 2>&1 && echo yes || echo no; }
      printf '%s=%s\\n' \
        isArchBased          "$(yn command -v pacman)" \
        hasBrightnessControl "$(yn [ -d /sys/class/backlight ])" \
        hasKeyboardBacklight "$(yn sh -c 'ls /sys/class/leds 2>/dev/null | grep -q kbd_backlight')" \
        isLaptop             "$(yn sh -c '[ -d /proc/acpi/button/lid ] || grep -q SW_LID /proc/bus/input/devices')" \
        username             "$(id -un)" \
        fullName             "$(getent passwd "$(id -un)" | cut -d: -f5 | cut -d, -f1)" \
        hostname             "$(uname -n)"
    `.trim()], result => {
    result.stdout.trim().split("\n").forEach(line => {
      const eqIndex = line.indexOf("=");
      if (eqIndex < 0 || !(line.slice(0, eqIndex) in sys))
        return;
      const key = line.slice(0, eqIndex);
      const value = line.slice(eqIndex + 1);
      sys[key] = (key.startsWith("is") || key.startsWith("has")) ? value.trim() === "yes" : value;
      Logger.log("MainService", `${key} = ${sys[key]}`);
    });
    sys.ready = true;
    Logger.log("MainService", "ready");
  })
}
