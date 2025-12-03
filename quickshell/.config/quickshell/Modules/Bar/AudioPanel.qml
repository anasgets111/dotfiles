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

  readonly property int muteButtonSize: Math.round(Theme.itemHeight * Theme.scaleSmall)
  readonly property color cardBg: Theme.bgElevated
  readonly property color cardBgAlt: Theme.bgElevatedAlt
  readonly property color cardBorder: Theme.borderLight

  // Input state shortcuts
  readonly property var inputAudio: AudioService.source?.audio ?? null
  readonly property bool inputMuted: inputAudio?.muted ?? false
  readonly property real inputVolume: inputAudio?.volume ?? 0
  property bool mixerExpanded: false
  readonly property int panelPadding: Theme.spacingSm
  readonly property int sliderHeight: Math.round(Theme.itemHeight * 0.6)

  needsKeyboardFocus: false
  panelNamespace: "obelisk-audio-panel"
  panelWidth: 400

  onVisibleChanged: {
    if (visible) {
      outputSlider.value = AudioService.volume / AudioService.maxVolume;
      inputSlider.value = inputVolume;
    }
  }

  ColumnLayout {
    spacing: Math.round(root.panelPadding * 1.5)
    width: parent.width - root.panelPadding * 2
    x: root.panelPadding
    y: root.panelPadding

    // Output Volume Card
    Rectangle {
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: outputCol.implicitHeight + root.panelPadding * 1.5
      color: root.cardBg
      radius: Theme.itemRadius

      border {
        color: root.cardBorder
        width: 1
      }

      ColumnLayout {
        id: outputCol

        spacing: root.panelPadding * 0.8

        anchors {
          fill: parent
          margins: root.panelPadding
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: root.panelPadding

          OText {
            color: AudioService.muted ? Theme.textInactiveColor : Theme.activeColor
            font.pixelSize: Theme.fontLg
            text: AudioService.muted ? "󰝟" : "󰕾"
          }

          OText {
            Layout.fillWidth: true
            bold: true
            text: qsTr("Output Volume")
          }

          OText {
            bold: true
            color: Theme.textActiveColor
            text: Math.round(AudioService.volume * 100) + "%"
          }

          IconButton {
            Layout.preferredHeight: root.muteButtonSize
            Layout.preferredWidth: root.muteButtonSize
            colorBg: AudioService.muted ? Theme.inactiveColor : Theme.activeColor
            icon: AudioService.muted ? "󰝟" : "󰕾"
            tooltipText: AudioService.muted ? qsTr("Unmute") : qsTr("Mute")

            onClicked: AudioService.toggleMute()
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: root.sliderHeight

          Slider {
            id: outputSlider

            fillColor: Theme.activeColor
            headroomColor: Theme.critical
            radius: Theme.itemRadius
            splitAt: 1.0 / AudioService.maxVolume
            steps: 30
            wheelStep: 1 / steps

            onCommitted: v => AudioService.setVolume(v * AudioService.maxVolume)
          }
        }

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
          Layout.preferredHeight: root.mixerExpanded ? (AudioService.streams.length > 0 ? mixerCol.implicitHeight : 40) : 0
          clip: true

          Behavior on Layout.preferredHeight {
            NumberAnimation {
              duration: Theme.animationDuration
              easing.type: Easing.OutCubic
            }
          }

          ColumnLayout {
            id: mixerCol

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
    }

    // Input Volume Card
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: inputCol.implicitHeight + root.panelPadding * 1.5
      color: root.cardBg
      radius: Theme.itemRadius
      visible: AudioService.source !== null

      border {
        color: root.cardBorder
        width: 1
      }

      ColumnLayout {
        id: inputCol

        spacing: root.panelPadding * 0.8

        anchors {
          fill: parent
          margins: root.panelPadding
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: root.panelPadding

          OText {
            color: root.inputMuted ? Theme.textInactiveColor : Theme.activeColor
            font.pixelSize: Theme.fontLg
            text: root.inputMuted ? "󰍭" : "󰍬"
          }

          OText {
            Layout.fillWidth: true
            bold: true
            text: qsTr("Input Volume")
          }

          OText {
            bold: true
            color: Theme.textActiveColor
            text: Math.round(root.inputVolume * 100) + "%"
          }

          IconButton {
            Layout.preferredHeight: root.muteButtonSize
            Layout.preferredWidth: root.muteButtonSize
            colorBg: root.inputMuted ? Theme.inactiveColor : Theme.activeColor
            icon: root.inputMuted ? "󰍭" : "󰍬"
            tooltipText: root.inputMuted ? qsTr("Unmute Mic") : qsTr("Mute Mic")

            onClicked: AudioService.toggleMicMute()
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: root.sliderHeight

          Slider {
            id: inputSlider

            fillColor: Theme.activeColor
            radius: Theme.itemRadius
            steps: 30
            wheelStep: 1 / steps

            onCommitted: v => {
              if (root.inputAudio)
                root.inputAudio.volume = v;
            }
          }
        }
      }
    }

    // Output Devices
    ColumnLayout {
      Layout.fillWidth: true
      spacing: root.panelPadding * 0.5

      OText {
        bold: true
        text: qsTr("Output Devices")
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: sinkList.implicitHeight + root.panelPadding * 1.2
        clip: true
        color: root.cardBgAlt
        radius: Theme.itemRadius

        border {
          color: root.cardBorder
          width: 1
        }

        ListView {
          id: sinkList

          boundsBehavior: Flickable.StopAtBounds
          clip: true
          implicitHeight: Math.min(contentHeight, Theme.itemHeight * 4)
          interactive: contentHeight > height
          model: AudioService.sinks
          spacing: Theme.spacingXs

          ScrollBar.vertical: ScrollBar {
            policy: sinkList.contentHeight > sinkList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: Theme.scrollBarWidth
          }
          delegate: DeviceItem {
            required property var modelData

            defaultIcon: "󰓃"
            isActive: modelData === AudioService.sink
            node: modelData
            width: ListView.view.width

            onClicked: AudioService.setAudioSink(modelData)
          }

          anchors {
            fill: parent
            margins: root.panelPadding * 0.6
          }
        }
      }
    }

    // Input Devices
    ColumnLayout {
      Layout.bottomMargin: root.panelPadding
      Layout.fillWidth: true
      spacing: root.panelPadding * 0.5
      visible: sourceList.count > 0

      OText {
        bold: true
        text: qsTr("Input Devices")
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: sourceList.implicitHeight + root.panelPadding * 1.2
        clip: true
        color: root.cardBgAlt
        radius: Theme.itemRadius

        border {
          color: root.cardBorder
          width: 1
        }

        ListView {
          id: sourceList

          boundsBehavior: Flickable.StopAtBounds
          clip: true
          implicitHeight: Math.min(contentHeight, Theme.itemHeight * 4)
          interactive: contentHeight > height
          model: AudioService.sources
          spacing: Theme.spacingXs

          ScrollBar.vertical: ScrollBar {
            policy: sourceList.contentHeight > sourceList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: Theme.scrollBarWidth
          }
          delegate: DeviceItem {
            required property var modelData

            defaultIcon: "󰍬"
            isActive: modelData === AudioService.source
            node: modelData
            width: ListView.view.width

            onClicked: AudioService.setAudioSource(modelData)
          }

          anchors {
            fill: parent
            margins: root.panelPadding * 0.6
          }
        }
      }
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

  // Stream item for mixer
  component StreamItem: ColumnLayout {
    id: streamItem

    required property var modelData
    readonly property real vol: modelData.audio?.volume ?? 0

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
        text: streamItem.modelData.name || "Unknown"
      }

      OText {
        color: Theme.textInactiveColor
        size: "sm"
        text: Math.round(streamItem.vol * 100) + "%"
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.sliderHeight * 0.8

      Slider {
        fillColor: Theme.activeColor
        radius: Theme.itemRadius * 0.5
        steps: 20
        value: streamItem.vol
        wheelStep: 1 / steps

        onCommitted: v => {
          if (streamItem.modelData?.audio)
            streamItem.modelData.audio.volume = v;
        }
      }
    }
  }
}
