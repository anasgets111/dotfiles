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

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, button.implicitWidth)

  IconButton {
    id: button

    readonly property bool isError: UpdateService.isError
    readonly property bool isUpdating: UpdateService.isUpdating
    property real spinAngle: 0

    anchors.fill: parent
    colorBg: isError ? Theme.critical : isUpdating ? Theme.activeColor : UpdateService.busy ? Theme.inactiveColor : UpdateService.totalUpdates > 0 ? Theme.activeColor : Theme.inactiveColor
    icon: isUpdating ? "󰦖" : isError ? "󰅙" : UpdateService.busy ? "" : UpdateService.totalUpdates > 0 ? "" : "󰂪"
    iconRotation: isUpdating ? spinAngle : 0
    suppressTooltip: root.panelOpen
    tooltipText: isUpdating ? qsTr("Updating system and developer tooling...") : isError ? qsTr("Update failed - click for details") : UpdateService.busy ? qsTr("Checking for updates…") : UpdateService.totalUpdates === 0 ? qsTr("No system package updates - right-click for updater") : UpdateService.totalUpdates === 1 ? qsTr("One package can be upgraded") : qsTr("%1 packages can be upgraded").arg(UpdateService.totalUpdates)

    NumberAnimation on spinAngle {
      duration: 1000
      from: 0
      loops: Animation.Infinite
      running: button.isUpdating
      to: 360
    }

    onClicked: mouse => {
      if (UpdateService.busy && UpdateService.isIdle)
        return;
      if (mouse.button === Qt.RightButton || UpdateService.totalUpdates > 0 || !UpdateService.isIdle) {
        ShellUiState.togglePanelForItem("updates", root.screenName, button);
      } else {
        UpdateService.doPoll();
      }
    }
  }
}
