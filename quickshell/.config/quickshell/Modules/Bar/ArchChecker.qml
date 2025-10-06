pragma ComponentBehavior: Bound
import QtQuick
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

    icon: {
      if (UpdateService.updateState === UpdateService.status.Updating)
        return "󰦖";
      if (UpdateService.updateState === UpdateService.status.Error)
        return "󰅙";
      if (UpdateService.busy)
        return "";
      return UpdateService.totalUpdates > 0 ? "" : "󰂪";
    }

    colorBg: {
      if (UpdateService.updateState === UpdateService.status.Error)
        return Theme.critical;
      if (UpdateService.updateState === UpdateService.status.Updating)
        return Theme.activeColor;
      if (UpdateService.busy)
        return Theme.inactiveColor;
      return UpdateService.totalUpdates > 0 ? Theme.activeColor : Theme.inactiveColor;
    }

    tooltipText: {
      if (UpdateService.updateState === UpdateService.status.Updating)
        return qsTr("Installing updates...");
      if (UpdateService.updateState === UpdateService.status.Error)
        return qsTr("Update failed - click for details");
      if (UpdateService.busy)
        return qsTr("Checking for updates…");
      if (UpdateService.totalUpdates === 0)
        return qsTr("No updates available");
      if (UpdateService.totalUpdates === 1)
        return qsTr("One package can be upgraded");
      return qsTr("%1 packages can be upgraded").arg(UpdateService.totalUpdates);
    }

    RotationAnimator on rotation {
      running: UpdateService.updateState === UpdateService.status.Updating
      from: 0
      to: 360
      duration: 1000
      loops: Animation.Infinite
    }

    Connections {
      target: UpdateService
      function onUpdateStateChanged() {
        if (UpdateService.updateState !== UpdateService.status.Updating)
          button.rotation = 0;
      }
    }

    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        if (UpdateService.totalUpdates > 0 || UpdateService.updateState !== UpdateService.status.Idle) {
          updatePanel.useButtonPosition = true;
          updatePanel.buttonPosition = button.mapToGlobal(0, 0);
          updatePanel.buttonWidth = button.width;
          updatePanel.buttonHeight = button.height;
          updatePanel.isOpen = true;
        }
        return;
      }
      if (UpdateService.busy)
        return;
      UpdateService.totalUpdates > 0 ? UpdateService.runUpdate() : UpdateService.doPoll(true);
    }
  }

  UpdatePanel {
    id: updatePanel
  }
}
