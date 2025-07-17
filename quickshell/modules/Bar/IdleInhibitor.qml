import QtQuick
import Quickshell
import Quickshell.Io
import "."

Rectangle {
  id: idleInhibitor
  width: Theme.itemWidth
  height: Theme.itemHeight
  radius: Theme.itemRadius

  property string iconOn:  ""
  property string iconOff: ""
  property bool hovered: false

  Process {
    id: inhibitorProcess
    command: [
      "systemd-inhibit",
      "--what=idle",
      "--who=quickshell",
      "--why=User inhibited idle",
      "sleep", "infinity"
    ]
  }
  property alias isActive: inhibitorProcess.running

  Process {
    id: lockProcess
    command: ["hyprlock"]
  }

  color: hovered
    ? Theme.onHoverColor
    : (isActive ? Theme.activeColor : Theme.inactiveColor)

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) {
        inhibitorProcess.running = !inhibitorProcess.running
      } else if (mouse.button === Qt.RightButton) {
        lockProcess.running = true
      }
    }
    onEntered: idleInhibitor.hovered = true
    onExited: idleInhibitor.hovered = false
  }

  Text {
    anchors.centerIn: parent
    text: isActive ? iconOn : iconOff
    color: hovered
      ? Theme.textOnHoverColor
      : (isActive ? Theme.textActiveColor : Theme.textInactiveColor)
    font.pixelSize: Theme.fontSize
    font.bold : true
    font.family: Theme.fontFamily
  }
}
