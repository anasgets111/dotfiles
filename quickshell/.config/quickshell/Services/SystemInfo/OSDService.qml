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

  property bool batteryTransitionPending: false
  property var currentEntry: null
  readonly property int debounceTimeout: 150
  readonly property real defaultPriority: 100
  readonly property var groupByType: ({
      [root.types.capsLock]: "locks",
      [root.types.numLock]: "locks",
      [root.types.scrollLock]: "locks"
    })
  property bool initialized: false
  property string osdIcon: ""
  property string osdLabel: ""
  property var osdMaxValue: 100
  property string osdType: ""
  property var osdValue: null
  property var pendingByType: ({})
  readonly property var priorityByType: ({
      [root.types.battery]: 0,
      [root.types.recording]: 0,
      [root.types.audioDevice]: 1,
      [root.types.micMute]: 1,
      [root.types.networking]: 2,
      [root.types.wifi]: 2,
      [root.types.bluetooth]: 2,
      [root.types.volumeOutput]: 3,
      [root.types.brightness]: 3,
      [root.types.keyboardBacklight]: 4,
      [root.types.keyboardLayout]: 4,
      [root.types.capsLock]: 4,
      [root.types.numLock]: 4,
      [root.types.scrollLock]: 4,
      [root.types.dnd]: 4
    })
  property int requestSequence: 0
  readonly property var suppressionMatrix: ({
      [root.types.battery]: [root.types.brightness, root.types.keyboardBacklight],
      [root.types.audioDevice]: [root.types.volumeOutput],
      [root.types.bluetooth]: [root.types.audioDevice],
      [root.types.networking]: [root.types.wifi],
      [root.types.micMute]: [root.types.volumeOutput]
    })

  // Tuning
  readonly property int timeout: 2000
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

  // API
  function _handleRequest(entry) {
    entry.priority = priorityFor(entry.type);
    entry.sequence = ++requestSequence;

    if (batteryTransitionPending && isSuppressedBy(root.types.battery, entry.type)) {
      dropPending(entry.type);
      Logger.log("OSDService", `Skipped ${entry.type} while battery notice pending`);
      return;
    }

    const active = currentEntry;
    if (active && isSuppressedBy(active.type, entry.type)) {
      dropPending(entry.type);
      return;
    }

    if (active) {
      if (entry.type === active.type || sameGroup(entry.type, active.type))
        return applyEntry(entry, active.priority);

      if (entry.priority < active.priority) {
        const requeued = cloneEntry(active);
        requeued.sequence = ++requestSequence;
        enqueueEntry(requeued);
        return applyEntry(entry);
      }
    }

    if (!visible)
      return applyEntry(entry);
    enqueueEntry(entry);
  }

  // Presentation
  function applyEntry(entry, overridePriority) {
    dropPending(entry.type);
    const active = ensureSequence(cloneEntry(entry, overridePriority));
    currentEntry = active;
    osdType = active.type;
    osdValue = active.value;
    osdIcon = active.icon;
    osdLabel = active.label;
    osdMaxValue = active.maxValue ?? 100;
    visible = true;
    hideTimer.restart();
    clearSuppressedPending(active.type);
    refreshBatteryPending();
    Logger.log("OSDService", `Show OSD: ${active.type} = ${active.value}`);
  }

  function clearSuppressedPending(forType) {
    const list = suppressionMatrix[forType];
    if (!Array.isArray(list))
      return;
    for (let i = 0; i < list.length; ++i)
      dropPending(list[i]);
  }

  function cloneEntry(entry, overridePriority) {
    return {
      type: entry.type,
      value: entry.value,
      icon: entry.icon,
      label: entry.label,
      maxValue: entry.maxValue ?? 100,
      priority: overridePriority ?? entry.priority ?? priorityFor(entry.type),
      sequence: entry.sequence
    };
  }

  function dropPending(type) {
    if (pendingByType[type])
      delete pendingByType[type];
    const g = groupFor(type);
    if (g)
      for (const k in groupByType)
        if (groupByType[k] === g && pendingByType[k])
          delete pendingByType[k];
    refreshBatteryPending();
  }

  function enqueueEntry(entry) {
    dropPending(entry.type);
    pendingByType[entry.type] = ensureSequence(cloneEntry(entry));
    refreshBatteryPending();
  }

  function ensureSequence(entry) {
    if (!entry.sequence)
      entry.sequence = ++requestSequence;
    return entry;
  }

  function groupFor(type) {
    return groupByType[type] || "";
  }

  function hideOSD() {
    if (!visible)
      return;
    visible = false;
    hideTimer.stop();
    currentEntry = null;
    refreshBatteryPending();
    showNextPending();
  }

  function isSuppressedBy(suppressor, type) {
    const list = suppressionMatrix[suppressor];
    return Array.isArray(list) && list.indexOf(type) !== -1;
  }

  // Utilities
  function priorityFor(type) {
    const p = priorityByType[type];
    return typeof p === "number" ? p : defaultPriority;
  }

  function refreshBatteryPending() {
    batteryTransitionPending = (currentEntry && currentEntry.type === root.types.battery) || !!pendingByType[root.types.battery];
  }

  function sameGroup(a, b) {
    return !!a && !!b && (a === b || (groupFor(a) !== "" && groupFor(a) === groupFor(b)));
  }

  function showNextPending() {
    let best = null;
    for (const t in pendingByType) {
      const c = pendingByType[t];
      if (c && (!best || c.priority < best.priority || (c.priority === best.priority && c.sequence > best.sequence)))
        best = c;
    }
    if (best)
      applyEntry(best);
  }

  function showOSD(type, value, icon, label, debounce = false, maxValue = 100) {
    if (!initialized)
      return;
    const entry = {
      type,
      value: value !== undefined ? value : null,
      icon,
      label,
      maxValue
    };
    if (debounce) {
      debounceTimer.pendingOSD = entry;
      debounceTimer.restart();
      return;
    }
    _handleRequest(entry);
  }

  function showToggleOSD(type, enabled, iconOn, iconOff, label) {
    showOSD(type, enabled, enabled ? iconOn : iconOff, `${label} ${enabled ? "On" : "Off"}`);
  }

  // Helpers for signals
  function volumeIcon(vol, muted) {
    return muted ? "󰖁" : (vol >= 70 ? "󰕾" : vol >= 30 ? "󰖀" : "󰕿");
  }

  Component.onCompleted: {
    initTimer.start();
    Logger.log("OSDService", "Service created, waiting 1s before showing OSDs");
  }

  // Timers
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

  // Connections (condensed)
  Connections {
    function onMutedChanged() {
      const vol = Math.round(AudioService.volume * 100);
      const icon = root.volumeIcon(vol, AudioService.muted);
      const value = AudioService.muted ? 0 : vol;
      const label = AudioService.muted ? "Muted" : `${vol}%`;
      root.showOSD(root.types.volumeOutput, value, icon, label, false, AudioService.maxVolumePercent);
    }

    function onSinkDeviceChanged(deviceName, icon) {
      root.showOSD(root.types.audioDevice, null, icon || "󰓃", deviceName);
    }

    function onVolumeChanged() {
      const vol = Math.round(AudioService.volume * 100);
      root.showOSD(root.types.volumeOutput, vol, root.volumeIcon(vol, AudioService.muted), `${vol}%`, false, AudioService.maxVolumePercent);
    }

    target: typeof AudioService !== "undefined" ? AudioService : null
  }

  Connections {
    function onNetworkingEnabledChanged() {
      root.showToggleOSD(root.types.networking, NetworkService.networkingEnabled, "󰈀", "󰪎", "Networking");
    }

    function onWifiRadioEnabledChanged() {
      root.showToggleOSD(root.types.wifi, NetworkService.wifiRadioEnabled, "󰖩", "󰖪", "WiFi");
    }

    target: typeof NetworkService !== "undefined" ? NetworkService : null
  }

  Connections {
    function onEnabledChanged() {
      root.showToggleOSD(root.types.bluetooth, BluetoothService.enabled, "󰂯", "󰂲", "Bluetooth");
    }

    target: typeof BluetoothService !== "undefined" ? BluetoothService : null
  }

  Connections {
    function onOnBatteryChanged() {
      const icon = PowerManagementService.onBattery ? "󰂃" : "󰂄";
      const label = PowerManagementService.onBattery ? "Running on Battery" : "Power Connected";
      root.showOSD(root.types.battery, null, icon, label);
    }

    target: typeof PowerManagementService !== "undefined" ? PowerManagementService : null
  }

  Connections {
    function onPercentageChanged() {
      if (!BrightnessService.ready)
        return;
      const percent = BrightnessService.percentage;
      const icon = percent >= 70 ? "󰃠" : percent >= 30 ? "󰃟" : "󰃞";
      root.showOSD(root.types.brightness, percent, icon, `${percent}%`, true);
    }

    target: typeof BrightnessService !== "undefined" ? BrightnessService : null
  }

  Connections {
    function onBrightnessChanged() {
      if (!KeyboardBacklightService.ready)
        return;
      root.showOSD(root.types.keyboardBacklight, null, "⌨", `Backlight: ${KeyboardBacklightService.levelName}`);
    }

    target: typeof KeyboardBacklightService !== "undefined" ? KeyboardBacklightService : null
  }

  Connections {
    function onDoNotDisturbChanged() {
      root.showToggleOSD(root.types.dnd, NotificationService.doNotDisturb, "󰂛", "󰂚", "Do Not Disturb");
    }

    target: typeof NotificationService !== "undefined" ? NotificationService : null
  }

  Connections {
    function onCapsOnChanged() {
      root.showToggleOSD(root.types.capsLock, KeyboardLayoutService.capsOn, "󰘲", "󰘲", "Caps Lock");
    }

    function onCurrentLayoutChanged() {
      const layoutCode = KeyboardLayoutService.currentLayout || "??";
      root.showOSD(root.types.keyboardLayout, layoutCode, "", `Layout: ${layoutCode}`);
    }

    function onNumOnChanged() {
      root.showToggleOSD(root.types.numLock, KeyboardLayoutService.numOn, "", "", "Num Lock");
    }

    function onScrollOnChanged() {
      root.showToggleOSD(root.types.scrollLock, KeyboardLayoutService.scrollOn, "󰌐", "", "Scroll Lock");
    }

    target: typeof KeyboardLayoutService !== "undefined" ? KeyboardLayoutService : null
  }

  Connections {
    function onMicMuteChanged() {
      if (!AudioService.source?.audio)
        return;
      const muted = AudioService.source.audio.muted;
      const label = muted ? "Microphone Muted" : "Microphone Unmuted";
      const vol = Math.round((AudioService.source.audio.volume || 0) * 100);
      root.showOSD(root.types.micMute, muted, muted ? "󰍭" : "󰍬", label);
    }

    target: typeof AudioService !== "undefined" ? AudioService : null
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

    target: typeof BatteryService !== "undefined" ? BatteryService : null
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

    target: typeof ScreenRecordingService !== "undefined" ? ScreenRecordingService : null
  }
}
