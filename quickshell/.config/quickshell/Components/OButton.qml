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

  property color bgColor: Theme.activeColor
  // Content container for custom children
  default property alias content: contentContainer.data
  readonly property color currentBackground: !isEnabled ? Theme.disabledColor : (hovered ? hoverColor : bgColor)
  property color hoverColor: Qt.lighter(bgColor, 1.2)
  property alias hovered: mouseArea.containsMouse
  property string icon: ""
  property bool isEnabled: true
  property string text: ""
  property color textColor: Theme.textContrast(currentBackground)

  signal clicked

  color: currentBackground
  implicitHeight: Theme.itemHeight
  implicitWidth: simpleContent.visible ? simpleContent.implicitWidth + 16 : contentContainer.implicitWidth
  opacity: isEnabled ? 1 : 0.5
  radius: Theme.itemRadius

  Behavior on color {
    ColorAnimation {
      duration: Theme.animationDuration
    }
  }

  // Simple mode: text/icon layout
  RowLayout {
    id: simpleContent

    anchors.centerIn: parent
    spacing: 8
    visible: root.text !== "" || root.icon !== ""

    OText {
      color: root.textColor
      text: root.icon
      visible: root.icon !== ""
    }

    OText {
      color: root.textColor
      font.bold: true
      text: root.text
      visible: root.text !== ""
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
    cursorShape: root.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: root.isEnabled
    hoverEnabled: true

    onClicked: root.clicked()
  }
}
