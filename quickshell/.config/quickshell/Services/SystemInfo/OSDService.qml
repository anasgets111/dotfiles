pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.WM

Singleton {
  id: root

  property string osdIcon: ""
  property string osdLabel: ""
  property string osdType: ""
  property var osdValue: null
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

  function show(type: string, value: var, icon: string, label: string, debounce = false) {
    const entry = {
      type: type,
      value: value,
      icon: icon,
      label: label,
      priority: osdState.config[type]?.prio ?? 99
    };

    if (debounce) {
      osdState.debounceEntry = entry;
      debounceTimer.restart();
    } else {
      osdState.push(entry);
    }
  }
  function showToggle(type: string, enabled: bool, iconOn: string, iconOff: string, label: string) {
    show(type, null, enabled ? iconOn : iconOff, `${label} ${enabled ? "On" : "Off"}`);
  }

  QtObject {
    id: osdState

    readonly property var config: ({
        [root.types.battery]: {
          prio: 0,
          group: "",
          suppress: [root.types.brightness, root.types.keyboardBacklight]
        },
        [root.types.recording]: {
          prio: 0,
          group: "",
          suppress: []
        },
        [root.types.audioDevice]: {
          prio: 1,
          group: "",
          suppress: [root.types.volumeOutput]
        },
        [root.types.micMute]: {
          prio: 1,
          group: "",
          suppress: [root.types.volumeOutput]
        },
        [root.types.networking]: {
          prio: 2,
          group: "",
          suppress: [root.types.wifi]
        },
        [root.types.wifi]: {
          prio: 2,
          group: "",
          suppress: []
        },
        [root.types.bluetooth]: {
          prio: 2,
          group: "",
          suppress: [root.types.audioDevice]
        },
        [root.types.volumeOutput]: {
          prio: 3,
          group: "",
          suppress: []
        },
        [root.types.brightness]: {
          prio: 3,
          group: "",
          suppress: []
        },
        [root.types.keyboardBacklight]: {
          prio: 4,
          group: "",
          suppress: []
        },
        [root.types.keyboardLayout]: {
          prio: 4,
          group: "",
          suppress: []
        },
        [root.types.capsLock]: {
          prio: 4,
          group: "locks",
          suppress: []
        },
        [root.types.numLock]: {
          prio: 4,
          group: "locks",
          suppress: []
        },
        [root.types.scrollLock]: {
          prio: 4,
          group: "locks",
          suppress: []
        },
        [root.types.dnd]: {
          prio: 4,
          group: "",
          suppress: []
        }
      })
    property var current: null
    property var debounceEntry: null
    readonly property int debounceMs: 150
    property bool initialized: false
    property var pending: null
    readonly property int timeoutMs: 2000
    property bool wasCharging: false
    property bool wasPendingCharge: false

    function apply(entry) {
      osdState.current = entry;
      root.osdType = entry.type;
      root.osdValue = entry.value;
      root.osdIcon = entry.icon;
      root.osdLabel = entry.label;
      root.visible = true;
      hideTimer.restart();

      if (osdState.pending && osdState.config[entry.type]?.suppress.includes(osdState.pending.type)) {
        osdState.pending = null;
      }
    }
    function close() {
      if (!root.visible)
        return;
      root.visible = false;
      hideTimer.stop();
      osdState.current = null;

      if (osdState.pending) {
        const next = osdState.pending;
        osdState.pending = null;
        osdState.apply(next);
      }
    }
    function push(entry) {
      if (!osdState.initialized)
        return;

      if (osdState.current && osdState.config[osdState.current.type]?.suppress.includes(entry.type))
        return;

      const sameGroup = osdState.config[entry.type]?.group !== "" && osdState.config[entry.type]?.group === osdState.config[osdState.current?.type]?.group;
      if (osdState.current && (osdState.current.type === entry.type || sameGroup)) {
        osdState.apply(entry);
        return;
      }

      if (osdState.current && entry.priority < osdState.current.priority) {
        osdState.pending = osdState.current;
        osdState.apply(entry);
        return;
      }

      if (!root.visible) {
        osdState.apply(entry);
        return;
      }

      if (!osdState.pending || entry.priority <= osdState.pending.priority) {
        osdState.pending = entry;
      }
    }
  }
  Timer {
    id: hideTimer

    interval: osdState.timeoutMs

    onTriggered: osdState.close()
  }
  Timer {
    id: debounceTimer

    interval: osdState.debounceMs

    onTriggered: {
      if (osdState.debounceEntry) {
        osdState.push(osdState.debounceEntry);
        osdState.debounceEntry = null;
      }
    }
  }
  Timer {
    interval: 1000
    running: true

    onTriggered: {
      osdState.initialized = true;
      osdState.wasCharging = BatteryService.isCharging;
      osdState.wasPendingCharge = BatteryService.isPendingCharge;
    }
  }
  Connections {
    function onMutedChanged() {
      const vol = Math.round(AudioService.volume * 100);
      root.show(root.types.volumeOutput, AudioService.muted ? 0 : vol, AudioService.muted ? "󰖁" : (vol >= 70 ? "󰕾" : vol >= 30 ? "󰖀" : "󰕿"), AudioService.muted ? "Muted" : `${vol}%`);
    }
    function onSinkChanged() {
      const deviceName = AudioService.sinkName;
      if (!deviceName)
        return;
      root.show(root.types.audioDevice, null, AudioService.sinkIcon || "󰓃", deviceName);
    }
    function onVolumeChanged() {
      const vol = Math.round(AudioService.volume * 100);
      root.show(root.types.volumeOutput, vol, (vol >= 70 ? "󰕾" : vol >= 30 ? "󰖀" : "󰕿"), `${vol}%`);
    }

    target: AudioService
  }
  Connections {
    function onMicMutedChanged() {
      const muted = AudioService.micMuted;
      root.show(root.types.micMute, null, muted ? "󰍭" : "󰍬", muted ? "Microphone Muted" : "Microphone Unmuted");
    }

    target: AudioService
  }
  Connections {
    function onNetworkingEnabledChanged() {
      root.showToggle(root.types.networking, NetworkService.networkingEnabled, "󰈀", "󰪎", "Networking");
    }
    function onWifiRadioEnabledChanged() {
      root.showToggle(root.types.wifi, NetworkService.wifiRadioEnabled, "󰖩", "󰖪", "WiFi");
    }

    target: NetworkService
  }
  Connections {
    function onEnabledChanged() {
      root.showToggle(root.types.bluetooth, BluetoothService.enabled, "󰂯", "󰂲", "Bluetooth");
    }

    target: BluetoothService
  }
  Connections {
    function onDeviceStateChanged() {
      const wasCharging = osdState.wasCharging;
      const wasPendingCharge = osdState.wasPendingCharge;
      osdState.wasCharging = BatteryService.isCharging;
      osdState.wasPendingCharge = BatteryService.isPendingCharge;

      if (!BatteryService.isLaptopBattery || !BatteryService.device?.ready || !BatteryService.isACPowered)
        return;

      if (!wasPendingCharge && BatteryService.isPendingCharge)
        root.show(root.types.battery, null, "󰂏", "Charge Limit Reached");
      else if (wasCharging && !BatteryService.isCharging && (BatteryService.isFullyCharged || BatteryService.percentage >= 100))
        root.show(root.types.battery, null, "󰚥", "Fully Charged");
    }
    function onIsACPoweredChanged() {
      if (BatteryService.isLaptopBattery && BatteryService.device?.ready)
        root.show(root.types.battery, null, BatteryService.isACPowered ? "󰂄" : "󰂃", BatteryService.isACPowered ? "Charger Connected" : "Charger Disconnected");
    }

    target: BatteryService
  }
  Connections {
    function onPercentageChanged() {
      if (!BrightnessService.ready)
        return;
      const p = BrightnessService.percentage;
      root.show(root.types.brightness, p, p >= 70 ? "󰃠" : p >= 30 ? "󰃟" : "󰃞", `${p}%`, true);
    }

    target: BrightnessService
  }
  Connections {
    function onBrightnessChanged() {
      if (KeyboardBacklightService.ready)
        root.show(root.types.keyboardBacklight, null, "⌨", `Backlight: ${KeyboardBacklightService.levelName}`);
    }

    target: KeyboardBacklightService
  }
  Connections {
    function onDoNotDisturbChanged() {
      root.showToggle(root.types.dnd, NotificationService.doNotDisturb, "󰂛", "󰂚", "Do Not Disturb");
    }

    target: NotificationService
  }
  Connections {
    function onCapsOnChanged() {
      root.showToggle(root.types.capsLock, KeyboardLayoutService.capsOn, "󰘲", "󰘲", "Caps Lock");
    }
    function onCurrentLayoutChanged() {
      root.show(root.types.keyboardLayout, null, "󰌌", `Layout: ${KeyboardLayoutService.currentLayout || "??"}`);
    }
    function onNumOnChanged() {
      root.showToggle(root.types.numLock, KeyboardLayoutService.numOn, "󰎠", "󰎠", "Num Lock");
    }
    function onScrollOnChanged() {
      root.showToggle(root.types.scrollLock, KeyboardLayoutService.scrollOn, "󰌐", "󰌐", "Scroll Lock");
    }

    target: KeyboardLayoutService
  }
  Connections {
    function onRecordingPaused(_) {
      root.show(root.types.recording, null, "󰏤", "Recording Paused");
    }
    function onRecordingResumed(_) {
      root.show(root.types.recording, null, "󰐊", "Recording Resumed");
    }
    function onRecordingStarted(_) {
      root.show(root.types.recording, null, "󰑊", "Recording Started");
    }
    function onRecordingStopped(_) {
      root.show(root.types.recording, null, "󰓛", "Recording Stopped");
    }

    target: ScreenRecordingService
  }
}
