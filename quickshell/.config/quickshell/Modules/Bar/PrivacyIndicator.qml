pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Core
import qs.Components

RowLayout {
  id: pIndic

  spacing: 8

  readonly property var activeIndicators: [(PrivacyService.microphoneActive || PrivacyService.microphoneMuted) && {
      icon: PrivacyService.microphoneMuted ? "\uF131" : "\uF130",
      tooltip: PrivacyService.microphoneMuted ? qsTr("Microphone muted") : qsTr("Microphone in use"),
      color: PrivacyService.microphoneMuted ? Theme.warning : Theme.critical,
      onClick: AudioService && AudioService.source && AudioService.source.audio ? function () {
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
        colorBg: cell.indicator.color ?? Theme.critical
        anchors.fill: parent
        icon: cell.indicator.icon
        tooltipText: cell.indicator.tooltip
        enabled: typeof cell.indicator.onClick === "function"
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
