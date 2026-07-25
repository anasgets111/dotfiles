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
  readonly property var settingGroups: [
    {
      key: "audio",
      title: qsTr("Audio"),
      fallback: "desktop",
      options: [
        {
          value: "off",
          label: qsTr("No audio"),
          icon: "󰝟"
        },
        {
          value: "desktop",
          label: qsTr("Desktop audio"),
          icon: "󰕾"
        },
        {
          value: "mic",
          label: qsTr("Desktop + Mic"),
          icon: "󰍬"
        }
      ]
    },
    {
      key: "quality",
      title: qsTr("Quality"),
      fallback: "high",
      options: [
        {
          value: "low",
          label: qsTr("Low"),
          icon: "󰾆",
          detail: qsTr("Smallest files, softest detail in motion")
        },
        {
          value: "medium",
          label: qsTr("Medium"),
          icon: "󰾅",
          detail: qsTr("Balanced size and detail")
        },
        {
          value: "high",
          label: qsTr("High"),
          icon: "󰓅",
          detail: qsTr("Sharpest detail, largest files")
        }
      ]
    },
    {
      key: "fps",
      title: qsTr("Frame rate"),
      fallback: 60,
      options: [30, 60, 120].map(rate => ({
            value: rate,
            label: qsTr("%1 FPS").arg(rate)
          }))
    },
    {
      key: "container",
      title: qsTr("Format"),
      fallback: "mp4",
      options: [
        {
          value: "mp4",
          label: qsTr("MP4"),
          icon: "󰈫",
          detail: qsTr("Plays and uploads anywhere")
        },
        {
          value: "mkv",
          label: qsTr("MKV"),
          icon: "󰿎",
          detail: qsTr("Stays playable if the session crashes mid-recording")
        }
      ]
    }
  ]
  property bool settingsExpanded: false
  readonly property string settingsSummary: root.settingGroups.map(group => group.options.find(option => option.value === root.selectedValue(group))?.label).filter(Boolean).join(" · ")
  readonly property string statusText: root.recording ? [root.paused ? qsTr("Paused") : qsTr("Recording"), ScreenRecordingService.captureLabel].filter(Boolean).join(" · ") : qsTr("Ready · %1").arg(ScreenRecordingService.monitor || qsTr("no output"))

  function beginRecording(mode: string): void {
    root.closeRequested();
    ScreenRecordingService.startRecording(mode);
  }
  function selectedValue(group: var): var {
    return root.config?.[group.key] ?? group.fallback;
  }

  flatContainer: true
  preferredHeight: contentLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: Theme.panelDefaultWidth

  onIsOpenChanged: if (!isOpen)
    settingsExpanded = false

  ColumnLayout {
    id: contentLayout

    anchors.left: parent.left
    anchors.margins: Theme.spacingMd
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Theme.spacingMd

    PanelHeader {
      accent: root.recording ? Theme.critical : Theme.activeColor
      icon: "󰑊"
      subtitle: root.statusText
      title: qsTr("Screen Recorder")

      InfoBadge {
        badgeColor: root.paused ? Theme.warning : Theme.critical
        text: ScreenRecordingService.elapsedText
        visible: root.recording
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
    PanelRow {
      Layout.fillWidth: true
      expandable: true
      expanded: root.settingsExpanded
      icon: "󰒓"
      subtitle: root.settingsSummary
      title: qsTr("Recording settings")

      expandedContent: [
        ColumnLayout {
          spacing: Theme.spacingMd
          width: parent?.width ?? 0

          Repeater {
            model: root.settingGroups

            delegate: OptionGroup {
              required property var modelData

              options: modelData.options
              selected: root.selectedValue(modelData)
              title: modelData.title

              onPicked: value => root.config[modelData.key] = value
            }
          }
          OText {
            Layout.fillWidth: true
            color: Theme.textInactiveColor
            size: "xs"
            text: qsTr("Changes apply to the next recording")
            visible: root.recording
            wrapMode: Text.Wrap
          }
        }
      ]

      onClicked: root.settingsExpanded = !root.settingsExpanded
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
      section: group.title
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
