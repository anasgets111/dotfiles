pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs.Services.SystemInfo
import qs.Config

Item {
  id: root

  readonly property color effectiveBg: (root.hovered && !UpdateService.busy) ? Theme.onHoverColor : Theme.inactiveColor
  readonly property color effectiveFg: Theme.textContrast(effectiveBg)
  property bool hovered: false

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, row.implicitWidth + (2 * Theme.itemRadius), busyMeasureRow.implicitWidth + (2 * Theme.itemRadius))

  Rectangle {
    anchors.centerIn: parent
    color: root.effectiveBg
    height: implicitHeight
    implicitHeight: Math.max(row.implicitHeight, Theme.itemHeight)
    implicitWidth: Math.max(row.implicitWidth, busyMeasureRow.implicitWidth) + (Theme.itemRadius)
    radius: Theme.itemRadius
    width: implicitWidth

    MouseArea {
      id: mouseArea

      anchors.fill: parent
      cursorShape: UpdateService.busy ? Qt.BusyCursor : Qt.PointingHandCursor
      hoverEnabled: true

      onClicked: {
        if (UpdateService.busy)
          return;
        if (UpdateService.totalUpdates > 0)
          UpdateService.runUpdate();
        else
          UpdateService.doPoll(true);
      }
      onEntered: root.hovered = true
      onExited: root.hovered = false
    }
    RowLayout {
      id: row

      anchors.centerIn: parent
      spacing: 4

      Text {
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        Layout.preferredHeight: Theme.itemHeight
        color: root.effectiveFg
        elide: Text.ElideNone
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        text: UpdateService.busy ? "" : UpdateService.totalUpdates > 0 ? "" : "󰂪"
        verticalAlignment: Text.AlignVCenter
      }
      Item {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredHeight: Theme.itemHeight
        Layout.preferredWidth: updateCount.implicitWidth
        visible: UpdateService.totalUpdates > 0

        Text {
          id: updateCount

          anchors.verticalCenter: parent.verticalCenter
          color: root.effectiveFg
          elide: Text.ElideNone
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: UpdateService.totalUpdates
        }
      }
    }
    RowLayout {
      id: busyMeasureRow

      spacing: 4
      visible: false

      Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: ""
      }
    }
    Rectangle {
      anchors.left: mouseArea.left
      anchors.top: mouseArea.bottom
      anchors.topMargin: 8
      color: Theme.onHoverColor
      height: tooltipText.height + 8
      opacity: mouseArea.containsMouse ? 1 : 0
      radius: Theme.itemRadius
      visible: mouseArea.containsMouse && !UpdateService.busy
      width: tooltipText.width + 16

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.OutCubic
        }
      }

      Column {
        id: tooltipText

        anchors.centerIn: parent
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
