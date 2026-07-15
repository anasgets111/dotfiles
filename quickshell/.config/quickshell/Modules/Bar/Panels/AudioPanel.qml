pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Core

PanelContentBase {
  id: root

  property bool inputDevicesExpanded: false
  readonly property string inputName: AudioService.sourceName || qsTr("No input device")
  property bool mixerExpanded: false
  property bool outputDevicesExpanded: false
  readonly property string outputName: AudioService.sinkName || qsTr("No output device")
  readonly property int sliderHeight: Math.round(Theme.itemHeight * 0.6)

  preferredHeight: contentLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: 380

  onIsOpenChanged: if (!isOpen) {
    inputDevicesExpanded = false;
    mixerExpanded = false;
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
      Layout.fillWidth: true
      headroomColor: Theme.critical
      iconOff: "󰝟"
      iconOn: "󰕾"
      muted: AudioService.muted
      ready: AudioService.sinkControllable
      splitAt: 1.0 / AudioService.maxVolume
      subtitle: root.outputName
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
      Layout.fillWidth: true
      iconOff: "󰍭"
      iconOn: "󰍬"
      muted: AudioService.micMuted
      ready: AudioService.sourceControllable
      sliderSteps: 20
      subtitle: root.inputName
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

  component AudioControl: Rectangle {
    id: hero

    default property alias content: extensionArea.data
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
    border.color: Theme.borderLight
    border.width: Theme.borderWidthThin
    color: Theme.bgElevated
    implicitHeight: heroLayout.implicitHeight + Theme.spacingMd * 2
    radius: Theme.radiusLg

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

          onCommitted: v => {
            if (hero.ready)
              hero.committed(v);
          }
        }
      }
      ColumnLayout {
        id: extensionArea

        Layout.fillWidth: true
        spacing: Theme.spacingXs
      }
    }
  }
  component DeviceItem: Rectangle {
    id: deviceItem

    property string defaultIcon: ""
    readonly property string displayIcon: (deviceItem.entry?.icon ?? "") || deviceItem.defaultIcon
    readonly property string displayName: deviceItem.entry?.name ?? ""
    property var entry
    readonly property bool isActive: deviceItem.entry?.active ?? false

    signal clicked

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.itemHeight
    color: hoverHandler.hovered ? Theme.onHoverColor : (deviceItem.isActive ? Theme.activeSubtle : "transparent")
    radius: Theme.radiusMd

    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }

    HoverHandler {
      id: hoverHandler
    }
    TapHandler {
      onTapped: deviceItem.clicked()
    }
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Theme.spacingSm
      anchors.rightMargin: Theme.spacingSm
      spacing: Theme.spacingSm

      OText {
        color: deviceItem.isActive ? Theme.activeColor : Theme.textInactiveColor
        text: deviceItem.displayIcon
      }
      OText {
        Layout.fillWidth: true
        bold: deviceItem.isActive
        color: deviceItem.isActive ? Theme.activeColor : (hoverHandler.hovered ? Theme.textOnHoverColor : Theme.textActiveColor)
        elide: Text.ElideRight
        text: deviceItem.displayName
      }
      OText {
        color: Theme.activeColor
        size: "sm"
        text: "󰄬"
        visible: deviceItem.isActive
      }
    }
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

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Theme.controlHeightLg
      color: devicePickerHover.hovered ? Theme.withOpacity(Theme.activeColor, 0.08) : Theme.bgElevatedAlt
      radius: Theme.radiusMd

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }

      HoverHandler {
        id: devicePickerHover
      }
      TapHandler {
        onTapped: picker.toggled()
      }
      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingSm
        anchors.rightMargin: Theme.spacingSm
        spacing: Theme.spacingSm

        OText {
          color: Theme.textInactiveColor
          size: "xs"
          text: qsTr("Choose device")
        }
        Item {
          Layout.fillWidth: true
        }
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
      }
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
  component MixerSection: Rectangle {
    id: mixer

    readonly property int streamCount: AudioService.streamModels.length

    border.color: root.mixerExpanded ? Theme.borderLight : "transparent"
    border.width: Theme.borderWidthThin
    color: root.mixerExpanded ? Theme.bgElevated : "transparent"
    implicitHeight: mixerContent.implicitHeight + (root.mixerExpanded ? Theme.spacingSm * 2 : 0)
    radius: Theme.radiusLg

    Behavior on border.color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }
    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }

    ColumnLayout {
      id: mixerContent

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: root.mixerExpanded ? Theme.spacingSm : 0
      spacing: 0

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight
        color: mixerHover.hovered ? Theme.withOpacity(Theme.activeColor, 0.08) : "transparent"
        radius: Theme.radiusMd

        Behavior on color {
          ColorAnimation {
            duration: Theme.animationDuration
          }
        }

        HoverHandler {
          id: mixerHover
        }
        TapHandler {
          onTapped: root.mixerExpanded = !root.mixerExpanded
        }
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Theme.spacingSm
          anchors.rightMargin: Theme.spacingSm
          spacing: Theme.spacingSm

          OText {
            color: Theme.activeColor
            size: "lg"
            text: "󰓡"
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            OText {
              bold: true
              color: Theme.textActiveColor
              text: qsTr("Application mixer")
            }
            OText {
              color: Theme.textInactiveColor
              size: "xs"
              text: mixer.streamCount === 0 ? qsTr("No applications playing audio") : qsTr("%1 active").arg(mixer.streamCount)
            }
          }
          OText {
            color: Theme.textInactiveColor
            rotation: root.mixerExpanded ? 180 : 0
            text: "󰅀"

            Behavior on rotation {
              NumberAnimation {
                duration: Theme.animationDuration
                easing.type: Easing.OutCubic
              }
            }
          }
        }
      }
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.mixerExpanded ? streamLayout.implicitHeight + Theme.spacingSm : 0
        clip: true

        Behavior on Layout.preferredHeight {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutCubic
          }
        }

        ColumnLayout {
          id: streamLayout

          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: Theme.spacingSm
          spacing: Theme.spacingSm

          Repeater {
            model: AudioService.streamModels

            delegate: StreamItem {
            }
          }
        }
      }
    }
  }
  component StreamItem: ColumnLayout {
    id: streamItem

    required property var modelData
    readonly property bool ready: AudioService.streamReady(modelData.id)
    readonly property real volume: AudioService.streamVolume(modelData.id)

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

        sourceSize {
          height: Theme.fontLg
          width: Theme.fontLg
        }
        OText {
          anchors.centerIn: parent
          text: "󰝚"
          visible: parent.status === Image.Error || parent.status === Image.Null
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

        onCommitted: v => {
          if (streamItem.ready)
            AudioService.setStreamVolume(streamItem.modelData.id, v);
        }
      }
    }
  }
}
