pragma ComponentBehavior: Bound
import QtQuick
import qs.Components
import qs.Config
import qs.Services.SystemInfo
import qs.Services.UI

Item {
  id: root

  readonly property bool panelOpen: ShellUiState.isPanelOpen("updates", root.screenName)
  required property string screenName
  readonly property int updateState: UpdateService.updateState

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, button.implicitWidth)

  IconButton {
    id: button

    readonly property bool isError: root.updateState === UpdateService.status.Error
    readonly property bool isUpdating: root.updateState === UpdateService.status.Updating
    property real spinAngle: 0

    anchors.fill: parent
    colorBg: isError ? Theme.critical : isUpdating ? Theme.activeColor : UpdateService.busy ? Theme.inactiveColor : UpdateService.totalUpdates > 0 ? Theme.activeColor : Theme.inactiveColor
    icon: isUpdating ? "󰦖" : isError ? "󰅙" : UpdateService.busy ? "" : UpdateService.totalUpdates > 0 ? "" : "󰂪"
    rotation: isUpdating ? spinAngle : 0
    suppressTooltip: root.panelOpen
    tooltipText: isUpdating ? qsTr("Installing updates...") : isError ? qsTr("Update failed - click for details") : UpdateService.busy ? qsTr("Checking for updates…") : UpdateService.totalUpdates === 0 ? qsTr("No updates available") : UpdateService.totalUpdates === 1 ? qsTr("One package can be upgraded") : qsTr("%1 packages can be upgraded").arg(UpdateService.totalUpdates)

    NumberAnimation on spinAngle {
      duration: 1000
      from: 0
      loops: Animation.Infinite
      running: button.isUpdating
      to: 360
    }

    onClicked: mouse => {
      if (UpdateService.busy)
        return;
      if (mouse.button === Qt.RightButton || UpdateService.totalUpdates > 0 || root.updateState !== UpdateService.status.Idle) {
        ShellUiState.togglePanelForItem("updates", root.screenName, button);
      } else {
        UpdateService.doPoll();
      }
    }
  }
}
