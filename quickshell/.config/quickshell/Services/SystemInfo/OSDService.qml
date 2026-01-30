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
  property int osdMaxValue: 100
  property string osdType: ""
  property var osdValue: null // Can be int or null

  // --- Constants / Enum ---
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

  // --- Public API ---
  property bool visible: false

  // --- Helper Functions ---

  function show(type: string, value: var, icon: string, label: string, debounce = false, maxValue = 100) {
    const entry = {
      type: type,
      value: value,
      icon: icon,
      label: label,
      maxValue: maxValue,
      priority: _.config[type]?.prio ?? 99
    };

    if (debounce) {
      _.debounceEntry = entry;
      debounceTimer.restart();
    } else {
      _.push(entry);
    }
  }

  function showToggle(type: string, enabled: bool, iconOn: string, iconOff: string, label: string) {
    show(type, null, enabled ? iconOn : iconOff, `${label} ${enabled ? "On" : "Off"}`);
  }

  // --- Internal Logic & Configuration ---
  QtObject {
    id: _

    // Config: [Priority (lower is higher), Group, SuppressionList]
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

    // State
    property var current: null
    property var debounceEntry: null
    readonly property int debounceMs: 150
    property bool initialized: false
    property var pending: null
    readonly property int timeoutMs: 2000

    function apply(entry) {
      _.current = entry;
      root.osdType = entry.type;
      root.osdValue = entry.value;
      root.osdIcon = entry.icon;
      root.osdLabel = entry.label;
      root.osdMaxValue = entry.maxValue;
      root.visible = true;
      hideTimer.restart();

      // Clear pending if the new entry suppresses what was waiting
      if (_.pending && _.config[entry.type]?.suppress.includes(_.pending.type)) {
        _.pending = null;
      }
    }

    function close() {
      if (!root.visible)
        return;
      root.visible = false;
      hideTimer.stop();
      _.current = null;

      if (_.pending) {
        const next = _.pending;
        _.pending = null;
        _.apply(next);
      }
    }

    function push(entry) {
      if (!_.initialized)
        return;

      // 1. Check Suppression (Does current entry suppress the new one?)
      if (_.current && _.config[_.current.type]?.suppress.includes(entry.type))
        return;

      // 2. Check Grouping (Update in place if same type or group)
      const sameGroup = _.config[entry.type]?.group !== "" && _.config[entry.type]?.group === _.config[_.current?.type]?.group;
      if (_.current && (_.current.type === entry.type || sameGroup)) {
        _.apply(entry);
        return;
      }

      // 3. Priority Interruption (New entry is more important than current)
      if (_.current && entry.priority < _.current.priority) {
        _.pending = _.current; // Save current for later
        _.apply(entry);
        return;
      }

      // 4. Show immediately if nothing is showing
      if (!root.visible) {
        _.apply(entry);
        return;
      }

      // 5. Queue logic (Add to pending if priority allows)
      if (!_.pending || entry.priority <= _.pending.priority) {
        _.pending = entry;
      }
    }
  }

  // --- Timers ---

  Timer {
    id: hideTimer

    interval: _.timeoutMs

    onTriggered: _.close()
  }

  Timer {
    id: debounceTimer

    interval: _.debounceMs

    onTriggered: {
      if (_.debounceEntry) {
        _.push(_.debounceEntry);
        _.debounceEntry = null;
      }
    }
  }

  // Initialization delay to prevent startup spam
  Timer {
    interval: 1000
    running: true

    onTriggered: _.initialized = true
  }

  // --- Service Connections ---

  Connections {
    function onMutedChanged() {
      const vol = Math.round(AudioService.volume * 100);
      root.show(root.types.volumeOutput, AudioService.muted ? 0 : vol, AudioService.muted ? "󰖁" : (vol >= 70 ? "󰕾" : vol >= 30 ? "󰖀" : "󰕿"), AudioService.muted ? "Muted" : `${vol}%`, false, Math.round(AudioService.maxVolume * 100));
    }

    function onSinkDeviceChanged(deviceName, icon) {
      root.show(root.types.audioDevice, null, icon || "󰓃", deviceName);
    }

    function onVolumeChanged() {
      const vol = Math.round(AudioService.volume * 100);
      root.show(root.types.volumeOutput, vol, (vol >= 70 ? "󰕾" : vol >= 30 ? "󰖀" : "󰕿"), `${vol}%`, false, Math.round(AudioService.maxVolume * 100));
    }

    target: AudioService
  }

  Connections {
    function onMutedChanged() {
      const muted = AudioService.source?.audio?.muted ?? false;
      root.show(root.types.micMute, null, muted ? "󰍭" : "󰍬", muted ? "Microphone Muted" : "Microphone Unmuted");
    }

    target: AudioService.source?.audio ?? null
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
    function onIsACPoweredChanged() {
      if (BatteryService.isLaptopBattery)
        root.show(root.types.battery, null, BatteryService.isACPowered ? "󰂄" : "󰂃", BatteryService.isACPowered ? "Charger Connected" : "Charger Disconnected");
    }

    function onIsFullyChargedChanged() {
      if (BatteryService.isLaptopBattery && BatteryService.isFullyCharged)
        root.show(root.types.battery, null, "󰚥", "Fully Charged");
    }

    function onIsPendingChargeChanged() {
      if (BatteryService.isLaptopBattery && BatteryService.isPendingCharge)
        root.show(root.types.battery, null, "󰂏", "Charge Limit Reached");
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
