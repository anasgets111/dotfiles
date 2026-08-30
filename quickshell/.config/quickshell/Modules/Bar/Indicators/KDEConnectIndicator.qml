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

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, button.implicitWidth)

  IconButton {
    id: button

    colorFg: KDEConnectService.connectedCount > 0 ? Theme.activeColor : Theme.textContrast(Theme.glassControlColor)
    icon: KDEConnectService.connectedCount > 0 ? "󰄜" : "󰥐"
    selected: root.panelOpen
    suppressTooltip: root.panelOpen
    tooltipText: KDEConnectService.connectedCount > 0 ? qsTr("KDE Connect · %1 connected").arg(KDEConnectService.connectedCount) : qsTr("KDE Connect · no devices connected")

    onClicked: ShellUiState.togglePanelForItem("kdeconnect", root.screenName, button)
  }
}
