pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.WM

Singleton {
  id: root

  property var currentEntry: null
  readonly property int debounceMs: 150
  readonly property var groups: ({
      [types.capsLock]: "locks",
      [types.numLock]: "locks",
      [types.scrollLock]: "locks"
    })
  property bool initialized: false
  property string osdIcon: ""
  property string osdLabel: ""
  property int osdMaxValue: 100
  property string osdType: ""
  property var osdValue: null
  property var pendingEntry: null
  readonly property var priorities: ({
      [types.battery]: 0,
      [types.recording]: 0,
      [types.audioDevice]: 1,
      [types.micMute]: 1,
      [types.networking]: 2,
      [types.wifi]: 2,
      [types.bluetooth]: 2,
      [types.volumeOutput]: 3,
      [types.brightness]: 3,
      [types.keyboardBacklight]: 4,
      [types.keyboardLayout]: 4,
      [types.capsLock]: 4,
      [types.numLock]: 4,
      [types.scrollLock]: 4,
      [types.dnd]: 4
    })

  // Suppression: key suppresses values in array
  readonly property var suppresses: ({
      [types.battery]: [types.brightness, types.keyboardBacklight],
      [types.audioDevice]: [types.volumeOutput],
      [types.bluetooth]: [types.audioDevice],
      [types.networking]: [types.wifi],
      [types.micMute]: [types.volumeOutput]
    })
  readonly property int timeoutMs: 2000
  readonly property var types: ({
      audioDevice: "audio-device",
      battery: "battery",
      bluetooth: "bluetooth",
      brightness: "brightness",
      capsLock: "caps-lock",
      dnd: "dnd",
      keyboardBacklight: "keyboard-backlight",
      keyboardLayout: "keyboard-layout",
      micMute: "mic-mute",
      networking: "networking",
      numLock: "num-lock",
      recording: "recording",
      scrollLock: "scroll-lock",
      volumeOutput: "volume-output",
      wifi: "wifi"
    })
  property bool visible: false

  function applyEntry(entry): void {
    currentEntry = entry;
    osdType = entry.type;
    osdValue = entry.value;
    osdIcon = entry.icon;
    osdLabel = entry.label;
    osdMaxValue = entry.maxValue;
    visible = true;
    hideTimer.restart();
    if (pendingEntry && suppresses[entry.type]?.includes(pendingEntry.type))
      pendingEntry = null;
  }

  function handleEntry(entry): void {
    const current = currentEntry;
    if (current && suppresses[current.type]?.includes(entry.type))
      return;
    if (current && sameTypeOrGroup(current.type, entry.type)) {
      applyEntry(entry);
      return;
    }

    if (current && entry.priority < current.priority) {
      pendingEntry = current;
      applyEntry(entry);
      return;
    }

    if (!visible) {
      applyEntry(entry);
      return;
    }

    if (!pendingEntry || entry.priority <= pendingEntry.priority)
      pendingEntry = entry;
  }

  function hideOSD(): void {
    if (!visible)
      return;
    visible = false;
    hideTimer.stop();
    currentEntry = null;

    if (pendingEntry) {
      const next = pendingEntry;
      pendingEntry = null;
      applyEntry(next);
    }
  }

  function sameTypeOrGroup(a: string, b: string): bool {
    return a === b || (groups[a] && groups[a] === groups[b]);
  }

  function showOSD(type, value, icon, label, debounce = false, maxValue = 100) {
    if (!initialized)
      return;
    const entry = {
      type,
      value: value ?? null,
      icon,
      label,
      maxValue,
      priority: priorities[type] ?? 99
    };
    if (debounce) {
      debounceTimer.entry = entry;
      debounceTimer.restart();
    } else {
      handleEntry(entry);
    }
  }

  function showToggleOSD(type, enabled, iconOn, iconOff, label) {
    showOSD(type, null, enabled ? iconOn : iconOff, `${label} ${enabled ? "On" : "Off"}`);
  }

  function volumeIcon(vol: int, muted: bool): string {
    return muted ? "󰖁" : (vol >= 70 ? "󰕾" : vol >= 30 ? "󰖀" : "󰕿");
  }

  Component.onCompleted: initTimer.start()

  Timer {
    id: hideTimer

    interval: root.timeoutMs

    onTriggered: root.hideOSD()
  }

  Timer {
    id: debounceTimer

    property var entry: null

    interval: root.debounceMs

    onTriggered: {
      if (entry) {
        root.handleEntry(entry);
        entry = null;
      }
    }
  }

  Timer {
    id: initTimer

    interval: 1000

    onTriggered: root.initialized = true
  }

  Connections {
    function onMutedChanged() {
      const vol = Math.round(AudioService.volume * 100);
      root.showOSD(root.types.volumeOutput, AudioService.muted ? 0 : vol, root.volumeIcon(vol, AudioService.muted), AudioService.muted ? "Muted" : `${vol}%`, false, Math.round(AudioService.maxVolume * 100));
    }

    function onSinkDeviceChanged(deviceName, icon) {
      root.showOSD(root.types.audioDevice, null, icon || "󰓃", deviceName);
    }

    function onVolumeChanged() {
      const vol = Math.round(AudioService.volume * 100);
      root.showOSD(root.types.volumeOutput, vol, root.volumeIcon(vol, AudioService.muted), `${vol}%`, false, Math.round(AudioService.maxVolume * 100));
    }

    target: AudioService
  }

  Connections {
    function onMutedChanged() {
      const muted = AudioService.source?.audio?.muted ?? false;
      root.showOSD(root.types.micMute, null, muted ? "󰍭" : "󰍬", muted ? "Microphone Muted" : "Microphone Unmuted");
    }

    target: AudioService.source?.audio ?? null
  }

  Connections {
    function onNetworkingEnabledChanged() {
      root.showToggleOSD(root.types.networking, NetworkService.networkingEnabled, "󰈀", "󰪎", "Networking");
    }

    function onWifiRadioEnabledChanged() {
      root.showToggleOSD(root.types.wifi, NetworkService.wifiRadioEnabled, "󰖩", "󰖪", "WiFi");
    }

    target: NetworkService
  }

  Connections {
    function onEnabledChanged() {
      root.showToggleOSD(root.types.bluetooth, BluetoothService.enabled, "󰂯", "󰂲", "Bluetooth");
    }

    target: BluetoothService
  }

  Connections {
    function onIsChargingChanged() {
      if (!BatteryService.isLaptopBattery)
        return;
      root.showOSD(root.types.battery, null, BatteryService.isCharging ? "󰂄" : "󰂃", BatteryService.isCharging ? "Charger Connected" : "Charger Disconnected");
    }

    function onIsFullyChargedChanged() {
      if (BatteryService.isLaptopBattery && BatteryService.isFullyCharged)
        root.showOSD(root.types.battery, null, "󰚥", "Fully Charged");
    }

    function onIsPendingChargeChanged() {
      if (BatteryService.isLaptopBattery && BatteryService.isPendingCharge)
        root.showOSD(root.types.battery, null, "󰂏", "Charge Limit Reached");
    }

    target: BatteryService
  }

  Connections {
    function onPercentageChanged() {
      if (!BrightnessService.ready)
        return;
      const p = BrightnessService.percentage;
      root.showOSD(root.types.brightness, p, p >= 70 ? "󰃠" : p >= 30 ? "󰃟" : "󰃞", `${p}%`, true);
    }

    target: BrightnessService
  }

  Connections {
    function onBrightnessChanged() {
      if (KeyboardBacklightService.ready)
        root.showOSD(root.types.keyboardBacklight, null, "⌨", `Backlight: ${KeyboardBacklightService.levelName}`);
    }

    target: KeyboardBacklightService
  }

  Connections {
    function onDoNotDisturbChanged() {
      root.showToggleOSD(root.types.dnd, NotificationService.doNotDisturb, "󰂛", "󰂚", "Do Not Disturb");
    }

    target: NotificationService
  }

  Connections {
    function onCapsOnChanged() {
      root.showToggleOSD(root.types.capsLock, KeyboardLayoutService.capsOn, "󰘲", "󰘲", "Caps Lock");
    }

    function onCurrentLayoutChanged() {
      root.showOSD(root.types.keyboardLayout, KeyboardLayoutService.currentLayout || "??", "", `Layout: ${KeyboardLayoutService.currentLayout || "??"}`);
    }

    function onNumOnChanged() {
      root.showToggleOSD(root.types.numLock, KeyboardLayoutService.numOn, "", "", "Num Lock");
    }

    function onScrollOnChanged() {
      root.showToggleOSD(root.types.scrollLock, KeyboardLayoutService.scrollOn, "󰌐", "", "Scroll Lock");
    }

    target: KeyboardLayoutService
  }

  Connections {
    function onRecordingPaused(_) {
      root.showOSD(root.types.recording, null, "󰏤", "Recording Paused");
    }

    function onRecordingResumed(_) {
      root.showOSD(root.types.recording, null, "", "Recording Resumed");
    }

    function onRecordingStarted(_) {
      root.showOSD(root.types.recording, null, "󰑊", "Recording Started");
    }

    function onRecordingStopped(_) {
      root.showOSD(root.types.recording, null, "", "Recording Stopped");
    }

    target: ScreenRecordingService
  }
}
