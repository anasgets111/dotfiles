pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Core

PanelContentBase {
  id: root

  readonly property string inputName: AudioService.sourceName || qsTr("No input device")
  property bool mixerExpanded: false
  readonly property int muteButtonSize: Math.round(Theme.itemHeight * Theme.scaleSmall)
  readonly property string outputName: AudioService.sinkName || qsTr("No output device")
  readonly property int sliderHeight: Math.round(Theme.itemHeight * 0.6)

  preferredHeight: contentLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: 400

  ColumnLayout {
    id: contentLayout

    anchors.fill: parent
    anchors.margins: Theme.spacingMd
    spacing: Theme.spacingSm

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 40
      border.color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.12)
      border.width: 1
      color: Theme.bgElevated
      radius: 10

      RowLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 3

        ToggleSegment {
          Layout.fillHeight: true
          Layout.fillWidth: true
          active: AudioService.sinkControllable
          checked: !AudioService.muted
          icon: !AudioService.muted ? "󰕾" : "󰝟"
          label: "Output"

          onToggled: AudioService.toggleMute()
        }

        ToggleSegment {
          Layout.fillHeight: true
          Layout.fillWidth: true
          active: AudioService.sourceControllable
          checked: AudioService.sourceControllable && !AudioService.micMuted
          icon: AudioService.micMuted ? "󰍭" : "󰍬"
          label: "Mic"

          onToggled: AudioService.toggleMicMute()
        }

        ToggleSegment {
          Layout.fillHeight: true
          Layout.fillWidth: true
          active: true
          checked: root.mixerExpanded
          icon: root.mixerExpanded ? "󰅃" : "󰅀"
          label: "Mixer"

          onToggled: root.mixerExpanded = !root.mixerExpanded
        }
      }
    }

    HeroAudioCard {
      Layout.fillWidth: true
      headroomColor: Theme.critical
      iconOff: "󰝟"
      iconOn: "󰕾"
      muted: AudioService.muted
      ready: AudioService.sinkControllable
      splitAt: 1.0 / AudioService.maxVolume
      subtitle: root.outputName
      tag: "OUTPUT"
      title: qsTr("Main Volume")
      volume: AudioService.volume / AudioService.maxVolume

      onCommitted: v => AudioService.setVolume(v * AudioService.maxVolume)
      onToggled: AudioService.toggleMute()

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.mixerExpanded ? (AudioService.streamModels.length > 0 ? mixerLayout.implicitHeight + Theme.spacingSm * 2 : 48) : 0
        clip: true

        Behavior on Layout.preferredHeight {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutCubic
          }
        }

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(Theme.textActiveColor.r, Theme.textActiveColor.g, Theme.textActiveColor.b, 0.03)
          radius: 10
          visible: root.mixerExpanded
        }

        ColumnLayout {
          id: mixerLayout

          anchors.fill: parent
          anchors.margins: Theme.spacingSm
          spacing: Theme.spacingXs
          visible: root.mixerExpanded

          OText {
            Layout.fillWidth: true
            color: Theme.textInactiveColor
            horizontalAlignment: Text.AlignHCenter
            size: "sm"
            text: qsTr("No active streams")
            visible: AudioService.streamModels.length === 0
          }

          Repeater {
            model: AudioService.streamModels

            delegate: StreamItem {
            }
          }
        }
      }
    }

    HeroAudioCard {
      Layout.fillWidth: true
      iconOff: "󰍭"
      iconOn: "󰍬"
      muted: AudioService.micMuted
      ready: AudioService.sourceControllable
      sliderSteps: 20
      subtitle: root.inputName
      tag: "INPUT"
      title: qsTr("Mic Volume")
      visible: AudioService.source !== null
      volume: AudioService.micVolume

      onCommitted: v => AudioService.setInputVolume(v)
      onToggled: AudioService.toggleMicMute()
    }

    DeviceList {
      defaultIcon: "󰓃"
      model: AudioService.sinkModels
      title: qsTr("Output Devices")

      onDeviceSelected: id => AudioService.setAudioSink(id)
    }

    DeviceList {
      Layout.bottomMargin: Theme.spacingSm
      defaultIcon: "󰍬"
      model: AudioService.sourceModels
      title: qsTr("Input Devices")
      visible: model.length > 0

      onDeviceSelected: id => AudioService.setAudioSource(id)
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
    radius: 10

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
  component DeviceList: ColumnLayout {
    id: deviceListRoot

    property string defaultIcon
    property alias model: deviceRepeater.model
    property string title

    signal deviceSelected(int id)

    Layout.fillWidth: true
    spacing: Theme.spacingXs

    OText {
      bold: true
      color: Theme.textInactiveColor
      size: "xs"
      text: deviceListRoot.title.toUpperCase()
    }

    Repeater {
      id: deviceRepeater

      delegate: DeviceItem {
        required property var modelData

        Layout.fillWidth: true
        defaultIcon: deviceListRoot.defaultIcon
        entry: modelData

        onClicked: deviceListRoot.deviceSelected(modelData.id)
      }
    }
  }
  component HeroAudioCard: Rectangle {
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
    property string tag: ""
    property string title
    property real volume

    signal committed(real v)
    signal toggled

    Layout.fillWidth: true
    border.color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.25)
    border.width: 1
    color: Theme.activeSubtle
    implicitHeight: heroLayout.implicitHeight + Theme.spacingMd * 2
    radius: 14

    ColumnLayout {
      id: heroLayout

      anchors.fill: parent
      anchors.margins: Theme.spacingMd
      spacing: Theme.spacingSm

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Rectangle {
          Layout.preferredHeight: 22
          Layout.preferredWidth: tagText.implicitWidth + Theme.spacingSm
          color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.14)
          radius: 6
          visible: hero.tag !== ""

          OText {
            id: tagText

            anchors.centerIn: parent
            bold: true
            color: Theme.activeColor
            size: "xs"
            text: hero.tag
          }
        }

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
            color: Theme.activeColor
            text: hero.title
          }

          OText {
            Layout.fillWidth: true
            color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.75)
            elide: Text.ElideRight
            size: "xs"
            text: hero.subtitle
          }
        }

        OText {
          bold: true
          color: Theme.textActiveColor
          text: hero.ready ? Math.round(hero.volume * (1.0 / hero.splitAt) * 100) + "%" : "--"
        }

        IconButton {
          Layout.preferredHeight: root.muteButtonSize
          Layout.preferredWidth: root.muteButtonSize
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
        color: Theme.textInactiveColor
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
  component ToggleSegment: Item {
    id: seg

    property bool active: true
    property bool checked: false
    required property string icon
    required property string label

    signal toggled

    opacity: seg.active ? 1.0 : Theme.opacityDisabled

    Rectangle {
      anchors.fill: parent
      color: seg.checked && seg.active ? Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.2) : "transparent"
      radius: 8

      Behavior on color {
        ColorAnimation {
          duration: 120
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: seg.active ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: seg.active

      onClicked: seg.toggled()
    }

    RowLayout {
      anchors.centerIn: parent
      spacing: 4

      Text {
        color: seg.checked && seg.active ? Theme.activeColor : Theme.textInactiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: seg.icon

        Behavior on color {
          ColorAnimation {
            duration: 120
          }
        }
      }

      OText {
        bold: seg.checked
        color: seg.checked && seg.active ? Theme.activeColor : Theme.textInactiveColor
        size: "xs"
        text: seg.label

        Behavior on color {
          ColorAnimation {
            duration: 120
          }
        }
      }
    }
  }
}
