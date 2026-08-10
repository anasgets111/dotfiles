pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config

Rectangle {
  id: card

  property bool active: true
  property bool checked: false
  property string detail: ""
  readonly property color detailColor: (checked || hovered) && active ? Theme.textActiveColor : Theme.textInactiveColor
  readonly property bool hovered: cardMouse.containsMouse && active
  required property string icon
  required property string label
  readonly property color labelColor: checked && active ? Theme.activeColor : hovered ? Theme.textActiveColor : Theme.textInactiveColor
  property bool spinning: false
  readonly property bool wide: !(width < Theme.panelToggleCompactThreshold) && detail !== ""

  signal toggled(bool checked)

  Layout.fillWidth: true
  Layout.preferredHeight: Theme.panelToggleCardHeight
  Layout.preferredWidth: 0
  border.color: card.checked && card.active ? Theme.withOpacity(Theme.activeColor, Theme.opacityMedium) : card.hovered ? Theme.glassBorderHoverColor : Theme.glassBorderColor
  border.width: Theme.borderWidthThin
  color: card.checked && card.active ? (card.hovered ? Theme.activeLight : Theme.activeSubtle) : card.hovered ? Theme.glassContentHoverColor : Theme.glassContentColor
  opacity: card.active ? 1.0 : Theme.opacityDisabled
  radius: Theme.radiusLg

  Theme.ColorTransition on border.color {
  }
  Theme.ColorTransition on color {
  }
  Theme.NumberTransition on opacity {
  }

  MouseArea {
    id: cardMouse

    anchors.fill: parent
    cursorShape: card.active ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: card.active
    hoverEnabled: true

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
      Layout.alignment: Qt.AlignHCenter
      Layout.column: 0
      Layout.preferredHeight: Theme.iconSizeMd
      Layout.preferredWidth: Theme.iconSizeMd
      Layout.row: 0
      visible: card.icon !== "" || card.spinning

      Text {
        anchors.centerIn: parent
        color: card.labelColor
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSizeMd
        text: card.icon
        visible: !card.spinning

        Theme.ColorTransition on color {
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
      Layout.alignment: Qt.AlignHCenter
      Layout.column: 0
      Layout.row: 1
      bold: card.checked
      color: card.labelColor
      size: "xs"
      text: card.label

      Theme.ColorTransition on color {
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
      size: "xs"
      text: card.detail
      visible: card.detail !== ""

      Theme.ColorTransition on color {
      }
    }
  }
}
