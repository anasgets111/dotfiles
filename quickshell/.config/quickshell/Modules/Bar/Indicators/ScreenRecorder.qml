import QtQuick
import qs.Components
import qs.Config
import qs.Services.SystemInfo

Item {
  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth

  IconButton {
    anchors.fill: parent
    colorBg: ScreenRecordingService.isRecording ? (ScreenRecordingService.isPaused ? Theme.inactiveColor : Theme.activeColor) : Theme.inactiveColor
    icon: ScreenRecordingService.isRecording ? (ScreenRecordingService.isPaused ? "󰏧" : "") : "󰞡"
    tooltipText: ScreenRecordingService.isRecording ? (ScreenRecordingService.isPaused ? qsTr("Right-click to resume, left to stop") : qsTr("Right-click to pause, left to stop")) : qsTr("Left-click for region, middle-click for current output")

    onClicked: point => {
      switch (point.button) {
      case Qt.RightButton:
        if (ScreenRecordingService.isRecording)
          ScreenRecordingService.togglePause();

        return;
      case Qt.LeftButton:
        ScreenRecordingService.isRecording ? ScreenRecordingService.stopRecording() : ScreenRecordingService.startRecording("selection");
        return;
      case Qt.MiddleButton:
        if (!ScreenRecordingService.isRecording)
          ScreenRecordingService.startRecording();

        return;
      default:
        return;
      }
    }
  }
}
