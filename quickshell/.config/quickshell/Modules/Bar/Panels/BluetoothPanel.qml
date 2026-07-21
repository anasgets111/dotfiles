pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Services.Core

PanelContentBase {
  id: root

  readonly property bool active: BluetoothService.available && BluetoothService.enabled
  readonly property var connectedDevices: ready ? BluetoothService.deviceModels.filter(d => d.connected) : []
  readonly property var otherDevices: ready ? BluetoothService.deviceModels : []
  readonly property var otherDevicesView: otherDevices.map(d => Object.assign({}, d, {
      group: d.paired ? "paired" : "available"
    }))
  readonly property var primaryDevice: connectedDevices[0] ?? null
  readonly property bool ready: BluetoothService.available
  property string showCodecFor: ""
  readonly property bool showDeviceGroups: otherDevices.some(d => d.paired) && otherDevices.some(d => !d.paired)

  preferredHeight: mainLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: Theme.bluetoothPanelWidth

  onActiveChanged: {
    if (!isOpen)
      return;
    if (active)
      BluetoothService.startDiscovery();
    else
      BluetoothService.stopDiscovery();
  }
  onIsOpenChanged: {
    if (isOpen && active) {
      BluetoothService.startDiscovery();
      return;
    }
    showCodecFor = "";
    BluetoothService.stopDiscovery();
  }

  ColumnLayout {
    id: mainLayout

    anchors.fill: parent
    anchors.margins: Theme.spacingMd
    spacing: 0

    PanelToggleCard {
      Layout.bottomMargin: root.active ? Theme.spacingXs : Theme.spacingMd
      active: root.ready
      checked: root.active
      detail: !root.ready ? qsTr("Unavailable") : !root.active ? qsTr("Off") : root.primaryDevice ? [qsTr("%1 connected").arg(root.connectedDevices.length), root.primaryDevice.name, root.primaryDevice.batteryText].filter(Boolean).join(" · ") : BluetoothService.discovering ? qsTr("Scanning…") : qsTr("No devices connected")
      icon: root.active ? "󰂯" : "󰂲"
      label: qsTr("Bluetooth")

      onToggled: c => {
        if (!c)
          BluetoothService.stopDiscovery();
        BluetoothService.setEnabled(c);
      }
    }
    RowLayout {
      Layout.bottomMargin: Theme.spacingMd
      Layout.fillWidth: true
      spacing: Theme.spacingXs
      visible: root.active

      PanelToggleCard {
        checked: BluetoothService.discoverable
        icon: "󰐾"
        label: qsTr("Visible")

        onToggled: c => BluetoothService.setDiscoverable(c)
      }
      PanelToggleCard {
        checked: BluetoothService.discovering
        icon: "󰀘"
        label: qsTr("Scan")
        spinning: BluetoothService.discovering

        onToggled: c => c ? BluetoothService.startDiscovery() : BluetoothService.stopDiscovery()
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      visible: root.active && root.otherDevices.length > 0

      OText {
        Layout.bottomMargin: Theme.spacingXs
        bold: true
        color: Theme.textInactiveColor
        size: "xs"
        text: qsTr("Devices").toUpperCase()
      }
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(deviceList.contentHeight, Theme.itemHeight * 6)
        clip: true
        color: "transparent"

        ListView {
          id: deviceList

          anchors.fill: parent
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          model: root.otherDevicesView
          section.criteria: ViewSection.FullString
          section.property: root.showDeviceGroups ? "group" : ""
          spacing: Theme.borderWidthMedium

          ScrollBar.vertical: ScrollBar {
            policy: deviceList.contentHeight > deviceList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: Theme.spacingXs
          }
          delegate: DeviceRow {
            required property var modelData

            device: modelData
            width: ListView.view.width
          }
          section.delegate: Item {
            id: sectionRoot

            required property string section

            implicitHeight: sectionLabel.implicitHeight + Theme.spacingXs
            width: ListView.view.width

            OText {
              id: sectionLabel

              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.leftMargin: Theme.spacingSm
              bold: true
              color: Theme.textInactiveColor
              opacity: Theme.opacityMuted
              size: "xs"
              text: sectionRoot.section === "paired" ? qsTr("Paired") : qsTr("Available")
            }
          }
        }
      }
    }
    StateMessage {
      text: BluetoothService.discovering ? qsTr("Scanning…") : qsTr("No devices found")
      visible: root.active && root.connectedDevices.length === 0 && root.otherDevices.length === 0
    }
    StateMessage {
      iconOpacity: 0.3
      text: !root.ready ? qsTr("Bluetooth unavailable") : qsTr("Bluetooth off")
      visible: !root.active
    }
  }

  component BatteryBadge: InfoBadge {
    id: badge

    property var device: null
    readonly property int level: device?.battery || 0

    badgeColor: level <= 10 ? Theme.critical : level <= 20 ? Theme.warning : Theme.activeColor
    text: badge.device?.batteryText || ""
    visible: !!badge.device?.hasBattery
  }
  component DeviceRow: PanelRow {
    id: row

    readonly property string addr: device?.address || ""
    readonly property var availableCodecs: device?.availableCodecs || []
    readonly property bool canConnect: !!device?.canConnect
    readonly property string currentCodec: device?.currentCodec || ""
    property var device: null
    readonly property bool isBusy: !!device?.busy
    readonly property bool isPaired: !!device?.paired
    readonly property string name: device?.name || qsTr("Unknown")
    readonly property string statusText: device?.statusText || ""

    busy: row.isBusy
    expanded: root.showCodecFor === row.addr
    icon: row.device?.icon || "󰂯"
    rowActionEnabled: row.canConnect || (!!row.device?.connected && !!row.device?.isAudio)
    selected: !!row.device?.connected
    subtitle: row.statusText
    title: row.name

    onClicked: {
      if (row.device?.connected && row.device?.isAudio) {
        root.showCodecFor = root.showCodecFor === row.addr ? "" : row.addr;
        if (root.showCodecFor)
          BluetoothService.fetchCodecs(row.addr);
      } else if (row.canConnect) {
        BluetoothService.connectDevice(row.addr);
      }
    }

    badges: [BatteryBadge { device: row.device; opacity: Theme.opacityStrong }]
    actions: [
      PanelActionIcon {
        icon: "󱘖"
        tint: Theme.critical
        tooltipText: qsTr("Disconnect")
        visible: !!row.device?.connected
        onClicked: BluetoothService.disconnectDevice(row.addr)
      },
      PanelActionIcon {
        icon: "󰩺"
        tint: Theme.critical
        tooltipText: qsTr("Forget")
        visible: row.isPaired
        onClicked: BluetoothService.forgetDevice(row.addr)
      },
      OButton {
        bgColor: "transparent"
        hoverColor: Theme.withOpacity(Theme.activeColor, Theme.opacitySubtle)
        size: "xs"
        text: qsTr("Pair")
        textColor: Theme.activeColor
        variant: "ghost"
        visible: !!row.device?.canPair
        onClicked: BluetoothService.pairDevice(row.addr)
      }
    ]
    expandedContent: [
      ColumnLayout {
        width: parent?.width ?? 0
        spacing: Theme.spacingXs

        Repeater {
          model: row.availableCodecs

          delegate: PanelRow {
            required property var modelData
            width: parent?.width ?? 0
            rowActionEnabled: modelData.name !== row.currentCodec
            selected: modelData.name === row.currentCodec
            subtitle: modelData.description || ""
            title: modelData.name || ""
            onClicked: {
              BluetoothService.switchCodec(row.addr, modelData.profile);
              root.showCodecFor = "";
            }
          }
        }
      }
    ]
  }
  component StateMessage: Item {
    id: stateMessage

    property real iconOpacity: 0.4
    property string text: ""

    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.minimumHeight: 120

    ColumnLayout {
      anchors.centerIn: parent
      spacing: Theme.spacingSm

      Text {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.textInactiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize * 2
        opacity: stateMessage.iconOpacity
        text: "󰂲"
      }
      OText {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.textInactiveColor
        text: stateMessage.text
      }
    }
  }
}
