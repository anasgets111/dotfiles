pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Components

Rectangle {
  id: pill

  property bool active: true
  property bool checked: false
  property string detail: ""
  required property string icon
  required property string label
  property bool spinning: false

  signal toggled(bool checked)

  Layout.fillWidth: true
  Layout.preferredHeight: 56
  border.color: pill.checked && pill.active ? Theme.withOpacity(Theme.activeColor, 0.3) : "transparent"
  border.width: Theme.borderWidthThin
  color: pill.checked && pill.active ? Theme.activeSubtle : Theme.bgElevated
  opacity: pill.active ? 1.0 : Theme.opacityDisabled
  radius: Theme.radiusLg

  Behavior on border.color {
    ColorAnimation {
      duration: Theme.animationDuration
    }
  }
  Behavior on color {
    ColorAnimation {
      duration: Theme.animationDuration
    }
  }
  Behavior on opacity {
    NumberAnimation {
      duration: Theme.animationDuration
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: pill.active ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: pill.active

    onClicked: pill.toggled(!pill.checked)
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: pill.detail !== "" ? Theme.spacingMd : 0
    anchors.rightMargin: pill.detail !== "" ? Theme.spacingMd : 0
    spacing: Theme.spacingSm

    Item {
      Layout.fillWidth: true
      visible: pill.detail === ""
    }

    ColumnLayout {
      spacing: Theme.spacingXs

      Text {
        Layout.alignment: Qt.AlignHCenter
        color: pill.checked && pill.active ? Theme.activeColor : Theme.textInactiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize * 1.3
        text: pill.icon

        Behavior on color {
          ColorAnimation {
            duration: Theme.animationDuration
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
            duration: Theme.animationDuration
          }
        }
      }
    }

    Item {
      Layout.fillWidth: true
    }

    OText {
      Layout.maximumWidth: pill.width / 2
      color: pill.checked && pill.active ? Theme.textActiveColor : Theme.textInactiveColor
      elide: Text.ElideRight
      size: "xs"
      text: pill.detail
      visible: pill.detail !== ""

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }
  }
}
