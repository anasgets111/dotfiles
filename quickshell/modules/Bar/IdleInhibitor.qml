import QtQuick
import Quickshell
import Quickshell.Io
import "."

Rectangle {
  id: idleInhibitor
  width: Theme.itemWidth
  height: Theme.itemHeight
  radius: Theme.itemRadius

  /* style constants */
  property string iconOn:  ""
  property string iconOff: ""

  /* bind state directly to process.running */
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

  /* lock screen process */
  Process { id: lockProcess; command: ["hyprlock"] }

  /* dynamic styling */
  property bool hovered: false
  color: hovered
    ? Theme.onHoverColor
    : (isActive ? Theme.activeColor : Theme.inactiveColor)


  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) {
        inhibitorProcess.running = !inhibitorProcess.running
      } else if (mouse.button === Qt.RightButton) {
        lockProcess.running = true
      }
    }
    hoverEnabled: true
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
