pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config

Rectangle {
  id: root

  default property alias content: contentSlot.data
  property int padding: Theme.cardPadding
  property string tone: "standard"
  readonly property color toneColor: tone === "active" ? Theme.activeColor : tone === "warning" ? Theme.warning : tone === "error" ? Theme.critical : Theme.borderColor

  border.color: tone === "standard" ? Theme.glassBorderColor : Theme.withOpacity(toneColor, Theme.opacityMedium)
  border.width: Theme.borderWidthThin
  color: tone === "active" ? Theme.activeSubtle : tone === "warning" || tone === "error" ? Theme.withOpacity(toneColor, Theme.opacitySubtle) : Theme.glassContentColor
  implicitHeight: Layout.fillHeight ? 0 : contentSlot.childrenRect.height + padding * 2
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

  Item {
    id: contentSlot

    anchors.fill: parent
    anchors.margins: root.padding
  }
}
