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

  signal clicked
  signal toggled(bool checked)

  border.color: Theme.textActiveColor
  border.width: 2
  color: "transparent"
  implicitHeight: size
  implicitWidth: size
  radius: Theme.radiusXs

  Behavior on border.color {
    ColorAnimation {
      duration: Theme.animationDuration
    }
  }

  Rectangle {
    anchors.centerIn: parent
    color: Theme.activeColor
    height: parent.height * 0.6
    radius: Theme.radiusXs
    scale: root.checked ? 1 : 0
    visible: root.checked
    width: parent.width * 0.6

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
}
