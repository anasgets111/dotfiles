pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs.Services.SystemInfo
import qs.Config
import qs.Widgets

Item {
  id: root

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, iconButton.implicitWidth)

  IconButton {
    id: iconButton

    anchors.centerIn: parent
    disabled: UpdateService.busy

    contentItem: RowLayout {
      spacing: 4

      Text {
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        Layout.preferredHeight: Theme.itemHeight
        color: iconButton.fgColor
        elide: Text.ElideNone
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        text: UpdateService.busy ? "" : UpdateService.totalUpdates > 0 ? "" : "󰂪"
        verticalAlignment: Text.AlignVCenter
      }
    }

    onClicked: {
      if (UpdateService.totalUpdates > 0)
        UpdateService.runUpdate();
      else
        UpdateService.doPoll(true);
    }
  }
  Tooltip {
    hoverSource: iconButton.area
    target: iconButton
    visibleWhenTargetHovered: !UpdateService.busy

    contentComponent: Component {
      Column {
        spacing: 4

        Text {
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: UpdateService.totalUpdates === 0 ? qsTr("No updates available") : UpdateService.totalUpdates === 1 ? qsTr("One package can be upgraded:") : UpdateService.totalUpdates + qsTr(" packages can be upgraded:")
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
  }
}
