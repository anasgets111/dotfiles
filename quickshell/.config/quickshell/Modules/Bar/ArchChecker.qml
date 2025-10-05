pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import qs.Services.SystemInfo
import qs.Config
import qs.Components

Item {
  id: root

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, button.implicitWidth)

  IconButton {
    id: button
    anchors.fill: parent
    colorBg: UpdateService.busy ? Theme.inactiveColor : (UpdateService.totalUpdates > 0 ? Theme.activeColor : Theme.inactiveColor)
    icon: UpdateService.busy ? "" : (UpdateService.totalUpdates > 0 ? "" : "󰂪")
    tooltipText: UpdateService.busy ? qsTr("Checking for updates…") : (UpdateService.totalUpdates === 0 ? qsTr("No updates available") : (UpdateService.totalUpdates === 1 ? qsTr("One package can be upgraded") : qsTr("%1 packages can be upgraded").arg(UpdateService.totalUpdates)))
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        if (UpdateService.totalUpdates > 0) {
          updatePanel.openAtItem(button, mouse.x, mouse.y);
        }
        return;
      }

      if (UpdateService.busy)
        return;
      if (UpdateService.totalUpdates > 0)
        UpdateService.runUpdate();
      else
        UpdateService.doPoll(true);
    }
  }

  UpdatePanel {
    id: updatePanel
    maxVisibleItems: 10
    panelWidth: 500
  }
}
