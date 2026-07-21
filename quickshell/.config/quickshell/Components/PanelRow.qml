pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config

Rectangle {
  id: root

  property alias actions: actionSlot.data
  property alias badges: badgeSlot.data
  property bool busy: false
  property bool expanded: false
  property alias expandedContent: expandedSlot.data
  property string icon: ""
  property alias leading: leadingSlot.data
  property bool rowActionEnabled: true
  property bool selected: false
  property string subtitle: ""
  property string title: ""

  signal clicked
  signal pointerMoved(point position)

  readonly property bool actionable: enabled && !busy && rowActionEnabled
  readonly property bool hovered: rowMouse.containsMouse && actionable

  border.color: selected ? Theme.activeColor : activeFocus ? Theme.activeColor : "transparent"
  border.width: Theme.borderWidthThin
  color: selected ? Theme.activeSubtle : hovered ? Theme.bgCardHover : "transparent"
  implicitHeight: rowLayout.implicitHeight + (expanded ? expandedSlot.implicitHeight + Theme.spacingSm : 0) + Theme.spacingXs * 2
  opacity: enabled ? 1 : Theme.opacityDisabled
  radius: Theme.radiusMd

  Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
  Behavior on implicitHeight { NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutCubic } }

  MouseArea {
    id: rowMouse

    anchors.fill: parent
    cursorShape: root.actionable ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: root.actionable
    hoverEnabled: true
    onClicked: root.clicked()
    onPositionChanged: mouse => root.pointerMoved(Qt.point(mouse.x, mouse.y))
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.leftMargin: Theme.spacingSm
    anchors.rightMargin: Theme.spacingSm
    anchors.topMargin: Theme.spacingXs
    spacing: Theme.spacingSm

    RowLayout {
      id: rowLayout

      Layout.fillWidth: true
      spacing: Theme.spacingSm

      Item {
        id: leadingSlot

        Layout.preferredHeight: Math.max(Theme.iconSizeMd, childrenRect.height)
        Layout.preferredWidth: Math.max(Theme.iconSizeMd, childrenRect.width)
        visible: children.length > 1 || root.icon !== ""

        OText {
          anchors.centerIn: parent
          color: root.selected ? Theme.activeColor : Theme.textActiveColor
          font.family: Theme.iconFontFamily
          font.pixelSize: Theme.iconSizeMd
          text: root.icon
          visible: leadingSlot.children.length === 1 && root.icon !== ""
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        OText {
          Layout.fillWidth: true
          bold: root.selected
          color: root.selected ? Theme.activeColor : Theme.textActiveColor
          elide: Text.ElideRight
          text: root.title
        }
        OText {
          Layout.fillWidth: true
          color: Theme.textInactiveColor
          elide: Text.ElideRight
          size: "xs"
          text: root.subtitle
          visible: text !== ""
        }
      }
      Item {
        Layout.preferredHeight: Math.max(Theme.spinnerSize, actionSlot.implicitHeight)
        Layout.preferredWidth: Math.max(Theme.spinnerSize, actionSlot.implicitWidth)
        visible: root.busy || actionSlot.children.length > 0

        RowLayout {
          id: actionSlot

          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          enabled: root.enabled && !root.busy
          opacity: root.busy ? 0 : 1
          spacing: Theme.spacingXs
        }
        OSpinner {
          anchors.centerIn: parent
          running: root.busy
        }
      }
      RowLayout {
        id: badgeSlot
        spacing: Theme.spacingXs
      }
    }
    Item {
      id: expandedSlot

      Layout.fillWidth: true
      Layout.preferredHeight: root.expanded ? implicitHeight : 0
      clip: true
      implicitHeight: childrenRect.height
      opacity: root.expanded ? 1 : 0
      visible: opacity > 0

      Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }
    }
  }
}
