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
    icon: PrivacyService.microphoneMuted ? "\uF131" : "\uF130"
    isEnabled: AudioService.sourceControllable
    tooltipText: PrivacyService.microphoneMuted ? qsTr("Microphone muted") : qsTr("Microphone in use")
    visible: PrivacyService.microphoneActive || PrivacyService.microphoneMuted

    onClicked: AudioService.toggleMicMute()
  }

  IconButton {
    Layout.preferredHeight: Theme.itemHeight
    Layout.preferredWidth: Theme.itemHeight
    colorBg: Theme.critical
    icon: "\uF030"
    isEnabled: true
    tooltipText: qsTr("Camera in use")
    visible: PrivacyService.cameraActive
  }

  IconButton {
    Layout.preferredHeight: Theme.itemHeight
    Layout.preferredWidth: Theme.itemHeight
    colorBg: Theme.critical
    icon: "\uF108"
    isEnabled: true
    tooltipText: qsTr("Screen sharing in progress")
    visible: PrivacyService.screenshareActive
  }
}
