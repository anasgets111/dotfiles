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
    bgColor: UpdateService.busy ? Theme.inactiveColor : (UpdateService.totalUpdates > 0 ? Theme.activeColor : Theme.inactiveColor)
    busy: UpdateService.busy
    iconText: UpdateService.busy ? "" : (UpdateService.totalUpdates > 0 ? "" : "󰂪")

    onLeftClicked: {
      if (UpdateService.busy)
        return;
      if (UpdateService.totalUpdates > 0)
        UpdateService.runUpdate();
      else
        UpdateService.doPoll(true);
    }
  }
  Component {
    id: updatesWithHeading

    Column {
      spacing: 4

      Text {
        color: Theme.textContrast(Theme.onHoverColor)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: UpdateService.totalUpdates === 1 ? qsTr("One package can be upgraded:") : UpdateService.totalUpdates + " " + qsTr("packages can be upgraded:")
      }
      Repeater {
        model: UpdateService.allPackages

        delegate: Text {
          required property var model

          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: model.name + ": " + model.oldVersion + " → " + model.newVersion
        }
      }
    }
  }
  Tooltip {
    contentComponent: UpdateService.totalUpdates > 0 ? updatesWithHeading : null
    edge: Qt.BottomEdge
    hoverSource: button.area
    target: button
    text: UpdateService.totalUpdates === 0 ? qsTr("No updates available") : ""
    visibleWhenTargetHovered: !UpdateService.busy
  }
}
