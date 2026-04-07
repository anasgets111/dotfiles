pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Components

Rectangle {
  id: pill

  property bool active: true
  property bool checked: false
  required property string icon
  required property string label
  property bool spinning: false

  signal toggled(bool checked)

  Layout.fillWidth: true
  Layout.preferredHeight: 56
  border.color: pill.checked && pill.active ? Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.3) : "transparent"
  border.width: 1
  color: pill.checked && pill.active ? Theme.activeSubtle : Theme.bgElevated
  opacity: pill.active ? 1.0 : Theme.opacityDisabled
  radius: 12

  Behavior on border.color {
    ColorAnimation {
      duration: 150
    }
  }
  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }
  Behavior on opacity {
    NumberAnimation {
      duration: 150
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: pill.active ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: pill.active

    onClicked: pill.toggled(!pill.checked)
  }

  ColumnLayout {
    anchors.centerIn: parent
    spacing: 4

    Text {
      Layout.alignment: Qt.AlignHCenter
      color: pill.checked && pill.active ? Theme.activeColor : Theme.textInactiveColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize * 1.3
      text: pill.icon

      Behavior on color {
        ColorAnimation {
          duration: 150
        }
      }
      RotationAnimation on rotation {
        duration: 2000
        from: 0
        loops: Animation.Infinite
        running: pill.spinning
        to: 360
      }
    }

    OText {
      Layout.alignment: Qt.AlignHCenter
      bold: pill.checked
      color: pill.checked && pill.active ? Theme.activeColor : Theme.textInactiveColor
      size: "xs"
      text: pill.label

      Behavior on color {
        ColorAnimation {
          duration: 150
        }
      }
    }
  }
}
