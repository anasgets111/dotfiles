pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Services.Core

PanelContentBase {
  id: root

  readonly property bool active: root.ready && BluetoothService.enabled
  readonly property var connectedDevices: root.otherDevices.filter(d => d.connected)
  readonly property var otherDevices: BluetoothService.deviceModels
  readonly property var primaryDevice: connectedDevices[0] ?? null
  readonly property bool ready: BluetoothService.available
  readonly property bool shouldDiscover: root.isOpen && root.active
  property string showCodecFor: ""

  flatContainer: true
  preferredHeight: mainLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: Theme.bluetoothPanelWidth

  onIsOpenChanged: if (!isOpen)
    showCodecFor = ""
  onShouldDiscoverChanged: shouldDiscover ? BluetoothService.startDiscovery() : BluetoothService.stopDiscovery()

  ColumnLayout {
    id: mainLayout

    anchors.left: parent.left
    anchors.margins: Theme.spacingMd
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 0

    PanelHeader {
      Layout.bottomMargin: Theme.spacingMd
      accent: root.active ? Theme.activeColor : Theme.textInactiveColor
      icon: root.active ? "󰂯" : "󰂲"
      subtitle: !root.ready ? qsTr("Unavailable") : !root.active ? qsTr("Off") : root.primaryDevice ? [qsTr("%1 connected").arg(root.connectedDevices.length), root.primaryDevice.name, root.primaryDevice.batteryText].filter(Boolean).join(" · ") : BluetoothService.discovering ? qsTr("Scanning…") : qsTr("No devices connected")
      title: qsTr("Bluetooth")

      OToggle {
        checked: root.active
        disabled: !root.ready

        onToggled: c => {
          if (!c)
            BluetoothService.stopDiscovery();
          BluetoothService.setEnabled(c);
        }
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

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(deviceList.contentHeight, Theme.itemHeight * 10)
        clip: true
        color: "transparent"

        ListView {
          id: deviceList

          anchors.fill: parent
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          model: root.otherDevices
          section.criteria: ViewSection.FullString
          section.property: "group"
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
          section.delegate: PanelSectionHeader {
            sectionLabel: section === "paired" ? qsTr("Paired") : qsTr("Available")
            width: ListView.view.width
          }
        }
      }
    }
    PanelEmptyState {
      Layout.fillHeight: true
      Layout.fillWidth: true
      Layout.minimumHeight: 120
      icon: "󰂲"
      text: root.active ? (BluetoothService.discovering ? qsTr("Scanning…") : qsTr("No devices found")) : (!root.ready ? qsTr("Bluetooth unavailable") : qsTr("Bluetooth off"))
      visible: !root.active || root.otherDevices.length === 0
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
    readonly property bool canPickCodec: !!device?.connected && !!device?.isAudio
    readonly property string currentCodec: device?.currentCodec || ""
    property var device: null

    busy: !!row.device?.busy
    expandable: row.canPickCodec
    expanded: root.showCodecFor === row.addr
    icon: row.device?.icon || "󰂯"
    rowActionEnabled: row.canConnect || row.canPickCodec
    selected: !!row.device?.connected
    subtitle: row.device?.statusText || ""
    title: row.device?.name || qsTr("Unknown")

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
        visible: !!row.device?.paired

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
    badges: [
      BatteryBadge {
        device: row.device
        opacity: Theme.opacityStrong
      }
    ]
    expandedContent: [
      ColumnLayout {
        spacing: Theme.spacingXs
        width: parent?.width ?? 0

        Repeater {
          model: row.availableCodecs

          delegate: PanelRow {
            required property var modelData

            rowActionEnabled: modelData.name !== row.currentCodec
            selected: modelData.name === row.currentCodec
            subtitle: modelData.description || ""
            title: modelData.name || ""
            width: parent?.width ?? 0

            onClicked: {
              BluetoothService.switchCodec(row.addr, modelData.profile);
              root.showCodecFor = "";
            }
          }
        }
      }
    ]

    onClicked: {
      if (row.canPickCodec) {
        root.showCodecFor = root.showCodecFor === row.addr ? "" : row.addr;
        if (root.showCodecFor)
          BluetoothService.fetchCodecs(row.addr);
      } else if (row.canConnect) {
        BluetoothService.connectDevice(row.addr);
      }
    }
  }
}
