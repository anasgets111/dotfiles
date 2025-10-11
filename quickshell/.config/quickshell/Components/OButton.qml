import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.Config

/**
 * OButton - Obelisk themed button component
 *
 * A clickable button with hover states, icons, and text.
 * Uses Theme for all styling with smooth transitions.
 *
 * Supports two modes:
 * 1. Simple mode: Set text/icon properties
 * 2. Custom content mode: Add children directly (text/icon ignored)
 */
Rectangle {
  id: root

  property string text: ""
  property string icon: ""
  property color bgColor: Theme.activeColor
  property color hoverColor: Qt.lighter(bgColor, 1.2)
  readonly property color currentBackground: !isEnabled ? Theme.disabledColor : (hovered ? hoverColor : bgColor)
  property color textColor: Theme.textContrast(currentBackground)
  property bool isEnabled: true
  property alias hovered: mouseArea.containsMouse
  // Content container for custom children
  default property alias content: contentContainer.data

  signal clicked

  implicitWidth: simpleContent.visible ? simpleContent.implicitWidth + 16 : contentContainer.implicitWidth
  implicitHeight: Theme.itemHeight
  color: currentBackground
  radius: Theme.itemRadius
  opacity: isEnabled ? 1 : 0.5

  // Simple mode: text/icon layout
  RowLayout {
    id: simpleContent

    anchors.centerIn: parent
    spacing: 8
    visible: root.text !== "" || root.icon !== ""

    OText {
      visible: root.icon !== ""
      text: root.icon
      color: root.textColor
    }

    OText {
      visible: root.text !== ""
      text: root.text
      font.bold: true
      color: root.textColor
    }
  }

  // Custom content mode
  Item {
    id: contentContainer

    anchors.fill: parent
    visible: !simpleContent.visible
  }

  MouseArea {
    id: mouseArea

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: root.isEnabled
    onClicked: root.clicked()
  }

  Behavior on color {
    ColorAnimation {
      duration: Theme.animationDuration
    }
  }
}
