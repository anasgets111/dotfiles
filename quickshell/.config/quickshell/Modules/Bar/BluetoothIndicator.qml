pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Widgets
import qs.Services.Core

Item {
  id: root

  readonly property var bt: BluetoothService

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)
  // visible: bt && bt.isReady

  // Helpers
  function isConnectedDevice(d) {
    if (!d)
      return false;
    // Prefer explicit 'connected' when available; fallback to state label
    if (d.connected !== undefined)
      return !!d.connected;
    const st = (d.state !== undefined) ? d.state : null;
    // 8 is often Connected in BlueZ enums, but avoid magic numbers overall
    return st && String(st).toLowerCase().indexOf("connected") !== -1;
  }

  readonly property var connectedDevices: (bt && bt.devices) ? bt.devices.filter(d => isConnectedDevice(d)) : []
  readonly property var pairedDevices: (bt && bt.pairedDevices) ? bt.pairedDevices : []
  readonly property var sortedConnected: (bt && connectedDevices && connectedDevices.length > 1) ? bt.sortDevices(connectedDevices) : connectedDevices
  readonly property var topDevice: (sortedConnected && sortedConnected.length > 0) ? sortedConnected[0] : null

  // Icons (Nerd Font / MDI)
  // - On, connected: 󰂱  (bluetooth-connected)
  // - On, idle:      󰂯  (bluetooth)
  // - Off/unavail:   󰂲  (bluetooth-off)
  readonly property string btIcon: {
    if (!bt || !bt.available)
      return "󰂲";
    if (!bt.enabled)
      return "󰂲";
    if (connectedDevices && connectedDevices.length > 0)
      return "󰂱";
    return "󰂯";
  }

  // Tooltip strings
  readonly property string titleText: {
    if (!bt || !bt.available)
      return qsTr("Bluetooth: unavailable");
    if (!bt.enabled)
      return qsTr("Bluetooth: off");
    const n = connectedDevices ? connectedDevices.length : 0;
    return n > 0 ? qsTr("Bluetooth: connected (%1)").arg(n) : qsTr("Bluetooth: on");
  }
  readonly property string detailText1: {
    if (!bt || !bt.available)
      return "";
    const d = topDevice;
    if (bt.enabled && d) {
      const name = (d.name || d.deviceName || qsTr("Unknown device"));
      const sig = bt.getSignalStrength ? bt.getSignalStrength(d) : "";
      const hasBatt = !!(d.batteryAvailable && d.battery > 0);
      const battStr = hasBatt ? qsTr(" · Battery: %1% ").arg(d.battery) : "";
      return qsTr("Top: %1 · Signal: %2%3").arg(name).arg(sig).arg(battStr);
    }
    if (bt.enabled) {
      return bt.discovering ? qsTr("Discovering devices…") : (pairedDevices && pairedDevices.length > 0 ? qsTr("Paired: %1").arg(pairedDevices.length) : qsTr("No devices connected"));
    }
    return "";
  }
  readonly property string detailText2: {
    if (!bt || !bt.available)
      return "";
    const n = connectedDevices ? connectedDevices.length : 0;
    if (n > 1)
      return qsTr("Others: %1 more").arg(n - 1);
    if (bt.enabled && !topDevice)
      return bt.discovering ? qsTr("Scanning is active") : "";
    return "";
  }

  IconButton {
    id: iconButton

    disabled: true
    iconText: root.btIcon
  }
  Tooltip {
    hoverSource: iconButton.area
    target: iconButton
    contentComponent: Component {
      Column {
        spacing: 2
        // Title
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: true
          text: root.titleText
        }
        // Detail 1
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          opacity: 0.85
          text: root.detailText1
          visible: text.length > 0
        }
        // Detail 2
        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          opacity: 0.65
          text: root.detailText2
          visible: text.length > 0
        }
      }
    }
  }
}
