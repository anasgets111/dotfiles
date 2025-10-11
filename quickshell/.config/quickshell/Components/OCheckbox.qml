import QtQuick
import qs.Config

/**
 * OCheckbox - Obelisk themed checkbox component
 *
 * A simple checkbox with border and fill indicator.
 * Uses Theme for consistent styling.
 */
Rectangle {
  id: root

  property bool checked: false
  property real size: Theme.itemHeight * 0.6

  signal toggled(bool checked)
  signal clicked

  implicitWidth: size
  implicitHeight: size
  color: "transparent"
  border.color: Theme.textActiveColor
  border.width: 2
  radius: 4

  Rectangle {
    anchors.centerIn: parent
    width: parent.width * 0.6
    height: parent.height * 0.6
    color: Theme.activeColor
    radius: 2
    visible: root.checked
    scale: root.checked ? 1 : 0

    Behavior on scale {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.OutBack
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      root.checked = !root.checked;
      root.toggled(root.checked);
      root.clicked();
    }
  }

  Behavior on border.color {
    ColorAnimation {
      duration: Theme.animationDuration
    }
  }
}
