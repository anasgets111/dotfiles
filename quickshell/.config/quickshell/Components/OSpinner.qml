pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Item {
  id: root

  property color color: Theme.activeColor
  property bool running: true
  property int spinnerSize: Theme.spinnerSize

  implicitHeight: spinnerSize
  implicitWidth: spinnerSize
  visible: running

  Text {
    anchors.centerIn: parent
    color: root.color
    font.family: Theme.iconFontFamily
    font.pixelSize: Math.min(root.width, root.height)
    text: "󰑐"

    RotationAnimation on rotation {
      duration: Theme.spinnerDuration
      from: 0
      loops: Animation.Infinite
      running: root.running && root.visible
      to: 360
    }
  }
}
