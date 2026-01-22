pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Core
import qs.Components

RowLayout {
  id: root

  spacing: Theme.spacingSm

  IconButton {
    Layout.preferredHeight: Theme.itemHeight
    Layout.preferredWidth: Theme.itemHeight
    colorBg: PrivacyService.microphoneMuted ? Theme.warning : Theme.critical
    enabled: true
    icon: PrivacyService.microphoneMuted ? "\uF131" : "\uF130"
    tooltipText: PrivacyService.microphoneMuted ? qsTr("Microphone muted") : qsTr("Microphone in use")
    visible: PrivacyService.microphoneActive || PrivacyService.microphoneMuted

    onClicked: AudioService?.source?.audio && AudioService.toggleMicMute()
  }

  IconButton {
    Layout.preferredHeight: Theme.itemHeight
    Layout.preferredWidth: Theme.itemHeight
    colorBg: Theme.critical
    enabled: true
    icon: "\uF030"
    tooltipText: qsTr("Camera in use")
    visible: PrivacyService.cameraActive
  }

  IconButton {
    Layout.preferredHeight: Theme.itemHeight
    Layout.preferredWidth: Theme.itemHeight
    colorBg: Theme.critical
    enabled: true
    icon: "\uF108"
    tooltipText: qsTr("Screen sharing in progress")
    visible: PrivacyService.screenshareActive
  }
}
