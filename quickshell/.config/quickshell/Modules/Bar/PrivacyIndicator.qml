pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Core
import qs.Components

RowLayout {
  id: pIndic

  readonly property var activeIndicators: [(PrivacyService.microphoneActive || PrivacyService.microphoneMuted) && {
      icon: PrivacyService.microphoneMuted ? "\uF131" : "\uF130",
      tooltip: PrivacyService.microphoneMuted ? qsTr("Microphone muted") : qsTr("Microphone in use"),
      color: PrivacyService.microphoneMuted ? Theme.warning : Theme.critical,
      onClick: AudioService?.source?.audio ? function () {
        AudioService.toggleMicMute();
      } : null
    }, PrivacyService.cameraActive && {
      icon: "\uF030",
      tooltip: qsTr("Camera in use"),
      color: Theme.critical
    }, PrivacyService.screensharingActive && {
      icon: "\uF108",
      tooltip: qsTr("Screen sharing in progress"),
      color: Theme.critical
    }].filter(Boolean)

  spacing: 8

  Component {
    id: pDelegate

    Item {
      id: cell

      readonly property var indicator: cell.modelData
      required property var modelData

      Layout.alignment: Qt.AlignVCenter
      Layout.preferredHeight: implicitHeight
      Layout.preferredWidth: implicitWidth
      implicitHeight: Theme.itemHeight
      implicitWidth: Theme.itemHeight

      IconButton {
        id: button

        anchors.fill: parent
        colorBg: cell.indicator.color ?? Theme.critical
        enabled: true
        icon: cell.indicator.icon
        tooltipText: cell.indicator.tooltip

        onClicked: {
          if (typeof cell.indicator.onClick === "function")
            cell.indicator.onClick();
        }
      }
    }
  }

  Repeater {
    delegate: pDelegate
    model: pIndic.activeIndicators
  }
}
