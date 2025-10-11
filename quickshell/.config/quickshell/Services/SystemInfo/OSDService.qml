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

  // OSD State
  property bool visible: false
  property string osdType: ""
  property var osdValue: null
  property string osdIcon: ""
  property string osdLabel: ""

  // Configuration
  property int timeout: 2000
  property bool initialized: false

  // OSD Type Constants
  readonly property string typeVolumeOutput: "volume-output"
  readonly property string typeVolumeInput: "volume-input"
  readonly property string typeWifi: "wifi"
  readonly property string typeNetworking: "networking"
  readonly property string typeBluetooth: "bluetooth"
  readonly property string typeDnd: "dnd"
  readonly property string typeKeyboardLayout: "keyboard-layout"
  readonly property string typeCapsLock: "caps-lock"
  readonly property string typeNumLock: "num-lock"
  readonly property string typeScrollLock: "scroll-lock"

  // Auto-hide timer
  Timer {
    id: hideTimer
    interval: root.timeout
    repeat: false
    running: false
    onTriggered: root.hideOSD()
  }

  // Initialization delay timer
  Timer {
    id: initTimer
    interval: 1000
    repeat: false
    running: false
    onTriggered: {
      root.initialized = true;
      Logger.log("OSDService", "Service initialized and ready");
    }
  }

  // Core Functions
  function showOSD(type, value, icon, label) {
    if (!root.initialized)
      return;

    root.osdType = type || "";
    root.osdValue = value !== undefined ? value : null;
    root.osdIcon = icon || "";
    root.osdLabel = label || "";
    root.visible = true;

    hideTimer.restart();
    Logger.log("OSDService", `Show OSD: ${type} = ${value}`);
  }

  function hideOSD() {
    root.visible = false;
    hideTimer.stop();
  }

  // Monitor AudioService
  Connections {
    target: typeof AudioService !== "undefined" ? AudioService : null

    function onVolumeChanged() {
      const volume = Math.round(AudioService.volume * 100);
      const icon = AudioService.muted ? "󰖁" : (volume >= 70 ? "󰕾" : volume >= 30 ? "󰖀" : "󰕿");
      root.showOSD(root.typeVolumeOutput, volume, icon, `${volume}%`);
    }

    function onMutedChanged() {
      const volume = Math.round(AudioService.volume * 100);
      const icon = AudioService.muted ? "󰖁" : (volume >= 70 ? "󰕾" : volume >= 30 ? "󰖀" : "󰕿");
      root.showOSD(root.typeVolumeOutput, AudioService.muted ? 0 : volume, icon, AudioService.muted ? "Muted" : `${volume}%`);
    }
  }

  // Monitor NetworkService
  Connections {
    target: typeof NetworkService !== "undefined" ? NetworkService : null

    function onWifiRadioEnabledChanged() {
      root.showOSD(root.typeWifi, NetworkService.wifiRadioEnabled, NetworkService.wifiRadioEnabled ? "󰖩" : "󰖪", NetworkService.wifiRadioEnabled ? "WiFi On" : "WiFi Off");
    }

    function onNetworkingEnabledChanged() {
      root.showOSD(root.typeNetworking, NetworkService.networkingEnabled, NetworkService.networkingEnabled ? "󰈀" : "󰪎", NetworkService.networkingEnabled ? "Networking On" : "Networking Off");
    }
  }

  // Monitor BluetoothService
  Connections {
    target: typeof BluetoothService !== "undefined" ? BluetoothService : null

    function onEnabledChanged() {
      root.showOSD(root.typeBluetooth, BluetoothService.enabled, BluetoothService.enabled ? "󰂯" : "󰂲", BluetoothService.enabled ? "Bluetooth On" : "Bluetooth Off");
    }
  }

  // Monitor NotificationService for DND changes
  Connections {
    target: typeof NotificationService !== "undefined" ? NotificationService : null

    function onDoNotDisturbChanged() {
      root.showOSD(root.typeDnd, NotificationService.doNotDisturb, NotificationService.doNotDisturb ? "󰂛" : "󰂚", NotificationService.doNotDisturb ? "Do Not Disturb On" : "Do Not Disturb Off");
    }
  }

  // Monitor KeyboardLayoutService for layout and lock key changes
  Connections {
    target: typeof KeyboardLayoutService !== "undefined" ? KeyboardLayoutService : null

    function onCurrentLayoutChanged() {
      const layoutCode = KeyboardLayoutService.currentLayout || "??";
      root.showOSD(root.typeKeyboardLayout, layoutCode, "󰌌", `Layout: ${layoutCode}`);
    }

    function onCapsOnChanged() {
      root.showOSD(root.typeCapsLock, KeyboardLayoutService.capsOn, "󰘲", KeyboardLayoutService.capsOn ? "Caps Lock On" : "Caps Lock Off");
    }

    function onNumOnChanged() {
      root.showOSD(root.typeNumLock, KeyboardLayoutService.numOn, "󰎠", KeyboardLayoutService.numOn ? "Num Lock On" : "Num Lock Off");
    }

    function onScrollOnChanged() {
      root.showOSD(root.typeScrollLock, KeyboardLayoutService.scrollOn, "󰌐", KeyboardLayoutService.scrollOn ? "Scroll Lock On" : "Scroll Lock Off");
    }
  }

  Component.onCompleted: {
    initTimer.start();
    Logger.log("OSDService", "Service created, waiting 1s before showing OSDs");
  }
}
