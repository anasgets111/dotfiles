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

  readonly property int btnSize: Theme.itemHeight * 0.7
  readonly property color cardBg: Qt.lighter(Theme.bgColor, 1.35)
  readonly property color cardBgAlt: Qt.lighter(Theme.bgColor, 1.25)
  readonly property color cardBorder: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)

  // Input state shortcuts
  readonly property var inputAudio: AudioService.source?.audio ?? null
  readonly property bool inputMuted: inputAudio?.muted ?? false
  readonly property real inputVolume: inputAudio?.volume ?? 0
  property bool mixerExpanded: false
  readonly property int pad: 8
  readonly property int sliderHeight: Theme.itemHeight * 0.6

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
    spacing: root.pad * 1.5
    width: parent.width - root.pad * 2
    x: root.pad
    y: root.pad

    // Output Volume Card
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: outputCol.implicitHeight + root.pad * 1.5
      color: root.cardBg
      radius: Theme.itemRadius

      border {
        color: root.cardBorder
        width: 1
      }

      ColumnLayout {
        id: outputCol

        spacing: root.pad * 0.8

        anchors {
          fill: parent
          margins: root.pad
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: root.pad

          Text {
            color: AudioService.muted ? Theme.textInactiveColor : Theme.activeColor
            text: AudioService.muted ? "󰝟" : "󰕾"

            font {
              family: Theme.fontFamily
              pixelSize: Theme.fontSize * 1.2
            }
          }

          OText {
            Layout.fillWidth: true
            font.bold: true
            text: qsTr("Output Volume")
          }

          Text {
            color: Theme.textActiveColor
            text: Math.round(AudioService.volume * 100) + "%"

            font {
              bold: true
              family: Theme.fontFamily
              pixelSize: Theme.fontSize
            }
          }

          IconButton {
            Layout.preferredHeight: root.btnSize
            Layout.preferredWidth: root.btnSize
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

          Text {
            anchors.centerIn: parent
            color: Theme.textInactiveColor
            text: root.mixerExpanded ? "󰅃" : "󰅀"

            font {
              family: Theme.fontFamily
              pixelSize: Theme.fontSize * 0.9
            }
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

            spacing: root.pad * 0.5
            width: parent.width

            Text {
              Layout.fillWidth: true
              Layout.topMargin: root.pad
              color: Theme.textInactiveColor
              horizontalAlignment: Text.AlignHCenter
              text: "No active streams"
              visible: AudioService.streams.length === 0

              font {
                family: Theme.fontFamily
                pixelSize: Theme.fontSize * 0.9
              }
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
      Layout.preferredHeight: inputCol.implicitHeight + root.pad * 1.5
      color: root.cardBg
      radius: Theme.itemRadius
      visible: AudioService.source !== null

      border {
        color: root.cardBorder
        width: 1
      }

      ColumnLayout {
        id: inputCol

        spacing: root.pad * 0.8

        anchors {
          fill: parent
          margins: root.pad
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: root.pad

          Text {
            color: root.inputMuted ? Theme.textInactiveColor : Theme.activeColor
            text: root.inputMuted ? "󰍭" : "󰍬"

            font {
              family: Theme.fontFamily
              pixelSize: Theme.fontSize * 1.2
            }
          }

          OText {
            Layout.fillWidth: true
            font.bold: true
            text: qsTr("Input Volume")
          }

          Text {
            color: Theme.textActiveColor
            text: Math.round(root.inputVolume * 100) + "%"

            font {
              bold: true
              family: Theme.fontFamily
              pixelSize: Theme.fontSize
            }
          }

          IconButton {
            Layout.preferredHeight: root.btnSize
            Layout.preferredWidth: root.btnSize
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
      spacing: root.pad * 0.5

      OText {
        color: Theme.textActiveColor
        font.bold: true
        text: qsTr("Output Devices")
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: sinkList.implicitHeight + root.pad * 1.2
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
          spacing: 4

          ScrollBar.vertical: ScrollBar {
            policy: sinkList.contentHeight > sinkList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 8
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
            margins: root.pad * 0.6
          }
        }
      }
    }

    // Input Devices
    ColumnLayout {
      Layout.bottomMargin: root.pad
      Layout.fillWidth: true
      spacing: root.pad * 0.5
      visible: sourceList.count > 0

      OText {
        color: Theme.textActiveColor
        font.bold: true
        text: qsTr("Input Devices")
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: sourceList.implicitHeight + root.pad * 1.2
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
          spacing: 4

          ScrollBar.vertical: ScrollBar {
            policy: sourceList.contentHeight > sourceList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 8
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
            margins: root.pad * 0.6
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
      color: hoverHandler.hovered ? Theme.onHoverColor : (deviceItem.isActive ? Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.15) : "transparent")
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
      spacing: root.pad

      anchors {
        fill: parent
        leftMargin: root.pad
        rightMargin: root.pad
      }

      Text {
        color: deviceItem.isActive ? Theme.activeColor : deviceItem.textColor
        text: deviceItem.displayIcon

        font {
          family: Theme.fontFamily
          pixelSize: Theme.fontSize
        }
      }

      Text {
        Layout.fillWidth: true
        color: deviceItem.textColor
        elide: Text.ElideRight
        text: deviceItem.displayName

        font {
          family: Theme.fontFamily
          pixelSize: Theme.fontSize
        }
      }

      Text {
        color: Theme.activeColor
        text: "󰄬"
        visible: deviceItem.isActive

        font {
          family: Theme.fontFamily
          pixelSize: Theme.fontSize * 0.9
        }
      }
    }
  }

  // Stream item for mixer
  component StreamItem: ColumnLayout {
    id: streamItem

    required property var modelData
    readonly property real vol: modelData.audio?.volume ?? 0

    Layout.fillWidth: true
    spacing: root.pad * 0.3

    RowLayout {
      Layout.fillWidth: true
      spacing: root.pad

      Image {
        Layout.preferredHeight: Theme.fontSize * 1.3
        Layout.preferredWidth: Theme.fontSize * 1.3
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectFit
        source: Utils.resolveIconSource(streamItem.modelData.name, streamItem.modelData.properties?.["application.icon-name"], "󰝚")

        sourceSize {
          height: Theme.fontSize * 1.3
          width: Theme.fontSize * 1.3
        }

        Text {
          anchors.centerIn: parent
          color: Theme.textActiveColor
          text: "󰝚"
          visible: parent.status === Image.Error || parent.status === Image.Null

          font {
            family: Theme.fontFamily
            pixelSize: Theme.fontSize
          }
        }
      }

      Text {
        Layout.fillWidth: true
        color: Theme.textActiveColor
        elide: Text.ElideRight
        text: streamItem.modelData.name || "Unknown"

        font {
          family: Theme.fontFamily
          pixelSize: Theme.fontSize * 0.9
        }
      }

      Text {
        color: Theme.textInactiveColor
        text: Math.round(streamItem.vol * 100) + "%"

        font {
          family: Theme.fontFamily
          pixelSize: Theme.fontSize * 0.8
        }
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
