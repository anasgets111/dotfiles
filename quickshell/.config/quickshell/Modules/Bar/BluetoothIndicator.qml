pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.Config
import qs.Components
import qs.Services.Core
import qs.Modules.Bar

Item {
  id: root

  readonly property var bt: BluetoothService
  readonly property string btIcon: {
    if (!bt?.available || !bt.enabled)
      return "󰂲";
    return connectedDevices.length > 0 ? "󰂱" : "󰂯";
  }
  readonly property var connectedDevices: bt?.devices.filter(d => d?.connected) ?? []
  readonly property string detailText1: {
    if (!bt?.available)
      return "";

    const d = topDevice;
    if (bt.enabled && d) {
      const name = d.name || d.deviceName || qsTr("Unknown device");
      const hasBatt = d.batteryAvailable && d.battery > 0;
      const battStr = hasBatt ? qsTr(" · Battery: %1%").arg(Math.round(d.battery * 100)) : "";
      return qsTr("Top: %1%2").arg(name).arg(battStr);
    }

    if (bt.enabled) {
      return bt.discovering ? qsTr("Discovering devices…") : pairedDevices.length > 0 ? qsTr("Paired: %1").arg(pairedDevices.length) : qsTr("No devices connected");
    }
    return "";
  }
  readonly property string detailText2: {
    if (!bt?.available)
      return "";
    const n = connectedDevices.length;
    if (n > 1)
      return qsTr("Others: %1 more").arg(n - 1);
    if (bt.enabled && !topDevice)
      return bt.discovering ? qsTr("Scanning is active") : "";
    return "";
  }
  readonly property var pairedDevices: bt?.pairedDevices ?? []
  readonly property var sortedConnected: connectedDevices.length > 1 ? bt?.sortDevices(connectedDevices) ?? [] : connectedDevices
  readonly property string titleText: {
    if (!bt?.available)
      return qsTr("Bluetooth: unavailable");
    if (!bt.enabled)
      return qsTr("Bluetooth: off");
    const n = connectedDevices.length;
    return n > 0 ? qsTr("Bluetooth: connected (%1)").arg(n) : qsTr("Bluetooth: on");
  }
  readonly property var topDevice: sortedConnected[0] ?? null

  function refreshAdapter() {
    if (!bt || typeof Bluetooth === 'undefined')
      return;
    const prop = "default" + "Adapter";
    bt.setAdapter(Bluetooth[prop]);
  }

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)

  Component.onCompleted: refreshAdapter()

  IconButton {
    id: iconButton

    enabled: true
    icon: root.btIcon
    tooltipText: [root.titleText, root.detailText1, root.detailText2].filter(t => t?.length > 0).join("\n")

    onClicked: function (mouse) {
      bluetoothPanelLoader.active = true;
    }
  }

  // Component definition for BluetoothPanel (better isolation)
  Component {
    id: bluetoothPanelComponent

    BluetoothPanel {
      property var loaderRef

      onPanelClosed: loaderRef.active = false
    }
  }

  // Loader for lazy-loading the panel
  Loader {
    id: bluetoothPanelLoader

    active: false
    sourceComponent: bluetoothPanelComponent

    onLoaded: {
      const panel = item as BluetoothPanel;
      panel.loaderRef = bluetoothPanelLoader;
      panel.openAtItem(iconButton, 0, 0);
    }
  }

  Connections {
    function onDefaultAdapterChanged() {
      root.refreshAdapter();
    }

    target: typeof Bluetooth !== 'undefined' ? Bluetooth : null
  }
}
