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
  panelNamespace: "obelisk-audio-panel"

  readonly property var currentSink: AudioService.sink
  readonly property var currentSource: AudioService.source
  readonly property var sinks: AudioService.sinks
  readonly property var sources: AudioService.sources

  readonly property bool outputMuted: AudioService.muted
  readonly property real outputVolume: AudioService.volume
  readonly property bool inputMuted: currentSource?.audio?.muted ?? false
  readonly property real inputVolume: currentSource?.audio?.volume ?? 0

  readonly property int padding: 8
  readonly property int sliderHeight: Theme.itemHeight * 0.6
  readonly property var streams: AudioService.streams
  readonly property color borderColor: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
  readonly property int cardPadding: padding
  readonly property int cardSpacing: padding * 0.8
  readonly property int actionButtonSize: Theme.itemHeight * 0.7

  readonly property string outputIcon: outputMuted ? "󰝟" : "󰕾"
  readonly property color outputIconColor: outputMuted ? Theme.textInactiveColor : Theme.activeColor
  readonly property string inputIcon: inputMuted ? "󰍭" : "󰍬"
  readonly property color inputIconColor: inputMuted ? Theme.textInactiveColor : Theme.activeColor

  property bool mixerExpanded: false

  panelWidth: 400
  needsKeyboardFocus: false

  onOutputVolumeChanged: {
    if (!outputVolumeSlider.dragging) {
      outputVolumeSlider.value = root.outputVolume / AudioService.maxVolume;
    }
  }

  onInputVolumeChanged: {
    if (!inputVolumeSlider.dragging) {
      inputVolumeSlider.value = root.inputVolume;
    }
  }

  function formatPercentage(value) {
    return Math.round(value * 100) + "%";
  }

  function buildDeviceList(devices, currentDevice, defaultIcon) {
    return devices.map(node => ({
          node: node,
          name: AudioService.displayName(node),
          icon: AudioService.deviceIconFor(node) || defaultIcon,
          isActive: node === currentDevice
        }));
  }

  ColumnLayout {
    width: parent.width - root.padding * 2
    x: root.padding
    y: root.padding
    spacing: root.padding * 1.5

    // Output Volume Section
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: outputCol.implicitHeight + root.cardPadding * 1.5
      radius: Theme.itemRadius
      color: Qt.lighter(Theme.bgColor, 1.35)
      border.width: 1
      border.color: root.borderColor

      ColumnLayout {
        id: outputCol
        anchors.fill: parent
        anchors.margins: root.cardPadding
        spacing: root.cardSpacing

        RowLayout {
          Layout.fillWidth: true
          spacing: root.padding

          Text {
            text: root.outputIcon
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 1.2
            color: root.outputIconColor
          }

          OText {
            text: qsTr("Output Volume")
            font.bold: true
            Layout.fillWidth: true
          }

          Text {
            text: root.formatPercentage(root.outputVolume)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            color: Theme.textActiveColor
          }

          IconButton {
            Layout.preferredWidth: root.actionButtonSize
            Layout.preferredHeight: root.actionButtonSize
            icon: root.outputIcon
            colorBg: root.outputMuted ? Theme.inactiveColor : Theme.activeColor
            tooltipText: root.outputMuted ? qsTr("Unmute") : qsTr("Mute")
            onClicked: AudioService.toggleMute()
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: root.sliderHeight

          Slider {
            id: outputVolumeSlider
            steps: 30
            wheelStep: 1 / steps
            splitAt: 1.0 / AudioService.maxVolume
            fillColor: Theme.activeColor
            headroomColor: Theme.critical
            radius: Theme.itemRadius
            interactive: true
            onCommitted: normalized => {
              AudioService.setVolumeReal(normalized * AudioService.maxVolume);
            }
          }
        }

        // Expand/Collapse Arrow
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Theme.itemHeight * 0.5
          color: "transparent"

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.mixerExpanded = !root.mixerExpanded

            Text {
              anchors.centerIn: parent
              text: root.mixerExpanded ? "󰅃" : "󰅀"
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize * 0.9
              color: Theme.textInactiveColor
            }
          }
        }

        // Volume Mixer
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: root.mixerExpanded ? (root.streams.length > 0 ? mixerCol.implicitHeight : 40) : 0
          clip: true
          visible: root.mixerExpanded || Layout.preferredHeight > 0

          Behavior on Layout.preferredHeight {
            NumberAnimation {
              duration: Theme.animationDuration
              easing.type: Easing.OutCubic
            }
          }

          ColumnLayout {
            id: mixerCol
            width: parent.width
            spacing: root.padding * 0.5

            Text {
              visible: root.streams.length === 0
              text: "No active streams"
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize * 0.9
              color: Theme.textInactiveColor
              horizontalAlignment: Text.AlignHCenter
              Layout.fillWidth: true
              Layout.topMargin: root.padding
            }

            Repeater {
              model: root.streams

              ColumnLayout {
                id: streamItem
                required property var modelData

                Layout.fillWidth: true
                spacing: root.padding * 0.3

                RowLayout {
                  Layout.fillWidth: true
                  spacing: root.padding

                  Image {
                    source: Utils.resolveIconSource(streamItem.modelData.name, streamItem.modelData.properties?.["application.icon-name"], "󰝚")
                    sourceSize.width: Theme.fontSize * 1.3
                    sourceSize.height: Theme.fontSize * 1.3
                    Layout.preferredWidth: Theme.fontSize * 1.3
                    Layout.preferredHeight: Theme.fontSize * 1.3
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectFit
                    smooth: true

                    // Fallback text icon if image fails to load
                    Text {
                      visible: parent.status === Image.Error || parent.status === Image.Null
                      anchors.centerIn: parent
                      text: "󰝚"
                      font.family: Theme.fontFamily
                      font.pixelSize: Theme.fontSize
                      color: Theme.textActiveColor
                    }
                  }

                  Text {
                    text: streamItem.modelData.name || "Unknown"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.9
                    color: Theme.textActiveColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Text {
                    text: root.formatPercentage(streamItem.modelData.audio?.volume ?? 0)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize * 0.8
                    color: Theme.textInactiveColor
                  }
                }

                Item {
                  Layout.fillWidth: true
                  Layout.preferredHeight: root.sliderHeight * 0.8

                  Slider {
                    steps: 20
                    wheelStep: 1 / steps
                    fillColor: Theme.activeColor
                    radius: Theme.itemRadius * 0.5
                    interactive: true
                    value: streamItem.modelData.audio?.volume ?? 0
                    onCommitted: normalized => {
                      if (streamItem.modelData?.audio) {
                        streamItem.modelData.audio.volume = normalized;
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // Input Volume Section
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: inputCol.implicitHeight + root.cardPadding * 1.5
      radius: Theme.itemRadius
      color: Qt.lighter(Theme.bgColor, 1.35)
      border.width: 1
      border.color: root.borderColor
      visible: root.currentSource !== null

      ColumnLayout {
        id: inputCol
        anchors.fill: parent
        anchors.margins: root.cardPadding
        spacing: root.cardSpacing

        RowLayout {
          Layout.fillWidth: true
          spacing: root.padding

          Text {
            text: root.inputIcon
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 1.2
            color: root.inputIconColor
          }

          OText {
            text: qsTr("Input Volume")
            font.bold: true
            Layout.fillWidth: true
          }

          Text {
            text: root.formatPercentage(root.inputVolume)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            color: Theme.textActiveColor
          }

          IconButton {
            Layout.preferredWidth: root.actionButtonSize
            Layout.preferredHeight: root.actionButtonSize
            icon: root.inputIcon
            colorBg: root.inputMuted ? Theme.inactiveColor : Theme.activeColor
            tooltipText: root.inputMuted ? qsTr("Unmute Mic") : qsTr("Mute Mic")
            onClicked: AudioService.toggleMicMute()
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: root.sliderHeight

          Slider {
            id: inputVolumeSlider
            steps: 30
            wheelStep: 1 / steps
            fillColor: Theme.activeColor
            radius: Theme.itemRadius
            interactive: true
            onCommitted: normalized => {
              if (root.currentSource?.audio) {
                root.currentSource.audio.volume = normalized;
              }
            }
          }
        }
      }
    }

    // Output Devices Section
    ColumnLayout {
      Layout.fillWidth: true
      spacing: root.padding * 0.5

      OText {
        text: qsTr("Output Devices")
        font.bold: true
        color: Theme.textActiveColor
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: sinkList.implicitHeight + root.padding * 1.2
        radius: Theme.itemRadius
        color: Qt.lighter(Theme.bgColor, 1.25)
        border.width: 1
        border.color: root.borderColor
        clip: true

        ListView {
          id: sinkList
          anchors.fill: parent
          anchors.margins: root.padding * 0.6
          spacing: 4
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          implicitHeight: Math.min(contentHeight, Theme.itemHeight * 4)
          interactive: contentHeight > height
          model: root.buildDeviceList(root.sinks, root.currentSink, "󰓃")

          ScrollBar.vertical: ScrollBar {
            policy: sinkList.contentHeight > sinkList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 8
          }

          delegate: DeviceItem {
            width: ListView.view.width
            onClicked: node => {
              AudioService.setAudioSink(node);
            }
          }
        }
      }
    }

    // Input Devices Section
    ColumnLayout {
      Layout.fillWidth: true
      Layout.bottomMargin: root.padding
      spacing: root.padding * 0.5
      visible: sourceList.count > 0

      OText {
        text: qsTr("Input Devices")
        font.bold: true
        color: Theme.textActiveColor
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: sourceList.implicitHeight + root.padding * 1.2
        radius: Theme.itemRadius
        color: Qt.lighter(Theme.bgColor, 1.25)
        border.width: 1
        border.color: root.borderColor
        clip: true

        ListView {
          id: sourceList
          anchors.fill: parent
          anchors.margins: root.padding * 0.6
          spacing: 4
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          implicitHeight: Math.min(contentHeight, Theme.itemHeight * 4)
          interactive: contentHeight > height
          model: root.buildDeviceList(root.sources, root.currentSource, "󰍬")

          ScrollBar.vertical: ScrollBar {
            policy: sourceList.contentHeight > sourceList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 8
          }

          delegate: DeviceItem {
            width: ListView.view.width
            onClicked: node => {
              AudioService.setAudioSource(node);
            }
          }
        }
      }
    }
  }

  component DeviceItem: Item {
    id: deviceItem
    required property var modelData

    readonly property var node: deviceItem.modelData.node
    readonly property color textColor: deviceItem.hovered ? Theme.textOnHoverColor : Theme.textActiveColor

    property bool hovered: false

    signal clicked(var node)

    height: Theme.itemHeight

    Rectangle {
      anchors.fill: parent
      color: deviceItem.hovered ? Theme.onHoverColor : (deviceItem.modelData.isActive ? Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.15) : "transparent")
      radius: Theme.itemRadius
      border.width: deviceItem.modelData.isActive ? 1 : 0
      border.color: Theme.activeColor

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: deviceItem.hovered = true
      onExited: deviceItem.hovered = false
      onClicked: deviceItem.clicked(deviceItem.node)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        spacing: root.padding

        Text {
          text: deviceItem.modelData.icon || ""
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: deviceItem.modelData.isActive ? Theme.activeColor : deviceItem.textColor
        }

        Text {
          text: deviceItem.modelData.name || ""
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: deviceItem.textColor
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          visible: deviceItem.modelData.isActive
          text: "󰄬"
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize * 0.9
          color: Theme.activeColor
        }
      }
    }
  }
}
