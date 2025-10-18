pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Components
import qs.Services.Core
import qs.Modules.Bar

Item {
  id: root

  readonly property bool active: bt?.available && bt.enabled
  readonly property var bt: BluetoothService
  readonly property string btIcon: {
    if (!active)
      return "󰂲";
    return connectedDevices.length > 0 ? "󰂱" : "󰂯";
  }
  readonly property var connectedDevices: bt?.devices.filter(d => d?.connected) ?? []
  readonly property string detailText1: {
    if (!active)
      return "";
    const d = topDevice;
    if (d) {
      const name = d.name || d.deviceName || qsTr("Unknown device");
      const battStr = d.batteryAvailable && d.battery > 0 ? qsTr(" · Battery: %1").arg(BluetoothService.getBattery(d)) : "";
      return qsTr("Top: %1%2").arg(name).arg(battStr);
    }
    return bt.discovering ? qsTr("Discovering devices…") : pairedDevices.length > 0 ? qsTr("Paired: %1").arg(pairedDevices.length) : qsTr("No devices connected");
  }
  readonly property string detailText2: {
    if (!active)
      return "";
    const n = connectedDevices.length;
    if (n > 1)
      return qsTr("Others: %1 more").arg(n - 1);
    return topDevice ? "" : (bt.discovering ? qsTr("Scanning is active") : "");
  }
  readonly property var pairedDevices: bt?.pairedDevices ?? []
  readonly property string titleText: {
    if (!bt?.available)
      return qsTr("Bluetooth: unavailable");
    if (!bt.enabled)
      return qsTr("Bluetooth: off");
    const n = connectedDevices.length;
    return n > 0 ? qsTr("Bluetooth: connected (%1)").arg(n) : qsTr("Bluetooth: on");
  }
  readonly property var topDevice: topList[0] ?? null
  readonly property var topList: (connectedDevices.length > 1 ? bt?.sortDevices(connectedDevices) ?? [] : connectedDevices)

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)

  IconButton {
    id: iconButton

    enabled: true
    icon: root.btIcon
    tooltipText: [root.titleText, root.detailText1, root.detailText2].filter(t => t?.length > 0).join("\n")

    onClicked: function (mouse) {
      bluetoothPanelLoader.active = true;
    }
  }

  Component {
    id: bluetoothPanelComponent

    BluetoothPanel {
      property var loaderRef

      onPanelClosed: loaderRef.active = false
    }
  }

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
}
