pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Utils

PanelContentBase {
  id: root

  readonly property var config: Settings.data?.screenRecorder
  readonly property bool paused: ScreenRecordingService.isPaused
  readonly property bool recording: ScreenRecordingService.isRecording
  readonly property string saveDirectory: ScreenRecordingService.directory.replace(Quickshell.env("HOME"), "~")
  readonly property string statusText: root.recording ? [root.paused ? qsTr("Paused") : qsTr("Recording"), ScreenRecordingService.elapsedText, ScreenRecordingService.captureLabel].filter(Boolean).join(" · ") : qsTr("Ready · %1").arg(ScreenRecordingService.monitor || qsTr("no output"))

  function beginRecording(mode: string): void {
    root.closeRequested();
    ScreenRecordingService.startRecording(mode);
  }

  flatContainer: true
  preferredHeight: contentLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: Theme.panelDefaultWidth

  ColumnLayout {
    id: contentLayout

    anchors.left: parent.left
    anchors.margins: Theme.spacingMd
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Theme.spacingMd

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingSm

      Rectangle {
        Layout.preferredHeight: Theme.controlHeightLg
        Layout.preferredWidth: Theme.controlHeightLg
        color: root.recording ? Theme.withOpacity(Theme.critical, Theme.opacitySubtle) : Theme.activeSubtle
        radius: Theme.radiusMd

        OText {
          anchors.centerIn: parent
          color: root.recording ? Theme.critical : Theme.activeColor
          size: "lg"
          text: "󰑊"
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        OText {
          bold: true
          color: Theme.textActiveColor
          size: "lg"
          text: qsTr("Screen Recorder")
        }
        OText {
          Layout.fillWidth: true
          color: Theme.textInactiveColor
          elide: Text.ElideRight
          size: "xs"
          text: root.statusText
        }
      }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingSm

      OButton {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.controlHeightXl
        bgColor: root.recording ? Theme.critical : Theme.activeColor
        icon: root.recording ? "󰓛" : "󰆞"
        isEnabled: !ScreenRecordingService.starting
        text: root.recording ? qsTr("Stop") : qsTr("Region")

        onClicked: root.recording ? ScreenRecordingService.stopRecording() : root.beginRecording("selection")
      }
      OButton {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.controlHeightXl
        icon: !root.recording ? "󰍹" : root.paused ? "󰐊" : "󰏤"
        isEnabled: !ScreenRecordingService.starting
        text: !root.recording ? qsTr("Screen") : root.paused ? qsTr("Resume") : qsTr("Pause")
        variant: root.recording ? "secondary" : "primary"

        onClicked: root.recording ? ScreenRecordingService.togglePause() : root.beginRecording("screen")
      }
    }
    Rectangle {
      Layout.fillWidth: true
      color: Theme.borderSubtle
      implicitHeight: Theme.borderWidthThin
    }
    OptionGroup {
      options: [{
          value: "off",
          label: qsTr("Off"),
          icon: "󰝟"
        }, {
          value: "desktop",
          label: qsTr("Desktop"),
          icon: "󰕾"
        }, {
          value: "mic",
          label: qsTr("Desktop + Mic"),
          icon: "󰍬"
        }]
      selected: root.config?.audio ?? "desktop"
      title: qsTr("Audio")

      onPicked: value => root.config.audio = value
    }
    OptionGroup {
      options: [{
          value: "low",
          label: qsTr("Low"),
          icon: "󰾆",
          detail: qsTr("Smallest files, softest detail in motion")
        }, {
          value: "medium",
          label: qsTr("Medium"),
          icon: "󰾅",
          detail: qsTr("Balanced size and detail")
        }, {
          value: "high",
          label: qsTr("High"),
          icon: "󰓅",
          detail: qsTr("Sharpest detail, largest files")
        }]
      selected: root.config?.quality ?? "high"
      title: qsTr("Quality")

      onPicked: value => root.config.quality = value
    }
    OptionGroup {
      options: [30, 60, 120].map(rate => ({
            value: rate,
            label: qsTr("%1 FPS").arg(rate)
          }))
      selected: root.config?.fps ?? 60
      title: qsTr("Frame rate")

      onPicked: value => root.config.fps = value
    }
    OptionGroup {
      options: [{
          value: "mp4",
          label: qsTr("MP4"),
          icon: "󰈫",
          detail: qsTr("Plays and uploads anywhere")
        }, {
          value: "mkv",
          label: qsTr("MKV"),
          icon: "󰿎",
          detail: qsTr("Stays playable if the session crashes mid-recording")
        }]
      selected: root.config?.container ?? "mp4"
      title: qsTr("Format")

      onPicked: value => root.config.container = value
    }
    OText {
      Layout.fillWidth: true
      color: Theme.textInactiveColor
      size: "xs"
      text: qsTr("Changes apply to the next recording")
      visible: root.recording
      wrapMode: Text.Wrap
    }
    PanelRow {
      Layout.fillWidth: true
      icon: "󰉋"
      subtitle: root.saveDirectory
      title: qsTr("Open recordings folder")

      onClicked: Command.detached(["xdg-open", ScreenRecordingService.directory])
    }
  }

  component OptionGroup: ColumnLayout {
    id: group

    property var options: []
    property var selected
    property string title: ""

    signal picked(var value)

    Layout.fillWidth: true
    spacing: Theme.spacingXs

    PanelSectionHeader {
      Layout.fillWidth: true
      section: group.title.toUpperCase()
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingXs

      Repeater {
        model: group.options

        delegate: PanelToggleCard {
          required property var modelData

          Layout.preferredHeight: Theme.controlHeightLg
          checked: modelData.value === group.selected
          icon: modelData.icon ?? ""
          label: modelData.label

          onToggled: group.picked(modelData.value)
        }
      }
    }
    OText {
      Layout.fillWidth: true
      color: Theme.textInactiveColor
      opacity: Theme.opacityMuted
      size: "xs"
      text: group.options.find(option => option.value === group.selected)?.detail ?? ""
      visible: text !== ""
      wrapMode: Text.Wrap
    }
  }
}
