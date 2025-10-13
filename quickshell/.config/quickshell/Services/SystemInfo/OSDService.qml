pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.Utils
import qs.Services.WM

Singleton {
  id: root

  property int debounceTimeout: 150
  property bool initialized: false
  property string osdIcon: ""
  property string osdLabel: ""
  property string osdType: ""
  property var osdValue: null
  property bool suppressVolumeOSD: false
  property int timeout: 2000
  readonly property string typeAudioDevice: "audio-device"
  readonly property string typeBattery: "battery"
  readonly property string typeBluetooth: "bluetooth"
  readonly property string typeBrightness: "brightness"
  readonly property string typeCapsLock: "caps-lock"
  readonly property string typeDnd: "dnd"
  readonly property string typeKeyboardBacklight: "keyboard-backlight"
  readonly property string typeKeyboardLayout: "keyboard-layout"
  readonly property string typeMicMute: "mic-mute"
  readonly property string typeNetworking: "networking"
  readonly property string typeNumLock: "num-lock"
  readonly property string typeRecording: "recording"
  readonly property string typeScrollLock: "scroll-lock"
  readonly property string typeVolumeOutput: "volume-output"
  readonly property string typeWifi: "wifi"
  property bool visible: false

  function hideOSD() {
    root.visible = false;
    hideTimer.stop();
  }

  function showOSD(type, value, icon, label, debounce = false) {
    if (!root.initialized)
      return;

    if (debounce) {
      debounceTimer.pendingOSD = {
        type,
        value,
        icon,
        label
      };
      debounceTimer.restart();
      return;
    }

    root.osdType = type;
    root.osdValue = value !== undefined ? value : null;
    root.osdIcon = icon;
    root.osdLabel = label;
    root.visible = true;
    hideTimer.restart();
    Logger.log("OSDService", `Show OSD: ${type} = ${value}`);
  }

  function showToggleOSD(type, enabled, iconOn, iconOff, label) {
    root.showOSD(type, enabled, enabled ? iconOn : iconOff, `${label} ${enabled ? "On" : "Off"}`);
  }

  Component.onCompleted: {
    initTimer.start();
    Logger.log("OSDService", "Service created, waiting 1s before showing OSDs");
  }

  Timer {
    id: hideTimer

    interval: root.timeout

    onTriggered: root.hideOSD()
  }

  Timer {
    id: debounceTimer

    property var pendingOSD: null

    interval: root.debounceTimeout

    onTriggered: {
      if (pendingOSD) {
        root.showOSD(pendingOSD.type, pendingOSD.value, pendingOSD.icon, pendingOSD.label);
        pendingOSD = null;
      }
    }
  }

  Timer {
    id: initTimer

    interval: 1000

    onTriggered: {
      root.initialized = true;
      Logger.log("OSDService", "Service initialized and ready");
    }
  }

  Timer {
    id: suppressTimer

    interval: 100

    onTriggered: root.suppressVolumeOSD = false
  }

  Connections {
    function onMutedChanged() {
      const volume = Math.round(AudioService.volume * 100);
      const icon = AudioService.muted ? "󰖁" : (volume >= 70 ? "󰕾" : volume >= 30 ? "󰖀" : "󰕿");
      const value = AudioService.muted ? 0 : volume;
      const label = AudioService.muted ? "Muted" : `${volume}%`;
      root.showOSD(root.typeVolumeOutput, value, icon, label);
    }

    function onSinkDeviceChanged(deviceName, icon) {
      root.suppressVolumeOSD = true;
      root.showOSD(root.typeAudioDevice, null, icon || "󰓃", deviceName);
      suppressTimer.restart();
    }

    function onVolumeChanged() {
      if (root.suppressVolumeOSD)
        return;
      const volume = Math.round(AudioService.volume * 100);
      const icon = AudioService.muted ? "󰖁" : (volume >= 70 ? "󰕾" : volume >= 30 ? "󰖀" : "󰕿");
      root.showOSD(root.typeVolumeOutput, volume, icon, `${volume}%`, true);
    }

    target: typeof AudioService !== "undefined" ? AudioService : null
  }

  Connections {
    function onNetworkingEnabledChanged() {
      root.showToggleOSD(root.typeNetworking, NetworkService.networkingEnabled, "󰈀", "󰪎", "Networking");
    }

    function onWifiRadioEnabledChanged() {
      root.showToggleOSD(root.typeWifi, NetworkService.wifiRadioEnabled, "󰖩", "󰖪", "WiFi");
    }

    target: typeof NetworkService !== "undefined" ? NetworkService : null
  }

  Connections {
    function onEnabledChanged() {
      root.showToggleOSD(root.typeBluetooth, BluetoothService.enabled, "󰂯", "󰂲", "Bluetooth");
    }

    target: typeof BluetoothService !== "undefined" ? BluetoothService : null
  }

  Connections {
    function onPercentageChanged() {
      if (!BrightnessService.ready)
        return;
      const percent = BrightnessService.percentage;
      const icon = percent >= 70 ? "󰃠" : percent >= 30 ? "󰃟" : "󰃞";
      root.showOSD(root.typeBrightness, percent, icon, `${percent}%`, true);
    }

    target: typeof BrightnessService !== "undefined" ? BrightnessService : null
  }

  Connections {
    function onBrightnessChanged() {
      if (!KeyboardBacklightService.ready)
        return;
      const levelName = KeyboardBacklightService.levelName;
      root.showOSD(root.typeKeyboardBacklight, null, "⌨", `Backlight: ${levelName}`);
    }

    target: typeof KeyboardBacklightService !== "undefined" ? KeyboardBacklightService : null
  }

  Connections {
    function onDoNotDisturbChanged() {
      root.showToggleOSD(root.typeDnd, NotificationService.doNotDisturb, "󰂛", "󰂚", "Do Not Disturb");
    }

    target: typeof NotificationService !== "undefined" ? NotificationService : null
  }

  Connections {
    function onCapsOnChanged() {
      root.showToggleOSD(root.typeCapsLock, KeyboardLayoutService.capsOn, "󰘲", "󰘲", "Caps Lock");
    }

    function onCurrentLayoutChanged() {
      const layoutCode = KeyboardLayoutService.currentLayout || "??";
      root.showOSD(root.typeKeyboardLayout, layoutCode, "󰌌", `Layout: ${layoutCode}`);
    }

    function onNumOnChanged() {
      root.showToggleOSD(root.typeNumLock, KeyboardLayoutService.numOn, "󰎠", "󰎠", "Num Lock");
    }

    function onScrollOnChanged() {
      root.showToggleOSD(root.typeScrollLock, KeyboardLayoutService.scrollOn, "󰌐", "󰌐", "Scroll Lock");
    }

    target: typeof KeyboardLayoutService !== "undefined" ? KeyboardLayoutService : null
  }

  Connections {
    function onMicMuteChanged() {
      if (!AudioService.source?.audio)
        return;
      const muted = AudioService.source.audio.muted;
      const volume = Math.round((AudioService.source.audio.volume || 0) * 100);
      const icon = muted ? "󰍭" : (volume >= 70 ? "󰍬" : volume >= 30 ? "󰍬" : "󰍬");
      const label = muted ? "Microphone Muted" : "Microphone Unmuted";
      root.showOSD(root.typeMicMute, muted, icon, label);
    }

    target: typeof AudioService !== "undefined" ? AudioService : null
  }

  Connections {
    function onIsChargingChanged() {
      if (!BatteryService.isLaptopBattery)
        return;
      const icon = BatteryService.isCharging ? "󰂄" : "󰂃";
      const label = BatteryService.isCharging ? "Charger Connected" : "Charger Disconnected";
      root.showOSD(root.typeBattery, null, icon, label);
    }

    function onIsFullyChargedChanged() {
      if (!BatteryService.isLaptopBattery || !BatteryService.isFullyCharged)
        return;
      root.showOSD(root.typeBattery, null, "󰚥", "Fully Charged");
    }

    function onIsPendingChargeChanged() {
      if (!BatteryService.isLaptopBattery || !BatteryService.isPendingCharge)
        return;
      root.showOSD(root.typeBattery, null, "󰂏", "Charge Limit Reached");
    }

    target: typeof BatteryService !== "undefined" ? BatteryService : null
  }

  Connections {
    function onRecordingPaused(path) {
      root.showOSD(root.typeRecording, null, "󰏤", "Recording Paused");
    }

    function onRecordingResumed(path) {
      root.showOSD(root.typeRecording, null, "", "Recording Resumed");
    }

    function onRecordingStarted(path) {
      root.showOSD(root.typeRecording, null, "󰑊", "Recording Started");
    }

    function onRecordingStopped(path) {
      root.showOSD(root.typeRecording, null, "", "Recording Stopped");
    }

    target: typeof ScreenRecordingService !== "undefined" ? ScreenRecordingService : null
  }
}
