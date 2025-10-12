pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
  id: flash

  property int fadeMs: 200
  property color flashColor: "#ffe066"
  property int growMs: 600

  function start() {
    // reset
    flash.opacity = 0;
    flash.width = 2;
    flash.x = (parent.width / 2) - 1;
    // animate
    flash.opacity = 1;
    flashAnim.restart();
  }

  anchors.verticalCenter: parent ? parent.verticalCenter : undefined
  color: flashColor
  height: parent ? parent.height : 0
  opacity: 0
  radius: height / 2
  width: 2
  x: (parent ? parent.width : width) / 2 - width / 2

  SequentialAnimation {
    id: flashAnim

    ParallelAnimation {
      NumberAnimation {
        duration: flash.growMs
        easing.type: Easing.OutCubic
        from: 2
        property: "width"
        target: flash
        to: flash.parent ? flash.parent.width : 2
      }

      NumberAnimation {
        duration: flash.growMs
        easing.type: Easing.OutCubic
        from: (flash.parent ? flash.parent.width : 0) / 2 - 1
        property: "x"
        target: flash
        to: 0
      }
    }

    NumberAnimation {
      duration: flash.fadeMs
      easing.type: Easing.OutCubic
      from: 1
      property: "opacity"
      target: flash
      to: 0
    }
  }
}
