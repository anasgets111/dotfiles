import QtQuick
import qs.Config
import qs.Widgets
import qs.Services.SystemInfo

Item {
  id: root

  readonly property color baseColor: isRecording ? (isPaused ? Theme.inactiveColor : Theme.activeColor) : Theme.inactiveColor
  property string iconIdle: "󰞡"
  property string iconPaused: "󰏧"
  property string iconRecording: ""
  readonly property bool isPaused: ScreenRecordingService.isPaused
  readonly property bool isRecording: ScreenRecordingService.isRecording
  readonly property string tipText: isRecording ? (isPaused ? qsTr("Right-click to resume, left to stop") : qsTr("Right-click to pause, left to stop")) : qsTr("Left-click to start recording")

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth

  IconButton {
    id: button

    anchors.fill: parent
    bgColor: root.baseColor
    disabledBgColor: Theme.inactiveColor
    hoverBgColor: Theme.onHoverColor
    iconFont: Qt.font({
      family: Theme.fontFamily,
      pixelSize: Theme.fontSize,
      bold: root.isRecording
    })
    iconText: root.isRecording ? (root.isPaused ? root.iconPaused : root.iconRecording) : root.iconIdle
    implicitHeight: Theme.itemHeight
    implicitWidth: Theme.itemWidth

    onLeftClicked: ScreenRecordingService.toggleRecording()
    onRightClicked: if (root.isRecording)
      ScreenRecordingService.togglePause()
  }
  Tooltip {
    edge: Qt.BottomEdge
    hoverSource: button.area
    target: button
    text: root.tipText
  }
}
