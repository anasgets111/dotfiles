pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config

Rectangle {
  id: card

  property bool active: true
  property bool checked: false
  readonly property bool compact: width < Theme.panelToggleCompactThreshold
  property string detail: ""
  readonly property color detailColor: checked && active ? Theme.textActiveColor : Theme.textInactiveColor
  required property string icon
  readonly property color labelColor: checked && active ? Theme.activeColor : Theme.textInactiveColor
  required property string label
  property bool spinning: false
  readonly property bool wide: !compact && detail !== ""

  signal toggled(bool checked)

  Layout.fillWidth: true
  Layout.preferredHeight: Theme.panelToggleCardHeight
  Layout.preferredWidth: 0
  border.color: card.checked && card.active ? Theme.withOpacity(Theme.activeColor, Theme.opacityMedium) : Theme.glassBorderColor
  border.width: Theme.borderWidthThin
  color: card.checked && card.active ? Theme.activeSubtle : Theme.glassContentColor
  opacity: card.active ? 1.0 : Theme.opacityDisabled
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
    cursorShape: card.active ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: card.active

    onClicked: card.toggled(!card.checked)
  }
  GridLayout {
    anchors.left: parent.left
    anchors.leftMargin: Theme.spacingMd
    anchors.right: parent.right
    anchors.rightMargin: Theme.spacingMd
    anchors.verticalCenter: parent.verticalCenter
    columnSpacing: Theme.spacingSm
    columns: card.wide ? 2 : 1
    rowSpacing: Theme.spacingXs

    Item {
      Layout.column: 0
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredHeight: Theme.iconSizeMd
      Layout.preferredWidth: Theme.iconSizeMd
      Layout.row: 0

      Text {
        anchors.centerIn: parent
        color: card.labelColor
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSizeMd
        text: card.icon
        visible: !card.spinning

        Behavior on color {
          ColorAnimation {
            duration: Theme.animationDuration
          }
        }
      }
      OSpinner {
        anchors.centerIn: parent
        color: card.labelColor
        running: card.spinning
        spinnerSize: Theme.iconSizeMd
      }
    }
    OText {
      Layout.column: 0
      Layout.alignment: Qt.AlignHCenter
      Layout.row: 1
      bold: card.checked
      color: card.labelColor
      size: "xs"
      text: card.label

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }
    OText {
      Layout.alignment: card.wide ? Qt.AlignVCenter : Qt.AlignHCenter
      Layout.column: card.wide ? 1 : 0
      Layout.fillWidth: card.wide
      Layout.maximumWidth: card.width - Theme.spacingMd * 2
      Layout.row: card.wide ? 0 : 2
      Layout.rowSpan: card.wide ? 2 : 1
      color: card.detailColor
      elide: Text.ElideRight
      size: "xs"
      text: card.detail
      visible: card.detail !== ""

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }
  }
}
