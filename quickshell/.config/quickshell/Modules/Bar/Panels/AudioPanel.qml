pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Core
import qs.Services.Utils

OPanel {
  id: root

  readonly property color cardBg: Theme.bgElevated
  readonly property color cardBgAlt: Theme.bgElevatedAlt
  readonly property color cardBorder: Theme.borderLight

  // Input state shortcuts
  property bool mixerExpanded: false
  readonly property int muteButtonSize: Math.round(Theme.itemHeight * Theme.scaleSmall)
  readonly property int panelPadding: Theme.spacingSm
  readonly property int sliderHeight: Math.round(Theme.itemHeight * 0.6)

  needsKeyboardFocus: false
  panelNamespace: "obelisk-audio-panel"
  panelWidth: 400

  ColumnLayout {
    spacing: Math.round(root.panelPadding * 1.5)
    width: parent.width - root.panelPadding * 2
    x: root.panelPadding
    y: root.panelPadding

    // Output Volume Card
    VolumeCard {
      headroomColor: Theme.critical
      iconOff: "󰝟"
      iconOn: "󰕾"
      muted: AudioService.muted
      splitAt: 1.0 / AudioService.maxVolume
      title: qsTr("Output Volume")
      volume: AudioService.volume / AudioService.maxVolume

      onCommitted: v => AudioService.setVolume(v * AudioService.maxVolume)
      onToggled: AudioService.toggleMute()

      // Mixer toggle
      MouseArea {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight * 0.5
        cursorShape: Qt.PointingHandCursor

        onClicked: root.mixerExpanded = !root.mixerExpanded

        OText {
          anchors.centerIn: parent
          color: Theme.textInactiveColor
          size: "sm"
          text: root.mixerExpanded ? "󰅃" : "󰅀"
        }
      }

      // Volume Mixer (collapsible)
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.mixerExpanded ? (AudioService.streams.length > 0 ? mixerLayout.implicitHeight : 40) : 0
        clip: true

        Behavior on Layout.preferredHeight {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutCubic
          }
        }

        ColumnLayout {
          id: mixerLayout

          spacing: root.panelPadding * 0.5
          width: parent.width

          OText {
            Layout.fillWidth: true
            Layout.topMargin: root.panelPadding
            color: Theme.textInactiveColor
            horizontalAlignment: Text.AlignHCenter
            size: "sm"
            text: "No active streams"
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

    // Input Volume Card
    VolumeCard {
      iconOff: "󰍭"
      iconOn: "󰍬"
      muted: AudioService.micMuted
      title: qsTr("Input Volume")
      visible: AudioService.source !== null
      volume: AudioService.micVolume

      onCommitted: v => AudioService.setInputVolume(v)
      onToggled: AudioService.toggleMicMute()
    }

    // Output Devices
    DeviceList {
      activeNode: AudioService.sink
      defaultIcon: "󰓃"
      model: AudioService.sinks
      title: qsTr("Output Devices")

      onDeviceSelected: node => AudioService.setAudioSink(node)
    }

    // Input Devices
    DeviceList {
      Layout.bottomMargin: root.panelPadding
      activeNode: AudioService.source
      defaultIcon: "󰍬"
      model: AudioService.sources
      title: qsTr("Input Devices")
      visible: model.length > 0

      onDeviceSelected: node => AudioService.setAudioSource(node)
    }
  }

  // Device list item
  component DeviceItem: Item {
    id: deviceItem

    property string defaultIcon: ""
    readonly property string displayIcon: AudioService.deviceIconFor(node) || defaultIcon
    readonly property string displayName: AudioService.displayName(node)
    property bool isActive: false
    property var node
    readonly property color textColor: hoverHandler.hovered ? Theme.textOnHoverColor : Theme.textActiveColor

    signal clicked

    height: Theme.itemHeight

    Rectangle {
      anchors.fill: parent
      color: hoverHandler.hovered ? Theme.onHoverColor : (deviceItem.isActive ? Theme.activeSubtle : "transparent")
      radius: Theme.itemRadius

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }

      border {
        color: Theme.activeColor
        width: deviceItem.isActive ? 1 : 0
      }
    }

    HoverHandler {
      id: hoverHandler

    }

    TapHandler {
      onTapped: deviceItem.clicked()
    }

    RowLayout {
      spacing: root.panelPadding

      anchors {
        fill: parent
        leftMargin: root.panelPadding
        rightMargin: root.panelPadding
      }

      OText {
        color: deviceItem.isActive ? Theme.activeColor : deviceItem.textColor
        text: deviceItem.displayIcon
      }

      OText {
        Layout.fillWidth: true
        color: deviceItem.textColor
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

  // Device list component
  component DeviceList: ColumnLayout {
    id: deviceListRoot

    property var activeNode
    property string defaultIcon
    property alias model: listView.model
    property string title

    signal deviceSelected(var node)

    Layout.fillWidth: true
    spacing: root.panelPadding * 0.5

    OText {
      bold: true
      text: deviceListRoot.title
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: listView.implicitHeight + root.panelPadding * 1.2
      clip: true
      color: root.cardBgAlt
      radius: Theme.itemRadius

      border {
        color: root.cardBorder
        width: 1
      }

      ListView {
        id: listView

        boundsBehavior: Flickable.StopAtBounds
        clip: true
        implicitHeight: Math.min(contentHeight, Theme.itemHeight * 4)
        interactive: contentHeight > height
        spacing: Theme.spacingXs

        ScrollBar.vertical: ScrollBar {
          policy: listView.contentHeight > listView.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
          width: Theme.scrollBarWidth
        }
        delegate: DeviceItem {
          required property var modelData

          defaultIcon: deviceListRoot.defaultIcon
          isActive: modelData === deviceListRoot.activeNode
          node: modelData
          width: ListView.view.width

          onClicked: deviceListRoot.deviceSelected(modelData)
        }

        anchors {
          fill: parent
          margins: root.panelPadding * 0.6
        }
      }
    }
  }

  // Stream item for mixer
  component StreamItem: ColumnLayout {
    id: streamItem

    required property var modelData
    readonly property real volume: Number.isFinite(modelData.audio?.volume) ? modelData.audio.volume : 0

    Layout.fillWidth: true
    spacing: root.panelPadding * 0.3

    RowLayout {
      Layout.fillWidth: true
      spacing: root.panelPadding

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
        Layout.fillWidth: true
        color: Theme.textActiveColor
        elide: Text.ElideRight
        size: "sm"
        readonly property string _rawName: streamItem.modelData.name || ""
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
        fillColor: Theme.activeColor
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
  component VolumeCard: Rectangle {
    id: volumeCardRoot

    default property alias content: extensionArea.data
    property color headroomColor: "transparent"
    property string iconOff
    property string iconOn
    property bool muted
    property real splitAt: 1.0
    property string title
    property real volume

    signal committed(real v)
    signal toggled

    Layout.fillWidth: true
    Layout.preferredHeight: cardLayout.implicitHeight + root.panelPadding * 1.5
    color: root.cardBg
    radius: Theme.itemRadius

    border {
      color: root.cardBorder
      width: 1
    }

    ColumnLayout {
      id: cardLayout

      spacing: root.panelPadding * 0.8

      anchors {
        fill: parent
        margins: root.panelPadding
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: root.panelPadding

        OText {
          color: volumeCardRoot.muted ? Theme.textInactiveColor : Theme.activeColor
          font.pixelSize: Theme.fontLg
          text: volumeCardRoot.muted ? volumeCardRoot.iconOff : volumeCardRoot.iconOn
        }

        OText {
          Layout.fillWidth: true
          bold: true
          text: volumeCardRoot.title
        }

        OText {
          bold: true
          color: Theme.textActiveColor
          text: Math.round(volumeCardRoot.volume * (1.0 / volumeCardRoot.splitAt) * 100) + "%"
        }

        IconButton {
          Layout.preferredHeight: root.muteButtonSize
          Layout.preferredWidth: root.muteButtonSize
          colorBg: volumeCardRoot.muted ? Theme.inactiveColor : Theme.activeColor
          icon: volumeCardRoot.muted ? volumeCardRoot.iconOff : volumeCardRoot.iconOn
          tooltipText: volumeCardRoot.muted ? qsTr("Unmute") : qsTr("Mute")

          onClicked: volumeCardRoot.toggled()
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.sliderHeight

        Slider {
          fillColor: Theme.activeColor
          headroomColor: volumeCardRoot.headroomColor
          radius: Theme.itemRadius
          splitAt: volumeCardRoot.splitAt
          steps: 30
          value: volumeCardRoot.volume
          wheelStep: 1 / steps

          onCommitted: v => volumeCardRoot.committed(v)
        }
      }

      ColumnLayout {
        id: extensionArea

        Layout.fillWidth: true
        spacing: root.panelPadding * 0.8
      }
    }
  }
}
