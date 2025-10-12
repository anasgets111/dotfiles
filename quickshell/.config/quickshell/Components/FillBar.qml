pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Config

Item {
  id: bar

  property int animMs: Theme.animationDuration
  property color fillColor: Theme.activeColor
  property real progress: 0      // 0..1
  property real radius: Theme.itemRadius

  anchors.fill: parent
  clip: false

  ClippingRectangle {
    anchors.fill: parent
    color: "transparent"
    radius: bar.radius

    Rectangle {
      color: bar.fillColor
      width: parent.width * Math.max(0, Math.min(1, bar.progress))

      Behavior on width {
        NumberAnimation {
          duration: bar.animMs
          easing.type: Easing.InOutQuad
        }
      }

      anchors {
        bottom: parent.bottom
        left: parent.left
        top: parent.top
      }
    }
  }
}
