import QtQuick
import qs.Components
import qs.Config
import qs.Services.SystemInfo
import qs.Services.UI

Item {
  id: root

  readonly property bool panelOpen: ShellUiState.isPanelOpen("screenRecorder", root.screenName)
  required property string screenName

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth

  IconButton {
    id: iconButton

    anchors.fill: parent
    colorBg: ScreenRecordingService.isRecording ? (ScreenRecordingService.isPaused ? Theme.glassControlColor : Theme.activeColor) : Theme.glassControlColor
    icon: ScreenRecordingService.isRecording ? (ScreenRecordingService.isPaused ? "󰏧" : "󰓛") : "󰞡"
    selected: root.panelOpen
    suppressTooltip: root.panelOpen
    tooltipText: ScreenRecordingService.isRecording ? qsTr("Left-click to stop, right-click for options") : qsTr("Left-click for region, middle-click for current output, right-click for options")

    onClicked: point => {
      switch (point.button) {
      case Qt.RightButton:
        ShellUiState.togglePanelForItem("screenRecorder", root.screenName, iconButton);
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
