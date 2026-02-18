pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Config
import qs.Components
import qs.Services.Core
import qs.Services.Utils

PanelContentBase {
  id: root

  readonly property string inputName: AudioService.source ? root.friendlyName(AudioService.displayName(AudioService.source)) : qsTr("No input device")
  property bool mixerExpanded: false
  readonly property int muteButtonSize: Math.round(Theme.itemHeight * Theme.scaleSmall)
  readonly property string outputName: AudioService.sink ? root.friendlyName(AudioService.displayName(AudioService.sink)) : qsTr("No output device")
  readonly property real preferredHeight: contentLayout.implicitHeight + Theme.spacingMd * 2
  readonly property real preferredWidth: 400
  property bool ready: false
  readonly property int sliderHeight: Math.round(Theme.itemHeight * 0.6)

  // Strip common vendor noise from device names
  function friendlyName(raw: string): string {
    if (!raw)
      return raw;
    return raw.replace(/\s*High Definition Audio Controller\b/i, "").replace(/\s*HD Audio Controller\b/i, "").replace(/\s*Audio Controller\b/i, "").replace(/\s*Digital Stereo\b/i, "").replace(/\s*Analog Stereo\b/i, "").replace(/\s*\(HDMI\)/i, " HDMI").replace(/\s*\(S\/PDIF\)/i, " S/PDIF").replace(/\s+/g, " ").trim() || raw;
  }

  Component.onCompleted: readyDelay.start()

  Timer {
    id: readyDelay

    interval: 30

    onTriggered: root.ready = true
  }

  // ── Background ──────────────────────────────────────────────

  Rectangle {
    anchors.fill: parent
    color: Theme.bgElevatedAlt
    layer.enabled: true
    radius: 16

    layer.effect: MultiEffect {
      shadowBlur: 0.5
      shadowColor: Qt.rgba(0, 0, 0, 0.18)
      shadowEnabled: true
      shadowVerticalOffset: 4
    }
  }

  // ── Content ─────────────────────────────────────────────────

  ColumnLayout {
    id: contentLayout

    anchors.fill: parent
    anchors.margins: Theme.spacingMd
    spacing: Theme.spacingSm

    // ── Quick-toggle bar ────────────────────────────────────

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
          active: true
          checked: !AudioService.muted
          icon: !AudioService.muted ? "󰕾" : "󰝟"
          label: "Output"

          onToggled: AudioService.toggleMute()
        }

        ToggleSegment {
          Layout.fillHeight: true
          Layout.fillWidth: true
          active: AudioService.source !== null
          checked: AudioService.source !== null && !AudioService.micMuted
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

    // ── Output volume card ──────────────────────────────────

    HeroAudioCard {
      Layout.fillWidth: true
      headroomColor: Theme.critical
      iconOff: "󰝟"
      iconOn: "󰕾"
      muted: AudioService.muted
      splitAt: 1.0 / AudioService.maxVolume
      subtitle: root.outputName
      tag: "OUTPUT"
      title: qsTr("Main Volume")
      volume: AudioService.volume / AudioService.maxVolume

      onCommitted: v => AudioService.setVolume(v * AudioService.maxVolume)
      onToggled: AudioService.toggleMute()

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.mixerExpanded ? (AudioService.streams.length > 0 ? mixerLayout.implicitHeight + Theme.spacingSm * 2 : 48) : 0
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
            visible: AudioService.streams.length === 0
          }

          Repeater {
            model: AudioService.streams

            delegate: StreamItem {
            }
          }
        }
      }
    }

    // ── Input volume card ───────────────────────────────────

    HeroAudioCard {
      Layout.fillWidth: true
      iconOff: "󰍭"
      iconOn: "󰍬"
      muted: AudioService.micMuted
      sliderSteps: 20
      subtitle: root.inputName
      tag: "INPUT"
      title: qsTr("Mic Volume")
      visible: AudioService.source !== null
      volume: AudioService.micVolume

      onCommitted: v => AudioService.setInputVolume(v)
      onToggled: AudioService.toggleMicMute()
    }

    // ── Device lists ────────────────────────────────────────

    DeviceList {
      activeNode: AudioService.sink
      defaultIcon: "󰓃"
      model: AudioService.sinks
      title: qsTr("Output Devices")

      onDeviceSelected: node => AudioService.setAudioSink(node)
    }

    DeviceList {
      Layout.bottomMargin: Theme.spacingSm
      activeNode: AudioService.source
      defaultIcon: "󰍬"
      model: AudioService.sources
      title: qsTr("Input Devices")
      visible: model.length > 0

      onDeviceSelected: node => AudioService.setAudioSource(node)
    }
  }

  // ── Flat device row ───────────────────────────────────────

  component DeviceItem: Rectangle {
    id: deviceItem

    property string defaultIcon: ""
    readonly property string displayIcon: AudioService.deviceIconFor(node) || defaultIcon
    readonly property string displayName: root.friendlyName(AudioService.displayName(node))
    property bool isActive: false
    property var node

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

  // ── Flat device list (no outer container box) ─────────────

  component DeviceList: ColumnLayout {
    id: deviceListRoot

    property var activeNode
    property string defaultIcon
    property alias model: deviceRepeater.model
    property string title

    signal deviceSelected(var node)

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
        isActive: modelData === deviceListRoot.activeNode
        node: modelData

        onClicked: deviceListRoot.deviceSelected(modelData)
      }
    }
  }

  // ── Inline Components ───────────────────────────────────────

  component HeroAudioCard: Rectangle {
    id: hero

    default property alias content: extensionArea.data
    property color headroomColor: "transparent"
    property string iconOff
    property string iconOn
    property bool muted
    property real splitAt: 1.0
    property string subtitle: ""
    property int sliderSteps: 30
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
          text: Math.round(hero.volume * (1.0 / hero.splitAt) * 100) + "%"
        }

        IconButton {
          Layout.preferredHeight: root.muteButtonSize
          Layout.preferredWidth: root.muteButtonSize
          colorBg: hero.muted ? Theme.inactiveColor : Theme.activeColor
          icon: hero.muted ? hero.iconOff : hero.iconOn
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
          interactive: root.ready
          radius: Theme.itemRadius
          splitAt: hero.splitAt
          steps: hero.sliderSteps
          value: root.ready ? hero.volume : 0
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
  component StreamItem: ColumnLayout {
    id: streamItem

    required property var modelData
    readonly property real volume: Number.isFinite(modelData.audio?.volume) ? modelData.audio.volume : 0

    Layout.fillWidth: true
    spacing: Theme.spacingXs

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingSm

      Image {
        Layout.preferredHeight: Theme.fontLg
        Layout.preferredWidth: Theme.fontLg
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectFit
        source: Utils.resolveIconSource(streamItem.modelData.name, streamItem.modelData.properties?.["application.icon-name"], "󰝚")

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
        readonly property string _rawName: streamItem.modelData.name || ""

        Layout.fillWidth: true
        color: Theme.textActiveColor
        elide: Text.ElideRight
        size: "sm"
        text: Utils.lookupDesktopEntryName(_rawName) || _rawName || "Unknown"
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
        interactive: root.ready
        radius: Theme.itemRadius * 0.5
        steps: 20
        value: streamItem.volume
        wheelStep: 1 / steps

        onCommitted: v => {
          if (streamItem.modelData?.audio)
            streamItem.modelData.audio.volume = v;
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
