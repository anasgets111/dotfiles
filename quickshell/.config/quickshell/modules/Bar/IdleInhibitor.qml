import QtQuick
import Quickshell.Io

Rectangle {
  id: idleInhibitor

  readonly property color bgColor: hovered ? Theme.onHoverColor : (isActive ? Theme.activeColor : Theme.inactiveColor)
  property bool enabled: false
  readonly property color fgColor: Theme.textContrast(bgColor)
  readonly property string glyph: isActive ? iconOn : iconOff
  property bool hovered: false
  property string iconOff: "󰾪"
  property string iconOn: "󰅶"
  readonly property bool isActive: process.running

  color: bgColor
  height: Theme.itemHeight
  radius: Theme.itemRadius
  width: Theme.itemWidth

  Process {
    id: process

    command: ["sh", "-c", "systemd-inhibit --what=idle --who=Caffeine " + "--why='Caffeine module is active' --mode=block sleep inf"]
    running: idleInhibitor.enabled
  }
  MouseArea {
    acceptedButtons: Qt.LeftButton
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: enabled = !enabled
    onEntered: idleInhibitor.hovered = true
    onExited: idleInhibitor.hovered = false
  }
  Text {
    anchors.centerIn: parent
    color: idleInhibitor.fgColor
    font.bold: true
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: idleInhibitor.glyph
  }
}
