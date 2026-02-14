pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Components
import qs.Services.Core
import qs.Modules.Bar.Panels

Item {
  id: root

  readonly property bool active: BluetoothService.available && BluetoothService.enabled
  readonly property string btIcon: !active ? "󰂲" : (connectedDevices.length > 0 ? "󰂱" : "󰂯")
  readonly property var devices: BluetoothService.devices ?? []
  readonly property var connectedDevices: devices.filter(d => d?.connected)
  readonly property string detailText1: {
    if (!active)
      return "";
    if (topDevice) {
      const name = topDevice.name || topDevice.deviceName || qsTr("Unknown device");
      const battStr = topDevice.batteryAvailable && topDevice.battery > 0 ? qsTr(" · Battery: %1").arg(BluetoothService.getBattery(topDevice)) : "";
      return qsTr("Top: %1%2").arg(name).arg(battStr);
    }
    return BluetoothService.discovering ? qsTr("Discovering devices…") : (pairedDevices.length > 0 ? qsTr("Paired: %1").arg(pairedDevices.length) : qsTr("No devices connected"));
  }
  readonly property string detailText2: {
    if (!active)
      return "";
    if (connectedDevices.length > 1)
      return qsTr("Others: %1 more").arg(connectedDevices.length - 1);
    return topDevice ? "" : (BluetoothService.discovering ? qsTr("Scanning is active") : "");
  }
  readonly property var pairedDevices: devices.filter(d => d?.paired || d?.trusted)
  readonly property string titleText: {
    if (!BluetoothService.available)
      return qsTr("Bluetooth: unavailable");
    if (!BluetoothService.enabled)
      return qsTr("Bluetooth: off");
    return connectedDevices.length > 0 ? qsTr("Bluetooth: connected (%1)").arg(connectedDevices.length) : qsTr("Bluetooth: on");
  }
  readonly property var topDevice: connectedDevices.length > 1 ? BluetoothService.sortDevices(connectedDevices)[0] : connectedDevices[0]

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
