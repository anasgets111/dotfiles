pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Core

PanelContentBase {
  id: root

  property bool inputDevicesExpanded: false
  property bool outputDevicesExpanded: false
  readonly property int sliderHeight: Math.round(Theme.itemHeight * 0.6)

  preferredHeight: contentLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: Theme.audioPanelWidth

  onIsOpenChanged: if (!isOpen) {
    inputDevicesExpanded = false;
    outputDevicesExpanded = false;
  }

  ColumnLayout {
    id: contentLayout

    anchors.fill: parent
    anchors.margins: Theme.spacingMd
    spacing: 0

    RowLayout {
      Layout.bottomMargin: Theme.spacingMd
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
      Layout.bottomMargin: Theme.spacingMd
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
        defaultIcon: "󰓃"
        expanded: root.outputDevicesExpanded
        model: AudioService.sinkModels
        visible: model.length > 1

        onDeviceSelected: id => AudioService.setAudioSink(id)
        onToggled: root.outputDevicesExpanded = !root.outputDevicesExpanded
      }
    }
    AudioControl {
      Layout.bottomMargin: Theme.spacingMd
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
        defaultIcon: "󰍬"
        expanded: root.inputDevicesExpanded
        model: AudioService.sourceModels
        visible: model.length > 1

        onDeviceSelected: id => AudioService.setAudioSource(id)
        onToggled: root.inputDevicesExpanded = !root.inputDevicesExpanded
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

    padding: 0
    Layout.fillWidth: true
    implicitHeight: heroLayout.implicitHeight + Theme.spacingMd * 2

    ColumnLayout {
      id: heroLayout

      anchors.fill: parent
      anchors.margins: Theme.spacingMd
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
          colorBg: hero.muted ? Theme.inactiveColor : Theme.activeColor
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
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          animMs: 0
          fillColor: Theme.activeColor
          headroomColor: hero.headroomColor
          height: parent.height
          interactive: hero.ready
          radius: Theme.itemRadius
          splitAt: hero.splitAt
          steps: hero.sliderSteps
          value: hero.ready ? hero.volume : 0
          wheelStep: 1 / steps

          onCommitted: v => hero.committed(v)
        }
      }
      ColumnLayout {
        id: extensionArea

        Layout.fillWidth: true
        spacing: Theme.spacingXs
      }
    }
  }
  component DeviceItem: PanelRow {
    id: deviceItem

    property string defaultIcon: ""
    property var entry

    Layout.fillWidth: true
    icon: (entry?.icon ?? "") || defaultIcon
    selected: entry?.active ?? false
    title: entry?.name ?? ""
    actions: [
      OText {
        color: deviceItem.selected ? Theme.activeColor : "transparent"
        size: "sm"
        text: "󰄬"
      }
    ]
  }
  component DevicePicker: ColumnLayout {
    id: picker

    property string defaultIcon
    property bool expanded: false
    property alias model: deviceRepeater.model

    signal deviceSelected(int id)
    signal toggled

    Layout.fillWidth: true
    spacing: 0

    PanelRow {
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

      onClicked: picker.toggled()
    }
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: picker.expanded ? deviceLayout.implicitHeight + Theme.spacingXs : 0
      clip: true

      Behavior on Layout.preferredHeight {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.OutCubic
        }
      }

      ColumnLayout {
        id: deviceLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingXs
        spacing: Theme.spacingXs

        Repeater {
          id: deviceRepeater

          delegate: DeviceItem {
            required property var modelData

            Layout.fillWidth: true
            defaultIcon: picker.defaultIcon
            entry: modelData

            onClicked: {
              picker.deviceSelected(modelData.id);
              picker.toggled();
            }
          }
        }
      }
    }
  }
  component MixerSection: PanelCard {
    id: mixer

    readonly property int streamCount: AudioService.streamModels.length

    padding: 0
    implicitHeight: mixerContent.implicitHeight + Theme.spacingSm * 2

    ColumnLayout {
      id: mixerContent

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: Theme.spacingSm
      spacing: 0

      PanelRow {
        Layout.fillWidth: true
        icon: "󰓡"
        rowActionEnabled: false
        subtitle: mixer.streamCount === 0 ? qsTr("No applications playing audio") : qsTr("%1 active").arg(mixer.streamCount)
        title: qsTr("Application mixer")
      }
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: mixer.streamCount > 0 ? Math.min(streamList.contentHeight, Theme.controlHeightLg * Theme.audioMixerVisibleRows) + Theme.spacingSm : 0
        clip: true

        Behavior on Layout.preferredHeight {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutCubic
          }
        }

        ListView {
          id: streamList

          anchors.fill: parent
          anchors.topMargin: Theme.spacingSm
          boundsBehavior: Flickable.StopAtBounds
          clip: true
          model: AudioService.streamModels
          spacing: Theme.spacingSm

          ScrollBar.vertical: ScrollBar { policy: streamList.contentHeight > streamList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }

          delegate: StreamItem {
            width: ListView.view.width
          }
        }
      }
    }
  }
  component StreamItem: ColumnLayout {
    id: streamItem

    required property var modelData
    readonly property bool ready: modelData.ready ?? false
    readonly property bool muted: modelData.muted ?? false
    readonly property real volume: modelData.volume ?? 0

    Layout.fillWidth: true
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
        source: streamItem.modelData.iconSource
        opacity: streamItem.muted ? Theme.opacityDisabled : 1

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
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        animMs: 0
        fillColor: Theme.activeColor
        height: parent.height
        interactive: streamItem.ready
        radius: Theme.itemRadius * 0.5
        steps: 20
        value: streamItem.ready ? streamItem.volume : 0
        wheelStep: 1 / steps

        onCommitted: v => AudioService.setStreamVolume(streamItem.modelData.id, v)
      }
    }
  }
}
