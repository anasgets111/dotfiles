// PulseFlash.qml
pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Rectangle {
  id: flash

  property color flashColor: "#ffe066"
  property int growMs: 600
  property int fadeMs: 200

  color: flashColor
  radius: height / 2
  opacity: 0
  width: 2
  x: (parent ? parent.width : width) / 2 - width / 2
  anchors.verticalCenter: parent ? parent.verticalCenter : undefined
  height: parent ? parent.height : 0

  function start() {
    // reset
    flash.opacity = 0;
    flash.width = 2;
    flash.x = (parent.width / 2) - 1;
    // animate
    flash.opacity = 1;
    flashAnim.restart();
  }

  SequentialAnimation {
    id: flashAnim

    ParallelAnimation {
      NumberAnimation {
        target: flash
        property: "width"
        from: 2
        to: flash.parent ? flash.parent.width : 2
        duration: flash.growMs
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        target: flash
        property: "x"
        from: (flash.parent ? flash.parent.width : 0) / 2 - 1
        to: 0
        duration: flash.growMs
        easing.type: Easing.OutCubic
      }
    }
    NumberAnimation {
      target: flash
      property: "opacity"
      from: 1
      to: 0
      duration: flash.fadeMs
      easing.type: Easing.OutCubic
    }
  }
}
