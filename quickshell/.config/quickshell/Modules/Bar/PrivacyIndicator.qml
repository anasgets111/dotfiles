pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.SystemInfo
import qs.Components

RowLayout {
  id: pIndic

  spacing: 8

  readonly property var activeIndicators: [PrivacyService.microphoneActive && {
      icon: "\uF130",
      tooltip: qsTr("Microphone in use")
    }, PrivacyService.cameraActive && {
      icon: "\uF030",
      tooltip: qsTr("Camera in use")
    }, PrivacyService.screensharingActive && {
      icon: "\uF108",
      tooltip: qsTr("Screen sharing in progress")
    }].filter(Boolean)

  Component {
    id: pDelegate

    Item {
      id: cell

      required property var modelData
      readonly property var indicator: cell.modelData

      Layout.alignment: Qt.AlignVCenter
      Layout.preferredHeight: implicitHeight
      Layout.preferredWidth: implicitWidth
      implicitHeight: Theme.itemHeight
      implicitWidth: Theme.itemHeight

      IconButton {
        id: button
        colorBg: Theme.critical
        anchors.fill: parent
        icon: cell.indicator.icon
        tooltipText: cell.indicator.tooltip
        onClicked: {}
      }
    }
  }
  Repeater {
    delegate: pDelegate
    model: pIndic.activeIndicators
  }
}
