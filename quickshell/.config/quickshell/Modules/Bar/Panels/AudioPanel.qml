pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Core

PanelContentBase {
  id: root

  readonly property int sliderHeight: Math.round(Theme.itemHeight * 0.6)

  flatContainer: true
  preferredHeight: contentLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: Theme.audioPanelWidth

  onIsOpenChanged: if (!isOpen) {
    inputPicker.expanded = false;
    outputPicker.expanded = false;
  }

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
        color: Theme.activeSubtle
        radius: Theme.radiusMd

        OText {
          anchors.centerIn: parent
          color: Theme.activeColor
          size: "lg"
          text: "󰕾"
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        OText {
          bold: true
          color: Theme.textActiveColor
          size: "lg"
          text: qsTr("Audio")
        }
        OText {
          color: Theme.textInactiveColor
          size: "xs"
          text: qsTr("Volume, devices and applications")
        }
      }
    }
    AudioControl {
      headroomColor: Theme.critical
      iconOff: "󰝟"
      iconOn: "󰕾"
      muted: AudioService.muted
      ready: AudioService.sinkControllable
      splitAt: 1.0 / AudioService.maxVolume
      subtitle: AudioService.sinkName || qsTr("No output device")
      title: qsTr("Output")
      volume: AudioService.volume / AudioService.maxVolume

      onCommitted: v => AudioService.setVolume(v * AudioService.maxVolume)
      onToggled: AudioService.toggleMute()

      DevicePicker {
        id: outputPicker

        defaultIcon: "󰓃"
        model: AudioService.sinkModels
        visible: model.length > 1

        onDeviceSelected: id => AudioService.setAudioSink(id)
      }
    }
    AudioControl {
      iconOff: "󰍭"
      iconOn: "󰍬"
      muted: AudioService.micMuted
      ready: AudioService.sourceControllable
      sliderSteps: 20
      subtitle: AudioService.sourceName || qsTr("No input device")
      title: qsTr("Microphone")
      visible: AudioService.source !== null
      volume: AudioService.micVolume

      onCommitted: v => AudioService.setInputVolume(v)
      onToggled: AudioService.toggleMicMute()

      DevicePicker {
        id: inputPicker

        defaultIcon: "󰍬"
        model: AudioService.sourceModels
        visible: model.length > 1

        onDeviceSelected: id => AudioService.setAudioSource(id)
      }
    }
    MixerSection {
      Layout.fillWidth: true
    }
  }

  component AudioControl: PanelCard {
    id: hero

    default property alias extensionContent: extensionArea.data
    property color headroomColor: "transparent"
    property string iconOff
    property string iconOn
    property bool muted
    property bool ready: true
    property int sliderSteps: 30
    property real splitAt: 1.0
    property string subtitle: ""
    property string title
    property real volume

    signal committed(real v)
    signal toggled

    Layout.fillWidth: true
    padding: Theme.spacingMd

    ColumnLayout {
      id: heroLayout

      anchors.fill: parent
      spacing: Theme.spacingSm

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        OText {
          color: hero.muted ? Theme.textInactiveColor : Theme.activeColor
          size: "lg"
          text: hero.muted ? hero.iconOff : hero.iconOn
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          OText {
            bold: true
            color: Theme.textActiveColor
            text: hero.title
          }
          OText {
            Layout.fillWidth: true
            color: Theme.textInactiveColor
            elide: Text.ElideRight
            size: "xs"
            text: hero.subtitle
          }
        }
        OText {
          bold: true
          color: hero.ready ? Theme.activeColor : Theme.textInactiveColor
          text: hero.ready ? Math.round(hero.volume * (1.0 / hero.splitAt) * 100) + "%" : "--"
        }
        IconButton {
          Layout.preferredHeight: Theme.controlHeightMd
          Layout.preferredWidth: Theme.controlHeightMd
          colorBg: hero.muted ? Theme.glassControlColor : Theme.activeColor
          icon: hero.muted ? hero.iconOff : hero.iconOn
          isEnabled: hero.ready
          tooltipText: hero.muted ? qsTr("Unmute") : qsTr("Mute")

          onClicked: hero.toggled()
        }
      }
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.sliderHeight

        Slider {
          anchors.fill: parent
          animMs: 0
          headroomColor: hero.headroomColor
          interactive: hero.ready
          splitAt: hero.splitAt
          steps: hero.sliderSteps
          value: hero.ready ? hero.volume : 0
          wheelStep: 1 / steps

          onCommitted: v => { hero.committed(v); value = Qt.binding(() => hero.ready ? hero.volume : 0); }
        }
      }
      ColumnLayout {
        id: extensionArea

        Layout.fillWidth: true
        spacing: Theme.spacingXs
      }
    }
  }
  component DevicePicker: PanelRow {
    id: picker

    property string defaultIcon
    property alias model: deviceRepeater.model

    signal deviceSelected(int id)

    Layout.fillWidth: true
    title: qsTr("Choose device")

    badges: [
      OText {
        color: Theme.textInactiveColor
        rotation: picker.expanded ? 180 : 0
        text: "󰅀"

        Behavior on rotation {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutCubic
          }
        }
      }
    ]
    expandedContent: [
      ColumnLayout {
        spacing: Theme.spacingXs
        width: parent?.width ?? 0

        Repeater {
          id: deviceRepeater

          delegate: PanelRow {
            id: deviceItem

            required property var modelData

            Layout.fillWidth: true
            icon: (modelData?.icon ?? "") || picker.defaultIcon
            selected: modelData?.active ?? false
            title: modelData?.name ?? ""

            actions: [
              OText {
                color: deviceItem.selected ? Theme.activeColor : "transparent"
                size: "sm"
                text: "󰄬"
              }
            ]

            onClicked: {
              picker.deviceSelected(modelData.id);
              picker.expanded = false;
            }
          }
        }
      }
    ]

    onClicked: picker.expanded = !picker.expanded
  }
  component MixerSection: PanelCard {
    id: mixer

    property bool expanded: false
    readonly property int streamCount: AudioService.streamModels.length

    implicitHeight: mixerContent.implicitHeight + Theme.spacingSm * 2
    padding: 0

    ColumnLayout {
      id: mixerContent

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: Theme.spacingSm
      spacing: 0

      PanelRow {
        Layout.fillWidth: true
        expanded: mixer.expanded && mixer.streamCount > 0
        icon: "󰓡"
        subtitle: mixer.streamCount === 0 ? qsTr("No applications playing audio") : qsTr("%1 active").arg(mixer.streamCount)
        title: qsTr("Application mixer")

        badges: [
          OText {
            text: mixer.expanded ? "󰅀" : "󰅂"
          }
        ]

        expandedContent: [
          ListView {
            id: streamList

            boundsBehavior: Flickable.StopAtBounds
            clip: true
            height: Math.min(contentHeight, Theme.controlHeightLg * Theme.audioMixerVisibleRows)
            model: AudioService.streamModels
            spacing: Theme.spacingSm
            width: parent?.width ?? 0

            ScrollBar.vertical: ScrollBar {
              policy: streamList.contentHeight > streamList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            }
            delegate: StreamItem {
              width: ListView.view.width
            }
          }
        ]

        onClicked: mixer.expanded = !mixer.expanded
      }
    }
  }
  component StreamItem: ColumnLayout {
    id: streamItem

    required property var modelData
    readonly property bool muted: modelData.muted ?? false
    readonly property bool ready: modelData.ready ?? false
    readonly property real volume: modelData.volume ?? 0

    spacing: Theme.spacingXs

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingSm

      Image {
        Layout.preferredHeight: Theme.fontLg
        Layout.preferredWidth: Theme.fontLg
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectFit
        opacity: streamItem.muted ? Theme.opacityDisabled : 1
        source: streamItem.modelData.iconSource

        sourceSize {
          height: Theme.fontLg
          width: Theme.fontLg
        }
        OText {
          anchors.centerIn: parent
          text: "󰝚"
          visible: parent.status === Image.Error || parent.status === Image.Null
        }
        TapHandler {
          enabled: streamItem.ready

          onTapped: AudioService.toggleStreamMute(streamItem.modelData.id)
        }
      }
      OText {
        Layout.fillWidth: true
        color: Theme.textActiveColor
        elide: Text.ElideRight
        size: "sm"
        text: streamItem.modelData.name
      }
      OText {
        color: Theme.activeColor
        size: "sm"
        text: Math.round(streamItem.volume * 100) + "%"
      }
    }
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.sliderHeight * 0.8

      Slider {
        anchors.fill: parent
        animMs: 0
        interactive: streamItem.ready
        radius: Theme.itemRadius * 0.5
        steps: 20
        value: streamItem.ready ? streamItem.volume : 0

        onCommitted: v => { AudioService.setStreamVolume(streamItem.modelData.id, v); value = Qt.binding(() => streamItem.ready ? streamItem.volume : 0); }
      }
    }
  }
}
