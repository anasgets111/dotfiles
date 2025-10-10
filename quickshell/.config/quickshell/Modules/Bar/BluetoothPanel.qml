pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Components
import qs.Services.Core
import qs.Services.Utils

OPanel {
  id: root

  readonly property bool ready: BluetoothService.available
  readonly property bool bluetoothEnabled: BluetoothService.enabled
  readonly property bool discovering: BluetoothService.discovering
  readonly property bool discoverable: BluetoothService.discoverable
  readonly property var devices: BluetoothService.devices || []
  readonly property var sortedDevices: BluetoothService.sortDevices(devices)

  property string showCodecFor: ""

  readonly property int minItems: 4
  readonly property int maxItems: 4
  readonly property int itemHeight: Theme.itemHeight
  readonly property int padding: 8

  panelWidth: 400
  needsKeyboardFocus: false

  onPanelOpened: {
    if (ready && bluetoothEnabled) {
      BluetoothService.startDiscovery();
    }
  }

  onPanelClosed: {
    showCodecFor = "";
    BluetoothService.stopDiscovery();
  }

  Connections {
    target: BluetoothService

    function onEnabledChanged() {
      root.syncToggles();
    }

    function onDiscoverableChanged() {
      root.syncToggles();
    }
  }

  Component.onCompleted: syncToggles()

  function syncToggles() {
    bluetoothToggle.checked = BluetoothService.enabled;
    discoverableToggle.checked = BluetoothService.discoverable;
  }

  function buildDeviceList() {
    if (!ready)
      return [];

    const deviceList = [];
    for (const device of sortedDevices) {
      if (!device)
        continue;

      const addr = device.address || "";
      const isBusy = BluetoothService.isDeviceBusy(device);
      const canConnect = BluetoothService.canConnect(device);
      const canDisconnect = BluetoothService.canDisconnect(device);
      const isAudio = BluetoothService.isAudioDevice(device);
      const currentCodec = BluetoothService.deviceCodecs[addr] || "";
      const availableCodecs = BluetoothService.deviceAvailableCodecs[addr] || [];
      const showCodec = showCodecFor === addr;

      deviceList.push({
        device: device,
        address: addr,
        name: device.name || device.deviceName || qsTr("Unknown Device"),
        icon: BluetoothService.getDeviceIcon(device),
        connected: device.connected || false,
        paired: device.paired || false,
        trusted: device.trusted || false,
        battery: device.batteryAvailable && device.battery > 0 ? device.battery : -1,
        statusText: BluetoothService.getStatusString(device),
        isBusy: isBusy,
        canConnect: canConnect,
        canDisconnect: canDisconnect,
        isAudio: isAudio,
        currentCodec: currentCodec,
        availableCodecs: availableCodecs,
        showCodecSelector: showCodec
      });
    }
    return deviceList;
  }

  function handleAction(action: string, device: var) {
    if (action === "connect") {
      BluetoothService.connectDeviceWithTrust(device);
    } else if (action === "disconnect") {
      BluetoothService.disconnectDevice(device);
    } else if (action === "forget") {
      BluetoothService.forgetDevice(device);
    } else if (action === "toggle-codec") {
      const addr = device?.address || "";
      if (showCodecFor === addr) {
        showCodecFor = "";
      } else {
        showCodecFor = addr;
        BluetoothService.getAvailableCodecs(device);
      }
    } else if (action.startsWith("switch-codec-")) {
      const profile = action.substring(13);
      BluetoothService.switchCodec(device, profile);
      showCodecFor = "";
    }
  }

  ColumnLayout {
    width: parent.width - root.padding * 2
    x: root.padding
    y: root.padding
    spacing: 4

    // Toggle Cards Row
    RowLayout {
      Layout.fillWidth: true
      spacing: root.padding * 1.25

      // Bluetooth Toggle Card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: btCol.implicitHeight + root.padding * 1.2
        radius: Theme.itemRadius
        color: Qt.lighter(Theme.bgColor, 1.35)
        border.width: 1
        border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
        opacity: root.ready ? 1 : 0.5

        Behavior on opacity {
          NumberAnimation {
            duration: 150
          }
        }

        ColumnLayout {
          id: btCol
          anchors.fill: parent
          anchors.margins: root.padding * 0.9
          spacing: root.padding * 0.4

          OText {
            text: qsTr("Bluetooth")
            font.bold: true
            color: root.ready ? Theme.textActiveColor : Theme.textInactiveColor
          }

          RowLayout {
            spacing: root.padding * 0.9

            Rectangle {
              implicitWidth: Theme.itemHeight * 0.9
              implicitHeight: implicitWidth
              radius: height / 2
              color: root.ready && root.bluetoothEnabled ? Qt.lighter(Theme.activeColor, 1.25) : Theme.inactiveColor
              border.width: 1
              border.color: Qt.rgba(0, 0, 0, 0.12)

              Behavior on color {
                ColorAnimation {
                  duration: 150
                }
              }

              Text {
                text: "󰂯"
                anchors.centerIn: parent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.95
                color: root.ready && root.bluetoothEnabled ? Theme.textContrast(parent.color) : Theme.textInactiveColor
              }
            }

            Item {
              Layout.fillWidth: true
            }

            OToggle {
              id: bluetoothToggle
              Layout.preferredWidth: Theme.itemHeight * 2.6
              Layout.preferredHeight: Theme.itemHeight * 0.72
              disabled: !root.ready
              onToggled: checked => BluetoothService.setBluetoothEnabled(checked)
            }
          }
        }
      }

      // Discoverable Toggle Card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: discoverableCol.implicitHeight + root.padding * 1.2
        radius: Theme.itemRadius
        color: Qt.lighter(Theme.bgColor, 1.35)
        border.width: 1
        border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
        opacity: root.ready && root.bluetoothEnabled ? 1 : 0.5

        Behavior on opacity {
          NumberAnimation {
            duration: 150
          }
        }

        ColumnLayout {
          id: discoverableCol
          anchors.fill: parent
          anchors.margins: root.padding * 0.9
          spacing: root.padding * 0.4

          OText {
            text: qsTr("Discoverable")
            font.bold: true
            color: root.ready && root.bluetoothEnabled ? Theme.textActiveColor : Theme.textInactiveColor
          }

          RowLayout {
            spacing: root.padding * 0.9

            Rectangle {
              implicitWidth: Theme.itemHeight * 0.9
              implicitHeight: implicitWidth
              radius: height / 2
              color: root.ready && root.bluetoothEnabled && root.discoverable ? Qt.lighter(Theme.onHoverColor, 1.25) : Qt.darker(Theme.inactiveColor, 1.1)
              border.width: 1
              border.color: Qt.rgba(0, 0, 0, 0.12)

              Behavior on color {
                ColorAnimation {
                  duration: 150
                }
              }

              Text {
                text: "󰐾"
                anchors.centerIn: parent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.95
                color: root.ready && root.bluetoothEnabled ? Theme.textContrast(parent.color) : Theme.textInactiveColor
              }
            }

            Item {
              Layout.fillWidth: true
            }

            OToggle {
              id: discoverableToggle
              Layout.preferredWidth: Theme.itemHeight * 2.6
              Layout.preferredHeight: Theme.itemHeight * 0.72
              disabled: !root.ready || !root.bluetoothEnabled
              onToggled: checked => BluetoothService.setDiscoverable(checked)
            }
          }
        }
      }
    }

    // Discovery Toggle Card (Full Width)
    Rectangle {
      Layout.fillWidth: true
      Layout.topMargin: root.padding * 0.5
      Layout.preferredHeight: discoveryCol.implicitHeight + root.padding * 1.2
      radius: Theme.itemRadius
      color: Qt.lighter(Theme.bgColor, 1.35)
      border.width: 1
      border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
      opacity: root.ready && root.bluetoothEnabled ? 1 : 0.5

      Behavior on opacity {
        NumberAnimation {
          duration: 150
        }
      }

      ColumnLayout {
        id: discoveryCol
        anchors.fill: parent
        anchors.margins: root.padding * 0.9
        spacing: root.padding * 0.4

        RowLayout {
          Layout.fillWidth: true
          spacing: root.padding * 0.9

          Rectangle {
            implicitWidth: Theme.itemHeight * 0.9
            implicitHeight: implicitWidth
            radius: height / 2
            color: root.ready && root.bluetoothEnabled && root.discovering ? Qt.lighter("#A6E3A1", 1.15) : Qt.darker(Theme.inactiveColor, 1.1)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.12)

            Behavior on color {
              ColorAnimation {
                duration: 150
              }
            }

            Text {
              text: "󰀘"
              anchors.centerIn: parent
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize * 0.95
              color: root.ready && root.bluetoothEnabled ? Theme.textContrast(parent.color) : Theme.textInactiveColor

              RotationAnimation on rotation {
                running: root.discovering
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 2000
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            OText {
              text: qsTr("Discovery")
              font.bold: true
              color: root.ready && root.bluetoothEnabled ? Theme.textActiveColor : Theme.textInactiveColor
            }

            OText {
              text: root.discovering ? qsTr("Scanning for devices…") : qsTr("No active scan")
              font.pixelSize: Theme.fontSize * 0.85
              color: Theme.textInactiveColor
              visible: root.ready && root.bluetoothEnabled
            }
          }
        }
      }
    }

    // Device List
    Rectangle {
      Layout.fillWidth: true
      Layout.topMargin: root.padding
      Layout.bottomMargin: root.padding * 2
      radius: Theme.itemRadius
      color: Qt.lighter(Theme.bgColor, 1.25)
      border.width: 1
      border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
      visible: root.ready && root.bluetoothEnabled && deviceList.count > 0
      clip: true
      implicitHeight: visible ? deviceList.implicitHeight + root.padding * 1.4 : 0

      ListView {
        id: deviceList
        anchors.fill: parent
        anchors.margins: root.padding * 0.8
        spacing: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        implicitHeight: {
          const itemCount = deviceList.count;
          const displayCount = Math.max(root.minItems, Math.min(itemCount, root.maxItems));
          return displayCount * root.itemHeight * 1.5 + (displayCount - 1) * 4;
        }
        interactive: contentHeight > height
        model: root.buildDeviceList()

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
    required property var modelData

    readonly property var device: deviceItem.modelData.device
    readonly property color textColor: deviceItem.hovered ? Theme.textOnHoverColor : Theme.textActiveColor

    property bool hovered: false

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
      onEntered: deviceItem.hovered = true
      onExited: deviceItem.hovered = false
      onClicked: {
        if (deviceItem.modelData.canConnect) {
          deviceItem.triggered("connect", deviceItem.device);
        } else if (deviceItem.modelData.canDisconnect) {
          deviceItem.triggered("disconnect", deviceItem.device);
        }
      }

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
            text: deviceItem.modelData.icon || "󰂯"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: deviceItem.modelData.connected ? Theme.activeColor : deviceItem.textColor
            Layout.leftMargin: root.padding
            Layout.alignment: Qt.AlignVCenter

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
              text: deviceItem.modelData.name || ""
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              color: deviceItem.textColor
              elide: Text.ElideRight
              Layout.fillWidth: true

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }
            }

            Text {
              text: deviceItem.modelData.statusText || ""
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize * 0.75
              color: Theme.textInactiveColor
              visible: text !== ""
            }
          }

          // Battery pill (only for connected devices with battery)
          Rectangle {
            visible: deviceItem.modelData.battery >= 0
            Layout.preferredWidth: Theme.itemHeight * 2
            Layout.preferredHeight: Theme.itemHeight * 0.6
            radius: height / 2
            color: {
              const level = deviceItem.modelData.battery;
              if (level <= 0.1)
                return Theme.critical;
              if (level <= 0.2)
                return Theme.warning;
              return Theme.activeColor;
            }

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }

            Text {
              anchors.centerIn: parent
              text: Math.round(deviceItem.modelData.battery * 100) + "%"
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize * 0.7
              font.bold: true
              color: Theme.textContrast(parent.color)
            }
          }

          // Codec button (for audio devices when connected)
          IconButton {
            visible: deviceItem.modelData.isAudio && deviceItem.modelData.connected
            Layout.preferredWidth: Theme.itemHeight * 0.8
            Layout.preferredHeight: Theme.itemHeight * 0.8
            icon: "󰓃"
            colorBg: deviceItem.modelData.showCodecSelector ? Theme.activeColor : Theme.onHoverColor
            tooltipText: deviceItem.modelData.currentCodec ? qsTr("Codec: %1").arg(deviceItem.modelData.currentCodec) : qsTr("Select Codec")
            onClicked: deviceItem.triggered("toggle-codec", deviceItem.device)
          }

          // Forget button
          IconButton {
            visible: deviceItem.modelData.paired || deviceItem.modelData.trusted
            Layout.preferredWidth: Theme.itemHeight * 0.8
            Layout.preferredHeight: Theme.itemHeight * 0.8
            icon: "󰩺"
            colorBg: "#F38BA8"
            tooltipText: qsTr("Forget Device")
            onClicked: deviceItem.triggered("forget", deviceItem.device)
          }

          // Connect/Disconnect button
          IconButton {
            visible: !deviceItem.modelData.isBusy
            enabled: deviceItem.modelData.canConnect || deviceItem.modelData.canDisconnect
            Layout.preferredWidth: Theme.itemHeight * 0.8
            Layout.preferredHeight: Theme.itemHeight * 0.8
            Layout.rightMargin: root.padding
            icon: deviceItem.modelData.connected ? "󱘖" : "󰌘"
            colorBg: deviceItem.modelData.connected ? "#F9E2AF" : Theme.activeColor
            tooltipText: deviceItem.modelData.connected ? qsTr("Disconnect") : qsTr("Connect")
            onClicked: deviceItem.triggered(deviceItem.modelData.connected ? "disconnect" : "connect", deviceItem.device)
          }

          // Busy indicator
          Text {
            visible: deviceItem.modelData.isBusy
            text: "󰇙"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.activeColor
            Layout.rightMargin: root.padding

            RotationAnimation on rotation {
              running: deviceItem.modelData.isBusy
              loops: Animation.Infinite
              from: 0
              to: 360
              duration: 1000
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
              required property var modelData
              required property int index

              Layout.fillWidth: true
              Layout.preferredHeight: Theme.itemHeight * 0.8
              radius: Theme.itemRadius
              color: codecMouseArea.containsMouse ? Theme.onHoverColor : "transparent"

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
                  implicitWidth: 8
                  implicitHeight: 8
                  radius: 4
                  color: codecDelegate.modelData.qualityColor || Theme.inactiveColor
                }

                Text {
                  text: codecDelegate.modelData.name || ""
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize * 0.85
                  font.bold: codecDelegate.modelData.name === deviceItem.modelData.currentCodec
                  color: codecMouseArea.containsMouse ? Theme.textOnHoverColor : Theme.textActiveColor
                  Layout.fillWidth: true
                }

                Text {
                  text: codecDelegate.modelData.description || ""
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize * 0.75
                  color: Theme.textInactiveColor
                }

                Text {
                  visible: codecDelegate.modelData.name === deviceItem.modelData.currentCodec
                  text: "󰄬"
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize * 0.8
                  color: Theme.activeColor
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
