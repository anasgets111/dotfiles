pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services.Utils

Singleton {
  id: root

  readonly property string _devicePath: backlightDevice.devicePath
  readonly property bool available: backlightDevice.available
  readonly property int brightness: backlightDevice.brightness
  readonly property int maxBrightness: backlightDevice.maxBrightness
  readonly property int percentage: maxBrightness > 0 ? Math.round((brightness / maxBrightness) * 100) : 0
  readonly property bool ready: backlightDevice.ready

  function setBrightness(percent: real): void {
    if (!available)
      return;
    const clamped = Math.max(0, Math.min(100, percent));
    Command.run(["brightnessctl", "--class=backlight", "set", `${clamped}%`]);
  }

  SysfsBrightnessDevice {
    id: backlightDevice

    directory: "/sys/class/backlight"
  }
}
