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
    colorBg: ScreenRecordingService.isRecording ? (ScreenRecordingService.isPaused ? Theme.inactiveColor : Theme.activeColor) : Theme.inactiveColor
    icon: ScreenRecordingService.isRecording ? (ScreenRecordingService.isPaused ? "󰏧" : "") : "󰞡"
    tooltipText: ScreenRecordingService.isRecording ? (ScreenRecordingService.isPaused ? qsTr("Right-click to resume, left to stop") : qsTr("Right-click to pause, left to stop")) : qsTr("Left-click to start recording")

    onClicked: point => {
      switch (point.button) {
      case Qt.RightButton:
        if (ScreenRecordingService.isRecording)
          ScreenRecordingService.togglePause();
        return;
      case Qt.LeftButton:
        ScreenRecordingService.toggleRecording();
        return;
      default:
        return;
      }
    }
  }
}
