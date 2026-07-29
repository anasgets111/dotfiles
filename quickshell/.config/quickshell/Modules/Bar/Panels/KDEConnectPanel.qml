pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Services.Core
import qs.Services.UI

PanelContentBase {
  id: root

  readonly property var actions: [
    { action: "--ring", icon: "󰂞", label: qsTr("Ring"), plugin: "findmyphone" },
    { action: "--ping", icon: "󰐷", label: qsTr("Ping"), plugin: "ping" },
    { action: "--send-clipboard", icon: "󰅍", label: qsTr("Clipboard"), plugin: "clipboard" },
    { action: "sms", icon: "󰍩", label: qsTr("SMS"), plugin: "sms" },
    { action: "share", icon: "󰒗", label: qsTr("Share"), plugin: "share" },
    { action: "browse", icon: "󰝰", label: qsTr("Files"), plugin: "sftp" }
  ]
  readonly property int battery: selectedDevice?.batteryInterface?.charge ?? -1
  readonly property color batteryColor: battery <= 10 ? Theme.critical : battery <= 20 ? Theme.warning : (selectedDevice?.batteryInterface?.isCharging ?? false) ? Theme.activeColor : Theme.textInactiveColor
  property bool confirmUnpair: false
  property bool refreshing: false
  readonly property var pairedDevices: KDEConnectService.devices.filter(device => device.source?.isPaired ?? false)
  readonly property var pairingDevice: KDEConnectService.devices.find(device => (device.source?.isPairRequestedByPeer ?? false) || (device.source?.isPairRequested ?? false)) ?? null
  property string preferredDeviceId: ""
  readonly property var selectedDevice: pairedDevices.find(device => device.id === preferredDeviceId) ?? pairedDevices.find(device => device.usable) ?? pairedDevices[0] ?? null
  readonly property string selectedDeviceId: selectedDevice?.id ?? ""
  property bool shareOpen: false
  readonly property var unpairedDevices: KDEConnectService.devices.filter(device => !(device.source?.isPaired ?? false))

  function can(plugin: string): bool { return (selectedDevice?.usable ?? false) && selectedDevice.hasPlugin(plugin); }
  function deviceIcon(device: var): string { return device?.type === "tablet" ? "󰓶" : device?.type === "desktop" ? "󰟀" : "󰄜"; }
  function networkText(device: var): string {
    const strength = Number(device?.connectivityInterface?.cellularNetworkStrength ?? -1);
    if (strength < 0)
      return "";
    const type = device?.connectivityInterface?.cellularNetworkType === "Unknown" ? "" : device?.connectivityInterface?.cellularNetworkType ?? "";
    return `${NetworkService.getWifiIcon([0, 25, 50, 80, 95][Math.min(4, Math.round(strength))])} ${type || qsTr("Mobile")}`;
  }
  function sendShare(): void {
    const value = shareInput.text.trim();
    if (!value)
      return;
    KDEConnectService.command(selectedDeviceId, [value.startsWith("/") || value.includes("://") ? "--share" : "--share-text", value]);
    shareInput.clear();
    shareOpen = false;
  }
  function statusText(device: var): string {
    const paired = device?.source?.isPaired ?? false;
    const reachable = device?.source?.isReachable ?? false;
    return !paired ? (reachable ? qsTr("Available to pair") : qsTr("Unavailable")) : reachable ? qsTr("Connected") : qsTr("Offline");
  }
  function trigger(action: string): void {
    if (action === "sms") {
      KDEConnectService.openSms(selectedDeviceId);
      ShellUiState.openModal("kdeconnectSms", ShellUiState.activeScreenName);
    } else if (action === "share") {
      shareOpen = !shareOpen;
    } else if (action === "browse") {
      KDEConnectService.browse(selectedDeviceId);
    } else {
      KDEConnectService.command(selectedDeviceId, [action]);
    }
  }

  flatContainer: true
  needsKeyboardFocus: shareOpen
  preferredHeight: Math.min(content.implicitHeight + Theme.spacingMd * 2, maxAvailableHeight)
  preferredWidth: Theme.kdeconnectPanelWidth

  onIsOpenChanged: if (!isOpen) {
    shareOpen = false;
    confirmUnpair = false;
  }
  onSelectedDeviceIdChanged: {
    shareOpen = false;
    confirmUnpair = false;
    KDEConnectService.remoteCommands.deviceId = selectedDeviceId;
  }

  Flickable {
    id: scroll

    anchors.fill: parent
    anchors.margins: Theme.spacingMd
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    contentHeight: content.implicitHeight
    contentWidth: width

    ScrollBar.vertical: ScrollBar {
      policy: scroll.contentHeight > scroll.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
      width: Theme.spacingXs
    }
    ColumnLayout {
      id: content

      spacing: 0
      width: parent.width

      PanelHeader {
        Layout.bottomMargin: Theme.spacingMd
        accent: KDEConnectService.connectedCount ? Theme.activeColor : Theme.textInactiveColor
        icon: "󰄡"
        subtitle: KDEConnectService.connectedCount ? qsTr("%1 connected").arg(KDEConnectService.connectedCount) : qsTr("No connected devices")
        title: qsTr("KDE Connect")

        PanelActionIcon {
          icon: "󰑐"
          tint: Theme.textInactiveColor
          tooltipText: qsTr("Refresh devices")
          visible: !root.refreshing

          onClicked: {
            KDEConnectService.refreshDevices();
            root.refreshing = true;
            refreshTimer.restart();
          }
        }
        OSpinner {
          color: Theme.textInactiveColor
          running: root.refreshing
          spinnerSize: Theme.iconSizeMd
        }
      }
      PanelCard {
        Layout.bottomMargin: visible ? Theme.spacingMd : 0
        Layout.fillWidth: true
        tone: "error"
        visible: KDEConnectService.error !== ""

        RowLayout {
          width: parent.width

          OText {
            Layout.fillWidth: true
            color: Theme.critical
            size: "sm"
            text: KDEConnectService.error
            wrapMode: Text.Wrap
          }
          PanelActionIcon {
            icon: "󰅖"
            tint: Theme.critical
            tooltipText: qsTr("Dismiss")

            onClicked: KDEConnectService.error = ""
          }
        }
      }
      PanelRow {
        Layout.bottomMargin: visible ? Theme.spacingMd : 0
        Layout.fillWidth: true
        rowActionEnabled: false
        subtitle: root.pairingDevice?.source?.verificationKey ? qsTr("Verification: %1").arg(root.pairingDevice.source.verificationKey) : qsTr("Confirm the code on both devices")
        title: root.pairingDevice?.source?.isPairRequestedByPeer ? qsTr("%1 wants to pair").arg(root.pairingDevice?.source?.name ?? "") : qsTr("Pairing with %1").arg(root.pairingDevice?.source?.name ?? "")
        visible: root.pairingDevice !== null

        actions: [
          OButton {
            size: "xs"
            text: root.pairingDevice?.source?.isPairRequestedByPeer ? qsTr("Reject") : qsTr("Cancel")
            variant: "secondary"

            onClicked: root.pairingDevice.source?.cancelPairing()
          },
          OButton {
            size: "xs"
            text: qsTr("Pair")
            visible: root.pairingDevice?.source?.isPairRequestedByPeer ?? false

            onClicked: root.pairingDevice.source?.acceptPairing()
          }
        ]
      }
      OComboBox {
        Layout.bottomMargin: visible ? Theme.spacingSm : 0
        Layout.fillWidth: true
        currentIndex: Math.max(0, root.pairedDevices.indexOf(root.selectedDevice))
        model: root.pairedDevices.map(device => device.source?.name ?? "")
        visible: root.pairedDevices.length > 1

        onActivated: index => root.preferredDeviceId = root.pairedDevices[index].id
      }
      PanelRow {
        Layout.bottomMargin: visible ? Theme.spacingSm : 0
        Layout.fillWidth: true
        icon: root.deviceIcon(root.selectedDevice)
        rowActionEnabled: false
        selected: root.selectedDevice?.usable ?? false
        subtitle: [root.statusText(root.selectedDevice), root.networkText(root.selectedDevice), (root.selectedDevice?.batteryInterface?.isCharging ?? false) ? (root.battery >= 100 ? qsTr("Charged") : qsTr("Charging")) : ""].filter(Boolean).join(" · ")
        title: root.selectedDevice?.source?.name ?? ""
        visible: root.selectedDevice !== null

        actions: [
          PanelActionIcon {
            icon: root.selectedDevice?.lockInterface?.isLocked ? "󰌾" : "󰌿"
            tint: root.selectedDevice?.lockInterface?.isLocked ? Theme.warning : Theme.textActiveColor
            tooltipText: root.selectedDevice?.lockInterface?.isLocked ? qsTr("Unlock device") : qsTr("Lock device")
            visible: root.can("lockdevice")

            onClicked: root.selectedDevice.lockInterface.isLocked = !root.selectedDevice.lockInterface.isLocked
          },
          PanelActionIcon {
            icon: "󰇪"
            tint: Theme.warning
            tooltipText: qsTr("Unmount phone files")
            visible: root.selectedDevice?.sftpMounted ?? false

            onClicked: KDEConnectService.unmountFiles(root.selectedDeviceId)
          },
          PanelActionIcon {
            icon: root.confirmUnpair ? "󰗠" : "󰌸"
            tint: Theme.critical
            tooltipText: root.confirmUnpair ? qsTr("Confirm unpair") : qsTr("Unpair device")

            onClicked: {
              if (root.confirmUnpair) {
                root.selectedDevice.source?.unpair();
                root.confirmUnpair = false;
                confirmTimer.stop();
              } else {
                root.confirmUnpair = true;
                confirmTimer.restart();
              }
            }
          }
        ]
        badges: [
          InfoBadge {
            badgeColor: root.batteryColor
            opacity: Theme.opacityStrong
            text: root.battery >= 0 ? qsTr("%1%").arg(root.battery) : ""
            visible: root.battery >= 0
          }
        ]
      }
      GridLayout {
        Layout.bottomMargin: visible ? Theme.spacingMd : 0
        Layout.fillWidth: true
        columnSpacing: Theme.spacingXs
        columns: 3
        rowSpacing: Theme.spacingXs
        visible: root.selectedDevice !== null

        Repeater {
          model: root.actions

          delegate: PanelToggleCard {
            required property var modelData

            Layout.preferredHeight: Theme.controlHeightLg
            active: root.can(modelData.plugin)
            checked: modelData.action === "share" && root.shareOpen || modelData.action === "browse" && (root.selectedDevice?.sftpMounted ?? false)
            icon: modelData.icon
            label: modelData.label

            onToggled: root.trigger(modelData.action)
          }
        }
      }
      PanelCard {
        Layout.bottomMargin: visible ? Theme.spacingMd : 0
        Layout.fillWidth: true
        visible: root.shareOpen

        RowLayout {
          width: parent.width

          OInput {
            id: shareInput

            Layout.fillWidth: true
            autoFocus: root.shareOpen
            placeholderText: qsTr("Text, URL, or file path")

            onInputAccepted: root.sendShare()
          }
          OButton {
            isEnabled: shareInput.text.trim() !== ""
            text: qsTr("Send")

            onClicked: root.sendShare()
          }
        }
      }
      ColumnLayout {
        Layout.bottomMargin: visible ? Theme.spacingMd : 0
        Layout.fillWidth: true
        spacing: Theme.borderWidthMedium
        visible: root.selectedDevice !== null && commands.count > 0

        PanelSectionHeader {
          Layout.fillWidth: true
          section: "remoteCommands"
          sectionLabel: qsTr("Remote commands")
        }
        Repeater {
          id: commands

          model: KDEConnectService.remoteCommands

          delegate: PanelRow {
            required property string key
            required property string name

            enabled: root.selectedDevice?.usable ?? false
            icon: "󰑔"
            title: name

            onClicked: KDEConnectService.command(root.selectedDeviceId, ["--execute-command", key])
          }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        visible: root.unpairedDevices.length > 0

        PanelSectionHeader {
          Layout.fillWidth: true
          section: "devices"
          sectionLabel: qsTr("Nearby devices")
        }
        Repeater {
          model: root.unpairedDevices

          delegate: PanelRow {
            id: deviceRow

            required property var modelData

            Layout.fillWidth: true
            icon: root.deviceIcon(modelData)
            rowActionEnabled: false
            subtitle: (modelData.source?.isReachable ?? false) ? qsTr("Ready to pair") : qsTr("Unavailable")
            title: modelData.source?.name ?? ""

            actions: [
              OButton {
                bgColor: "transparent"
                hoverColor: Theme.withOpacity(Theme.activeColor, Theme.opacitySubtle)
                size: "xs"
                text: qsTr("Pair")
                textColor: Theme.activeColor
                variant: "ghost"
                visible: deviceRow.modelData.source?.isReachable ?? false

                onClicked: deviceRow.modelData.source?.requestPairing()
              }
            ]
          }
        }
      }
      PanelEmptyState {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight * 5
        icon: "󰥐"
        subtext: qsTr("Open KDE Connect on a device connected to this network.")
        text: qsTr("No devices found")
        visible: KDEConnectService.devices.length === 0
      }
    }
  }
  Timer {
    id: confirmTimer

    interval: 4000

    onTriggered: root.confirmUnpair = false
  }
  // ponytail: discovery outlives the CLI command; 4s is feedback, not completion. Replace if KDE Connect exposes a completion signal.
  Timer {
    id: refreshTimer

    interval: 4000

    onTriggered: root.refreshing = false
  }
}
