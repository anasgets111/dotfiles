pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services.Utils

Singleton {
  id: root

  property bool _blanked: false
  property int _unblankedLevel: 0
  readonly property string _deviceName: keyboardDevice.deviceName
  readonly property string _devicePath: keyboardDevice.devicePath
  readonly property bool available: keyboardDevice.available
  readonly property int brightness: keyboardDevice.brightness
  readonly property string levelName: ["Off", "Low", "Medium", "High"][brightness] ?? `Level ${brightness}`
  readonly property int maxBrightness: keyboardDevice.maxBrightness
  readonly property bool ready: keyboardDevice.ready
  // Settle window after DPMS blank/unblank so sysfs polls don't flash OSD.
  property bool suppressOsd: false

  function _writeLevel(level: int): void {
    if (available)
      Command.run(["brightnessctl", `--device=${_deviceName}`, "set", `${level}`]);
  }
  function setBlanked(shouldBlank: bool): void {
    if (root._blanked === shouldBlank || (shouldBlank && !ready))
      return;

    if (shouldBlank)
      root._unblankedLevel = brightness;
    root._blanked = shouldBlank;
    root.suppressOsd = true;
    root._writeLevel(shouldBlank ? 0 : root._unblankedLevel);
    quietClear.restart();
  }
  function setLevel(level: int): void {
    const clamped = Math.max(0, Math.min(maxBrightness, level));
    if (_blanked) {
      root._unblankedLevel = clamped;
      return;
    }
    root.suppressOsd = false;
    quietClear.stop();
    root._writeLevel(clamped);
  }

  onAvailableChanged: {
    if (!available)
      Logger.log("KeyboardBacklightService", "not available");
  }
  onLevelNameChanged: {
    if (available && ready)
      Logger.log("KeyboardBacklightService", `keyboard backlight: ${brightness}/${maxBrightness} (${levelName})`);
  }
  onReadyChanged: {
    if (ready)
      Logger.log("KeyboardBacklightService", `ready | device: ${_deviceName} (${_devicePath}) | level: ${brightness}/${maxBrightness} (${levelName})`);
  }
  on_DevicePathChanged: {
    if (!_devicePath)
      Logger.log("KeyboardBacklightService", "device lost");
  }

  SysfsBrightnessDevice {
    id: keyboardDevice

    directory: "/sys/class/leds"
    maxBrightnessFallback: 3
    nameIncludes: "kbd_backlight"
  }
  Timer {
    id: quietClear

    // ponytail: covers a few 100ms polls after blank/unblank; raise if writes lag.
    interval: 400

    onTriggered: root.suppressOsd = false
  }
}
