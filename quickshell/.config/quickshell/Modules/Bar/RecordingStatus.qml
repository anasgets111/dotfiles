import QtQuick
import QtQuick.Controls
import qs.Config
import qs.Services.SystemInfo

Item {
  id: root

  property bool hovered: false

  // Nerd Font icons (override if your font differs)
  // idle: nf-oct-primitive_dot, recording: nf-fa-circle (red expected), paused: nf-fa-pause, stopped: nf-fa-stop
  property string iconIdle: "󰞡"
  property string iconPaused: "󰏧"
  property string iconRecording: ""
  property bool isPaused: ScreenRecordingService.isPaused
  // Bind to ScreenRecordingService singleton
  property bool isRecording: ScreenRecordingService.isRecording
  // Optional override label
  property string statusText: ""

  ToolTip.delay: 300
  ToolTip.text: isRecording ? (isPaused ? "Right-click to resume, left to stop" : "Right-click to pause, left to stop") : "Left-click to start recording"
  // Optional hover hint
  ToolTip.visible: hovered
  height: Theme.itemHeight
  width: Theme.itemWidth

  MouseArea {
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) {
        ScreenRecordingService.toggleRecording();
      } else if (mouse.button === Qt.RightButton) {
        // Only toggles pause if currently recording
        if (root.isRecording)
          ScreenRecordingService.togglePause();
      }
    }
    onEntered: root.hovered = true
    onExited: root.hovered = false
  }
  Rectangle {
    anchors.fill: parent
    border.color: Theme.borderColor
    border.width: 1
    color: root.isRecording ? (root.isPaused ? Theme.inactiveColor : Theme.activeColor) : (root.hovered ? Theme.onHoverColor : Theme.inactiveColor)
    radius: Theme.itemRadius

    Text {
      anchors.centerIn: parent
      color: Theme.textContrast(root.isRecording ? (root.isPaused ? Theme.inactiveColor : Theme.activeColor) : (root.hovered ? Theme.onHoverColor : Theme.inactiveColor))
      font.bold: root.isRecording
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      text: root.isRecording ? (root.isPaused ? root.iconPaused : root.iconRecording) : root.iconIdle
    }
  }
}
