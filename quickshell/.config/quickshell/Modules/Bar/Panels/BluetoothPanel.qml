pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Core

OPanel {
  id: root

  readonly property int actionButtonSize: itemHeight * 0.8
  readonly property bool active: BluetoothService.available && BluetoothService.enabled
  readonly property color borderColor: Theme.borderLight
  readonly property int cardPadding: padding * 0.9
  readonly property int cardSpacing: padding * 0.4
  readonly property int iconSize: itemHeight * 0.9
  readonly property int itemHeight: Theme.itemHeight
  readonly property int padding: Theme.spacingSm
  readonly property bool ready: BluetoothService.available
  property string showCodecFor: ""

  function handleAction(action: string, device: var) {
    switch (action) {
    case "connect":
      BluetoothService.connectDevice(device);
      break;
    case "disconnect":
      BluetoothService.disconnectDevice(device);
      break;
    case "forget":
      BluetoothService.forgetDevice(device);
      break;
    case "toggle-codec":
      const addr = device?.address || "";
      showCodecFor = showCodecFor === addr ? "" : addr;
      if (showCodecFor)
        BluetoothService.fetchCodecs(device);
      break;
    default:
      if (action.startsWith("codec:")) {
        BluetoothService.switchCodec(device, action.substring(6));
        showCodecFor = "";
      }
    }
  }

  needsKeyboardFocus: false
  panelNamespace: "obelisk-bluetooth-panel"
  panelWidth: 400

  onPanelClosed: {
    showCodecFor = "";
    BluetoothService.stopDiscovery();
  }
  onPanelOpened: {
    if (active) {
      BluetoothService.startDiscovery();
    }
  }

  ColumnLayout {
    spacing: Theme.spacingXs
    width: parent.width - root.padding * 2
    x: root.padding
    y: root.padding

    // Toggle Cards Row
    RowLayout {
      Layout.fillWidth: true
      spacing: root.padding * 1.25

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: btCol.implicitHeight + root.cardPadding * 1.3
        border.color: root.borderColor
        border.width: 1
        color: Theme.bgElevated
        opacity: root.ready ? 1 : 0.5
        radius: Theme.itemRadius

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
          }
        }

        ColumnLayout {
          id: btCol

          anchors.fill: parent
          anchors.margins: root.cardPadding
          spacing: root.cardSpacing

          OText {
            bold: true
            color: root.ready ? Theme.textActiveColor : Theme.textInactiveColor
            text: qsTr("Bluetooth")
          }

          RowLayout {
            spacing: root.cardPadding

            Rectangle {
              border.color: Qt.rgba(0, 0, 0, 0.12)
              border.width: 1
              color: root.ready && BluetoothService.enabled ? Theme.activeColor : Theme.inactiveColor
              implicitHeight: root.iconSize
              implicitWidth: root.iconSize
              radius: height / 2

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }

              Text {
                anchors.centerIn: parent
                color: root.ready && BluetoothService.enabled ? Theme.textActiveColor : Theme.textInactiveColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.95
                text: "󰂯"
              }
            }

            Item {
              Layout.fillWidth: true
            }

            OToggle {
              id: bluetoothToggle

              Layout.preferredHeight: Theme.itemHeight * 0.72
              Layout.preferredWidth: Theme.itemHeight * 2.6
              checked: BluetoothService.enabled
              disabled: !root.ready

              onToggled: checked => {
                if (!checked)
                  BluetoothService.stopDiscovery();
                BluetoothService.setEnabled(checked);
                Qt.callLater(() => bluetoothToggle.checked = BluetoothService.enabled);
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: discoverableCol.implicitHeight + root.cardPadding * 1.3
        border.color: root.borderColor
        border.width: 1
        color: Theme.bgElevated
        radius: Theme.itemRadius
        visible: root.active

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
          }
        }

        ColumnLayout {
          id: discoverableCol

          anchors.fill: parent
          anchors.margins: root.cardPadding
          spacing: root.cardSpacing

          OText {
            bold: true
            color: root.active ? Theme.textActiveColor : Theme.textInactiveColor
            text: qsTr("Discoverable")
          }

          RowLayout {
            spacing: root.cardPadding

            Rectangle {
              border.color: Qt.rgba(0, 0, 0, 0.12)
              border.width: 1
              color: root.active && BluetoothService.discoverable ? Qt.lighter(Theme.onHoverColor, 1.25) : Qt.darker(Theme.inactiveColor, 1.1)
              implicitHeight: root.iconSize
              implicitWidth: root.iconSize
              radius: height / 2

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }

              Text {
                anchors.centerIn: parent
                color: root.active ? Theme.textContrast(parent.color) : Theme.textInactiveColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.95
                text: "󰐾"
              }
            }

            Item {
              Layout.fillWidth: true
            }

            OToggle {
              id: discoverableToggle

              Layout.preferredHeight: Theme.itemHeight * 0.72
              Layout.preferredWidth: Theme.itemHeight * 2.6
              checked: BluetoothService.discoverable
              disabled: !root.active

              onToggled: checked => {
                BluetoothService.setDiscoverable(checked);
                Qt.callLater(() => discoverableToggle.checked = BluetoothService.discoverable);
              }
            }
          }
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: discoveryCol.implicitHeight + root.cardPadding * 1.3
      Layout.topMargin: root.padding * 0.5
      border.color: root.borderColor
      border.width: 1
      color: Theme.bgElevated
      radius: Theme.itemRadius
      visible: root.active

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animationDuration
        }
      }

      ColumnLayout {
        id: discoveryCol

        anchors.fill: parent
        anchors.margins: root.cardPadding
        spacing: root.cardSpacing

        RowLayout {
          Layout.fillWidth: true
          spacing: root.cardPadding

          Rectangle {
            border.color: Qt.rgba(0, 0, 0, 0.12)
            border.width: 1
            color: root.active && BluetoothService.discovering ? Qt.lighter(Theme.powerSaveColor, 1.15) : Qt.darker(Theme.inactiveColor, 1.1)
            implicitHeight: root.iconSize
            implicitWidth: root.iconSize
            radius: height / 2

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }

            Text {
              anchors.centerIn: parent
              color: root.active ? Theme.textContrast(parent.color) : Theme.textInactiveColor
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize * 0.95
              text: "󰀘"

              RotationAnimation on rotation {
                duration: 2000
                from: 0
                loops: Animation.Infinite
                running: BluetoothService.discovering
                to: 360
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXs / 2

            OText {
              bold: true
              color: root.active ? Theme.textActiveColor : Theme.textInactiveColor
              text: qsTr("Discovery")
            }

            OText {
              color: Theme.textInactiveColor
              size: "sm"
              text: BluetoothService.discovering ? qsTr("Scanning for devices…") : qsTr("No active scan")
              visible: root.active
            }
          }
        }
      }
    }

    // Device List
    Rectangle {
      Layout.fillWidth: true
      Layout.topMargin: root.padding * 0.5
      border.color: root.borderColor
      border.width: 1
      clip: true
      color: Theme.bgElevatedAlt
      implicitHeight: visible ? deviceList.contentHeight + root.cardPadding * 2 : 0
      radius: Theme.itemRadius
      visible: root.active && deviceList.count > 0

      ListView {
        id: deviceList

        readonly property int maxVisibleItems: 4

        anchors.fill: parent
        anchors.margins: root.cardPadding
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        implicitHeight: Math.min(contentHeight, maxVisibleItems * root.itemHeight + (maxVisibleItems - 1) * spacing)
        interactive: contentHeight > height
        model: root.ready ? BluetoothService.sortedDevices : []
        reuseItems: true
        spacing: Theme.spacingXs

        ScrollBar.vertical: ScrollBar {
          policy: deviceList.contentHeight > deviceList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
          width: Theme.scrollBarWidth
        }
        delegate: DeviceItem {
          width: ListView.view.width

          onTriggered: (action, dev) => root.handleAction(action, dev)
        }
      }
    }

    // Bottom spacer for padding (needs extra to account for y offset)
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.padding * 1.5
    }
  }

  component CodecItem: Item {
    id: codecItem

    required property string currentCodec
    required property int index
    readonly property bool isCurrent: modelData.name === currentCodec
    readonly property bool isHovered: codecMouse.containsMouse
    required property var modelData

    signal selected(string profile)

    Layout.fillWidth: true
    Layout.preferredHeight: Theme.itemHeight * 0.8

    Rectangle {
      anchors.fill: parent
      border.color: codecItem.isCurrent ? Theme.activeColor : "transparent"
      border.width: codecItem.isCurrent ? 1 : 0
      color: codecItem.isCurrent ? Theme.activeSubtle : (codecItem.isHovered ? Theme.borderLight : "transparent")
      radius: Theme.itemRadius

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: root.padding
      anchors.rightMargin: root.padding
      spacing: Theme.spacingSm

      Rectangle {
        color: codecItem.modelData.qualityColor || Theme.inactiveColor
        implicitHeight: Theme.spacingSm
        implicitWidth: Theme.spacingSm
        opacity: codecItem.isCurrent || codecItem.isHovered ? 1 : Theme.opacityDisabled
        radius: Theme.radiusXs
      }

      OText {
        Layout.fillWidth: true
        bold: codecItem.isCurrent || codecItem.isHovered
        color: codecItem.isCurrent ? Theme.activeColor : (codecItem.isHovered ? Theme.textActiveColor : Theme.textInactiveColor)
        opacity: codecItem.isCurrent || codecItem.isHovered ? 1 : 0.7
        size: "sm"
        text: codecItem.modelData.name || ""
      }

      OText {
        color: codecItem.isCurrent ? Theme.activeColor : (codecItem.isHovered ? Theme.textActiveColor : Theme.textInactiveColor)
        opacity: codecItem.isCurrent || codecItem.isHovered ? 1 : 0.6
        size: "xs"
        text: codecItem.modelData.description || ""
      }

      Rectangle {
        Layout.preferredHeight: Theme.controlHeightXs
        Layout.preferredWidth: Theme.controlHeightXs
        border.color: codecItem.isCurrent ? Theme.activeColor : "transparent"
        border.width: Theme.borderWidthMedium
        color: codecItem.isCurrent ? Theme.activeColor : "transparent"
        radius: Theme.radiusMd

        OText {
          anchors.centerIn: parent
          bold: true
          color: Theme.bgColor
          size: "sm"
          text: "✓"
          visible: codecItem.isCurrent
        }
      }
    }

    MouseArea {
      id: codecMouse

      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true

      onClicked: if (!codecItem.isCurrent)
        codecItem.selected(codecItem.modelData.profile)
    }
  }
  component DeviceItem: Item {
    id: deviceItem

    readonly property string addr: device?.address || ""
    readonly property var availableCodecs: BluetoothService.deviceAvailableCodecs[addr] || []
    readonly property real batteryLevel: hasBattery ? device.battery : -1
    readonly property string batteryStr: BluetoothService.getBattery(device)
    readonly property bool canConnect: device && !device.connected && !isBusy && !device.blocked
    readonly property bool canDisconnect: device && device.connected && !isBusy
    readonly property string currentCodec: BluetoothService.deviceCodecs[addr] || ""
    readonly property var device: modelData
    readonly property bool hasBattery: device?.batteryAvailable && device.battery > 0
    property bool hovered: false
    readonly property string icon: BluetoothService.getDeviceIcon(device)
    readonly property bool isAudio: BluetoothService.isAudioDevice(device)
    readonly property bool isBusy: BluetoothService.isDeviceBusy(device)
    readonly property bool isConnected: device?.connected || false
    readonly property bool isPaired: device?.paired || device?.trusted || false
    required property var modelData
    readonly property string name: BluetoothService.getDeviceName(device) || qsTr("Unknown Device")
    readonly property bool showCodecSelector: root.showCodecFor === addr && availableCodecs.length > 0
    readonly property string statusText: BluetoothService.getStatusString(device)
    readonly property color textColor: hovered ? Theme.textOnHoverColor : Theme.textActiveColor

    signal triggered(string action, var device)

    height: Theme.itemHeight + (showCodecSelector ? availableCodecs.length * (Theme.itemHeight * 0.8) + root.padding : 0)

    Behavior on height {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }

    Rectangle {
      anchors.fill: parent
      color: (deviceItem.hovered && !deviceItem.showCodecSelector) ? Theme.borderMedium : "transparent"
      radius: Theme.itemRadius

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

      onClicked: {
        if (deviceItem.canConnect)
          deviceItem.triggered("connect", deviceItem.device);
        else if (deviceItem.canDisconnect)
          deviceItem.triggered("disconnect", deviceItem.device);
      }
      onEntered: deviceItem.hovered = true
      onExited: deviceItem.hovered = false

      ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingXs

        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: Theme.itemHeight
          spacing: Theme.spacingSm

          Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: root.padding
            color: deviceItem.isConnected ? Theme.activeColor : deviceItem.textColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: deviceItem.icon

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true

            OText {
              Layout.fillWidth: true
              color: deviceItem.textColor
              elide: Text.ElideRight
              text: deviceItem.name

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }
            }

            OText {
              color: Theme.textInactiveColor
              size: "xs"
              text: deviceItem.statusText
              visible: text !== ""
            }
          }

          Rectangle {
            Layout.preferredHeight: Theme.itemHeight * 0.6
            Layout.preferredWidth: Theme.itemHeight * 2
            color: deviceItem.batteryLevel <= 0.1 ? Theme.critical : (deviceItem.batteryLevel <= 0.2 ? Theme.warning : Theme.activeColor)
            radius: height / 2
            visible: deviceItem.hasBattery

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }

            OText {
              anchors.centerIn: parent
              bold: true
              color: Theme.textContrast(parent.color)
              size: "xs"
              text: deviceItem.batteryStr
            }
          }

          IconButton {
            Layout.preferredHeight: root.actionButtonSize
            Layout.preferredWidth: root.actionButtonSize
            colorBg: deviceItem.showCodecSelector ? Theme.activeColor : Theme.onHoverColor
            icon: "󰓃"
            tooltipText: deviceItem.currentCodec ? qsTr("Codec: %1").arg(deviceItem.currentCodec) : qsTr("Select Codec")
            visible: deviceItem.isAudio && deviceItem.isConnected

            onClicked: deviceItem.triggered("toggle-codec", deviceItem.device)
          }

          IconButton {
            Layout.preferredHeight: root.actionButtonSize
            Layout.preferredWidth: root.actionButtonSize
            colorBg: Theme.critical
            icon: "󰩺"
            tooltipText: qsTr("Forget Device")
            visible: deviceItem.isPaired

            onClicked: deviceItem.triggered("forget", deviceItem.device)
          }

          IconButton {
            Layout.preferredHeight: root.actionButtonSize
            Layout.preferredWidth: root.actionButtonSize
            Layout.rightMargin: root.padding
            colorBg: deviceItem.isConnected ? Theme.warning : Theme.activeColor
            enabled: deviceItem.canConnect || deviceItem.canDisconnect
            icon: deviceItem.isConnected ? "󱘖" : "󰌘"
            tooltipText: deviceItem.isConnected ? qsTr("Disconnect") : qsTr("Connect")
            visible: !deviceItem.isBusy

            onClicked: deviceItem.triggered(deviceItem.isConnected ? "disconnect" : "connect", deviceItem.device)
          }

          Text {
            Layout.rightMargin: root.padding
            color: Theme.activeColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: "󰇙"
            visible: deviceItem.isBusy

            RotationAnimation on rotation {
              duration: 1000
              from: 0
              loops: Animation.Infinite
              running: deviceItem.isBusy
              to: 360
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.leftMargin: root.padding * 2
          Layout.rightMargin: root.padding
          spacing: Theme.spacingXs / 2
          visible: deviceItem.showCodecSelector

          Repeater {
            model: deviceItem.availableCodecs

            delegate: CodecItem {
              currentCodec: deviceItem.currentCodec

              onSelected: profile => deviceItem.triggered("codec:" + profile, deviceItem.device)
            }
          }
        }
      }
    }
  }
}
