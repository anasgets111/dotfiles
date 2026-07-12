pragma ComponentBehavior: Bound

import QtQuick
import qs.Components
import qs.Config
import qs.Services.Core
import qs.Services.UI

Item {
  id: root

  readonly property bool active: BluetoothService.available && BluetoothService.enabled
  readonly property string btIcon: !active ? "󰂲" : (connectedDevices.length > 0 ? "󰂱" : "󰂯")
  readonly property var connectedDevices: BluetoothService.deviceModels.filter(d => d.connected)
  readonly property string detailText1: {
    if (!active)
      return "";
    if (topDevice) {
      const battStr = topDevice.hasBattery ? qsTr(" · Battery: %1").arg(topDevice.batteryText) : "";
      return qsTr("Top: %1%2").arg(topDevice.name).arg(battStr);
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
  readonly property var pairedDevices: BluetoothService.deviceModels.filter(d => d.paired)
  readonly property bool panelOpen: ShellUiState.isPanelOpen("bluetooth", root.screenName)
  required property string screenName
  readonly property string titleText: {
    if (!BluetoothService.available)
      return qsTr("Bluetooth: unavailable");
    if (!BluetoothService.enabled)
      return qsTr("Bluetooth: off");
    return connectedDevices.length > 0 ? qsTr("Bluetooth: connected (%1)").arg(connectedDevices.length) : qsTr("Bluetooth: on");
  }
  readonly property var topDevice: connectedDevices[0] ?? null

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)

  IconButton {
    id: iconButton

    colorFg: root.connectedDevices.length > 0 ? Theme.activeColor : Theme.textContrast(Theme.inactiveColor)
    icon: root.btIcon
    isEnabled: true
    suppressTooltip: root.panelOpen
    tooltipText: [root.titleText, root.detailText1, root.detailText2].filter(t => t?.length > 0).join("\n")

    onClicked: ShellUiState.togglePanelForItem("bluetooth", root.screenName, iconButton)
  }
}
