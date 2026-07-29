pragma ComponentBehavior: Bound

import QtQuick
import qs.Components
import qs.Config
import qs.Services.Core
import qs.Services.UI

Item {
  id: root

  required property string screenName
  readonly property bool panelOpen: ShellUiState.isPanelOpen("kdeconnect", screenName)
  readonly property string icon: KDEConnectService.connectedCount > 0 ? "󰄜" : "󰥐"
  readonly property string title: KDEConnectService.connectedCount > 0 ? qsTr("KDE Connect · %1 connected").arg(KDEConnectService.connectedCount) : qsTr("KDE Connect · no devices connected")

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, button.implicitWidth)

  IconButton {
    id: button

    colorFg: KDEConnectService.connectedCount > 0 ? Theme.activeColor : Theme.textContrast(Theme.glassControlColor)
    icon: root.icon
    selected: root.panelOpen
    suppressTooltip: root.panelOpen
    tooltipText: root.title

    onClicked: ShellUiState.togglePanelForItem("kdeconnect", root.screenName, button)
  }
}
