pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Rectangle {
  id: btn

  property string icon: ""
  property color tint: Theme.textActiveColor

  signal clicked

  color: ma.containsMouse ? Qt.rgba(tint.r, tint.g, tint.b, 0.15) : "transparent"
  implicitHeight: 30
  implicitWidth: 30
  radius: 8

  Behavior on color {
    ColorAnimation {
      duration: 120
    }
  }

  Text {
    anchors.centerIn: parent
    color: btn.tint
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    opacity: ma.containsMouse ? 1.0 : 0.5
    text: btn.icon
  }

  MouseArea {
    id: ma

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: btn.clicked()
  }
}
