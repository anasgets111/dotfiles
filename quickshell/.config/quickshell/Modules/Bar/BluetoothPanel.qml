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
  readonly property bool bluetoothEnabled: BluetoothService.enabled
  readonly property color borderColor: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
  readonly property int cardPadding: padding * 0.9
  readonly property int cardSpacing: padding * 0.4
  readonly property bool discoverable: BluetoothService.discoverable
  readonly property bool discovering: BluetoothService.discovering
  readonly property int iconSize: itemHeight * 0.9
  readonly property int itemHeight: Theme.itemHeight
  readonly property int padding: 8
  readonly property bool ready: BluetoothService.available
  property string showCodecFor: ""

  function buildDeviceList() {
    if (!ready)
      return [];

    const sortedDevices = BluetoothService.sortDevices(BluetoothService.devices);
    return sortedDevices.map(device => {
      const addr = device.address || "";
      const isAudio = BluetoothService.isAudioDevice(device);

      return {
        device: device,
        address: addr,
        name: BluetoothService.getDeviceName(device) || qsTr("Unknown Device"),
        icon: BluetoothService.getDeviceIcon(device),
        connected: device.connected || false,
        paired: device.paired || false,
        trusted: device.trusted || false,
        battery: device.batteryAvailable && device.battery > 0 ? device.battery : -1,
        statusText: BluetoothService.getStatusString(device),
        isBusy: BluetoothService.isDeviceBusy(device),
        canConnect: BluetoothService.canConnect(device),
        canDisconnect: BluetoothService.canDisconnect(device),
        isAudio: isAudio,
        currentCodec: BluetoothService.deviceCodecs[addr] || "",
        availableCodecs: BluetoothService.deviceAvailableCodecs[addr] || [],
        showCodecSelector: showCodecFor === addr
      };
    });
  }

  function handleAction(action: string, device: var) {
    switch (action) {
    case "connect":
      BluetoothService.connectDeviceWithTrust(device);
      break;
    case "disconnect":
      BluetoothService.disconnectDevice(device);
      break;
    case "forget":
      BluetoothService.forgetDevice(device);
      break;
    case "toggle-codec":
      const addr = device?.address || "";
      if (showCodecFor === addr) {
        showCodecFor = "";
      } else {
        showCodecFor = addr;
        BluetoothService.getAvailableCodecs(device);
      }
      break;
    default:
      if (action.startsWith("switch-codec-")) {
        const profile = action.substring(13);
        BluetoothService.switchCodec(device, profile);
        showCodecFor = "";
      }
      break;
    }
  }

  function syncToggles() {
    bluetoothToggle.checked = BluetoothService.enabled;
    discoverableToggle.checked = BluetoothService.discoverable;
  }

  needsKeyboardFocus: false
  panelNamespace: "obelisk-bluetooth-panel"
  panelWidth: 400

  Component.onCompleted: syncToggles()
  onPanelClosed: {
    showCodecFor = "";
    BluetoothService.stopDiscovery();
  }
  onPanelOpened: {
    if (ready && bluetoothEnabled) {
      BluetoothService.startDiscovery();
    }
  }

  Connections {
    function onDiscoverableChanged() {
      root.syncToggles();
    }

    function onEnabledChanged() {
      root.syncToggles();
    }

    target: BluetoothService
  }

  ColumnLayout {
    spacing: 4
    width: parent.width - root.padding * 2
    x: root.padding
    y: root.padding

    // Toggle Cards Row
    RowLayout {
      Layout.bottomMargin: root.bluetoothEnabled ? 0 : root.padding * 2
      Layout.fillWidth: true
      spacing: root.padding * 1.25

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: btCol.implicitHeight + root.cardPadding * 1.3
        border.color: root.borderColor
        border.width: 1
        color: Qt.lighter(Theme.bgColor, 1.35)
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
            color: root.ready ? Theme.textActiveColor : Theme.textInactiveColor
            font.bold: true
            text: qsTr("Bluetooth")
          }

          RowLayout {
            spacing: root.cardPadding

            Rectangle {
              border.color: Qt.rgba(0, 0, 0, 0.12)
              border.width: 1
              color: root.ready && root.bluetoothEnabled ? Theme.activeColor : Theme.inactiveColor
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
                color: root.ready && root.bluetoothEnabled ? "#FFFFFF" : Theme.textInactiveColor
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
              disabled: !root.ready

              onToggled: checked => BluetoothService.setBluetoothEnabled(checked)
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: discoverableCol.implicitHeight + root.cardPadding * 1.3
        border.color: root.borderColor
        border.width: 1
        color: Qt.lighter(Theme.bgColor, 1.35)
        radius: Theme.itemRadius
        visible: root.ready && root.bluetoothEnabled

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
            color: root.ready && root.bluetoothEnabled ? Theme.textActiveColor : Theme.textInactiveColor
            font.bold: true
            text: qsTr("Discoverable")
          }

          RowLayout {
            spacing: root.cardPadding

            Rectangle {
              border.color: Qt.rgba(0, 0, 0, 0.12)
              border.width: 1
              color: root.ready && root.bluetoothEnabled && root.discoverable ? Qt.lighter(Theme.onHoverColor, 1.25) : Qt.darker(Theme.inactiveColor, 1.1)
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
                color: root.ready && root.bluetoothEnabled ? Theme.textContrast(parent.color) : Theme.textInactiveColor
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
              disabled: !root.ready || !root.bluetoothEnabled

              onToggled: checked => BluetoothService.setDiscoverable(checked)
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
      color: Qt.lighter(Theme.bgColor, 1.35)
      radius: Theme.itemRadius
      visible: root.ready && root.bluetoothEnabled

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
            color: root.ready && root.bluetoothEnabled && root.discovering ? Qt.lighter("#A6E3A1", 1.15) : Qt.darker(Theme.inactiveColor, 1.1)
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
              color: root.ready && root.bluetoothEnabled ? Theme.textContrast(parent.color) : Theme.textInactiveColor
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize * 0.95
              text: "󰀘"

              RotationAnimation on rotation {
                duration: 2000
                from: 0
                loops: Animation.Infinite
                running: root.discovering
                to: 360
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            OText {
              color: root.ready && root.bluetoothEnabled ? Theme.textActiveColor : Theme.textInactiveColor
              font.bold: true
              text: qsTr("Discovery")
            }

            OText {
              color: Theme.textInactiveColor
              font.pixelSize: Theme.fontSize * 0.85
              text: root.discovering ? qsTr("Scanning for devices…") : qsTr("No active scan")
              visible: root.ready && root.bluetoothEnabled
            }
          }
        }
      }
    }

    // Device List
    Rectangle {
      Layout.bottomMargin: root.padding * 2
      Layout.fillWidth: true
      Layout.topMargin: root.padding
      border.color: root.borderColor
      border.width: 1
      clip: true
      color: Qt.lighter(Theme.bgColor, 1.25)
      implicitHeight: visible ? deviceList.implicitHeight + root.padding * 1.4 : 0
      radius: Theme.itemRadius
      visible: root.ready && root.bluetoothEnabled && deviceList.count > 0

      ListView {
        id: deviceList

        anchors.fill: parent
        anchors.margins: root.padding * 0.8
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        implicitHeight: {
          const itemCount = deviceList.count;
          const displayCount = Math.min(itemCount, 4);
          return displayCount * root.itemHeight * 1.5 + (displayCount - 1) * 4;
        }
        interactive: contentHeight > height
        model: root.buildDeviceList()
        spacing: 4

        ScrollBar.vertical: ScrollBar {
          policy: deviceList.contentHeight > deviceList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
          width: 8
        }
        delegate: DeviceItem {
          width: ListView.view.width

          onTriggered: (action, device) => {
            root.handleAction(action, device);
          }
        }
      }
    }
  }

  component DeviceItem: Item {
    id: deviceItem

    readonly property var device: deviceItem.modelData.device
    property bool hovered: false
    required property var modelData
    readonly property color textColor: deviceItem.hovered ? Theme.textOnHoverColor : Theme.textActiveColor

    signal triggered(string action, var device)

    height: {
      let h = Theme.itemHeight;
      if (deviceItem.modelData.showCodecSelector && deviceItem.modelData.availableCodecs.length > 0) {
        h += deviceItem.modelData.availableCodecs.length * (Theme.itemHeight * 0.8) + root.padding;
      }
      return h;
    }

    Behavior on height {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }

    Rectangle {
      anchors.fill: parent
      color: deviceItem.hovered ? Theme.onHoverColor : "transparent"
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
        if (deviceItem.modelData.canConnect) {
          deviceItem.triggered("connect", deviceItem.device);
        } else if (deviceItem.modelData.canDisconnect) {
          deviceItem.triggered("disconnect", deviceItem.device);
        }
      }
      onEntered: deviceItem.hovered = true
      onExited: deviceItem.hovered = false

      ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // Main device row
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: Theme.itemHeight
          spacing: 8

          // Device icon
          Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: root.padding
            color: deviceItem.modelData.connected ? Theme.activeColor : deviceItem.textColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: deviceItem.modelData.icon || "󰂯"

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }

          // Device name + status
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              Layout.fillWidth: true
              color: deviceItem.textColor
              elide: Text.ElideRight
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              text: deviceItem.modelData.name || ""

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }
            }

            Text {
              color: Theme.textInactiveColor
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize * 0.75
              text: deviceItem.modelData.statusText || ""
              visible: text !== ""
            }
          }

          // Battery pill (only for connected devices with battery)
          Rectangle {
            Layout.preferredHeight: Theme.itemHeight * 0.6
            Layout.preferredWidth: Theme.itemHeight * 2
            color: {
              const level = deviceItem.modelData.battery;
              if (level <= 0.1)
                return Theme.critical;
              if (level <= 0.2)
                return Theme.warning;
              return Theme.activeColor;
            }
            radius: height / 2
            visible: deviceItem.modelData.battery >= 0

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }

            Text {
              anchors.centerIn: parent
              color: Theme.textContrast(parent.color)
              font.bold: true
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize * 0.7
              text: Math.round(deviceItem.modelData.battery * 100) + "%"
            }
          }

          // Codec button (for audio devices when connected)
          IconButton {
            Layout.preferredHeight: root.actionButtonSize
            Layout.preferredWidth: root.actionButtonSize
            colorBg: deviceItem.modelData.showCodecSelector ? Theme.activeColor : Theme.onHoverColor
            icon: "󰓃"
            tooltipText: deviceItem.modelData.currentCodec ? qsTr("Codec: %1").arg(deviceItem.modelData.currentCodec) : qsTr("Select Codec")
            visible: deviceItem.modelData.isAudio && deviceItem.modelData.connected

            onClicked: deviceItem.triggered("toggle-codec", deviceItem.device)
          }

          // Forget button
          IconButton {
            Layout.preferredHeight: root.actionButtonSize
            Layout.preferredWidth: root.actionButtonSize
            colorBg: "#F38BA8"
            icon: "󰩺"
            tooltipText: qsTr("Forget Device")
            visible: deviceItem.modelData.paired || deviceItem.modelData.trusted

            onClicked: deviceItem.triggered("forget", deviceItem.device)
          }

          // Connect/Disconnect button
          IconButton {
            Layout.preferredHeight: root.actionButtonSize
            Layout.preferredWidth: root.actionButtonSize
            Layout.rightMargin: root.padding
            colorBg: deviceItem.modelData.connected ? "#F9E2AF" : Theme.activeColor
            enabled: deviceItem.modelData.canConnect || deviceItem.modelData.canDisconnect
            icon: deviceItem.modelData.connected ? "󱘖" : "󰌘"
            tooltipText: deviceItem.modelData.connected ? qsTr("Disconnect") : qsTr("Connect")
            visible: !deviceItem.modelData.isBusy

            onClicked: deviceItem.triggered(deviceItem.modelData.connected ? "disconnect" : "connect", deviceItem.device)
          }

          // Busy indicator
          Text {
            Layout.rightMargin: root.padding
            color: Theme.activeColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: "󰇙"
            visible: deviceItem.modelData.isBusy

            RotationAnimation on rotation {
              duration: 1000
              from: 0
              loops: Animation.Infinite
              running: deviceItem.modelData.isBusy
              to: 360
            }
          }
        }

        // Codec selector (expanded)
        ColumnLayout {
          Layout.fillWidth: true
          Layout.leftMargin: root.padding * 2
          Layout.rightMargin: root.padding
          spacing: 2
          visible: deviceItem.modelData.showCodecSelector && deviceItem.modelData.availableCodecs.length > 0

          Repeater {
            model: deviceItem.modelData.availableCodecs

            delegate: Rectangle {
              id: codecDelegate

              required property int index
              required property var modelData

              Layout.fillWidth: true
              Layout.preferredHeight: Theme.itemHeight * 0.8
              color: codecMouseArea.containsMouse ? Theme.onHoverColor : "transparent"
              radius: Theme.itemRadius

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.padding
                anchors.rightMargin: root.padding
                spacing: 8

                Rectangle {
                  color: codecDelegate.modelData.qualityColor || Theme.inactiveColor
                  implicitHeight: 8
                  implicitWidth: 8
                  radius: 4
                }

                Text {
                  Layout.fillWidth: true
                  color: codecMouseArea.containsMouse ? Theme.textOnHoverColor : Theme.textActiveColor
                  font.bold: codecDelegate.modelData.name === deviceItem.modelData.currentCodec
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize * 0.85
                  text: codecDelegate.modelData.name || ""
                }

                Text {
                  color: Theme.textInactiveColor
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize * 0.75
                  text: codecDelegate.modelData.description || ""
                }

                Text {
                  color: Theme.activeColor
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize * 0.8
                  text: "󰄬"
                  visible: codecDelegate.modelData.name === deviceItem.modelData.currentCodec
                }
              }

              MouseArea {
                id: codecMouseArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: {
                  if (codecDelegate.modelData.name !== deviceItem.modelData.currentCodec) {
                    deviceItem.triggered("switch-codec-" + codecDelegate.modelData.profile, deviceItem.device);
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
