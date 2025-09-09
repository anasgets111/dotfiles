import QtQuick
import qs.Config
import qs.Components
import qs.Services.SystemInfo

Item {
  id: root

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth

  IconButton {
    id: button

    anchors.fill: parent
    bgColor: ScreenRecordingService.isRecording ? (ScreenRecordingService.isPaused ? Theme.inactiveColor : Theme.activeColor) : Theme.inactiveColor
    iconText: ScreenRecordingService.isRecording ? (ScreenRecordingService.isPaused ? "󰏧" : "") : "󰞡"

    onLeftClicked: ScreenRecordingService.toggleRecording()
    onRightClicked: if (ScreenRecordingService.isRecording)
      ScreenRecordingService.togglePause()
  }
  Tooltip {
    hAlign: Qt.AlignCenter
    hoverSource: button.area
    target: button
    text: ScreenRecordingService.isRecording ? (ScreenRecordingService.isPaused ? qsTr("Right-click to resume, left to stop") : qsTr("Right-click to pause, left to stop")) : qsTr("Left-click to start recording")
  }
}
