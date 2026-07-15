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
  readonly property var otherDevices: ready ? BluetoothService.deviceModels.filter(d => !d.connected) : []
  readonly property var otherDevicesView: otherDevices.map(d => Object.assign({}, d, {
      group: d.paired ? "paired" : "available"
    }))
  readonly property bool ready: BluetoothService.available
  property string showCodecFor: ""
  readonly property bool showDeviceGroups: otherDevices.some(d => d.paired) && otherDevices.some(d => !d.paired)

  function codecQualityColor(qualityTier: string): color {
    if (qualityTier === "best")
      return Theme.powerSaveColor;
    if (qualityTier === "high")
      return Theme.warning;
    if (qualityTier === "balanced")
      return Theme.activeColor;
    return Theme.inactiveColor;
  }
  function handleAction(action: string, device: var): void {
    const address = device?.address || "";
    switch (action) {
    case "connect":
      BluetoothService.connectDevice(address);
      break;
    case "pair":
      BluetoothService.pairDevice(address);
      break;
    case "disconnect":
      BluetoothService.disconnectDevice(address);
      break;
    case "forget":
      BluetoothService.forgetDevice(address);
      break;
    case "toggle-codec":
      showCodecFor = showCodecFor === address ? "" : address;
      if (showCodecFor)
        BluetoothService.fetchCodecs(address);
      break;
    default:
      if (action.startsWith("codec:")) {
        BluetoothService.switchCodec(address, action.substring(6));
        showCodecFor = "";
      }
    }
  }

  preferredHeight: mainLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: 360

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

    PanelTogglePill {
      Layout.bottomMargin: root.active ? Theme.spacingXs : Theme.spacingMd
      active: root.ready
      checked: root.active
      detail: !root.ready ? qsTr("Unavailable") : !root.active ? qsTr("Off") : root.connectedDevices.length === 1 ? root.connectedDevices[0].name : root.connectedDevices.length > 1 ? qsTr("%1 connected").arg(root.connectedDevices.length) : BluetoothService.discovering ? qsTr("Scanning…") : qsTr("No devices connected")
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

      PanelTogglePill {
        checked: BluetoothService.discoverable
        icon: "󰐾"
        label: qsTr("Visible")

        onToggled: c => BluetoothService.setDiscoverable(c)
      }
      PanelTogglePill {
        checked: BluetoothService.discovering
        icon: "󰀘"
        label: qsTr("Scan")
        spinning: BluetoothService.discovering

        onToggled: c => c ? BluetoothService.startDiscovery() : BluetoothService.stopDiscovery()
      }
    }
    Repeater {
      model: root.connectedDevices

      delegate: HeroCard {
        required property var modelData

        Layout.bottomMargin: Theme.spacingSm
        Layout.fillWidth: true
        device: modelData
        showCodecFor: root.showCodecFor

        onAction: (a, d) => root.handleAction(a, d)
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
          spacing: 2

          ScrollBar.vertical: ScrollBar {
            policy: deviceList.contentHeight > deviceList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 4
          }
          delegate: DeviceRow {
            required property var modelData

            device: modelData
            width: ListView.view.width

            onAction: (a, d) => root.handleAction(a, d)
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
              opacity: 0.7
              size: "xs"
              text: sectionRoot.section === "paired" ? qsTr("Paired") : qsTr("Available")
            }
          }
        }
      }
    }
    StateMessage {
      iconOpacity: 0.4
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
  component DeviceRow: Rectangle {
    id: row

    readonly property bool canConnect: !!device?.canConnect
    property var device: null
    readonly property string icon: device?.icon || "󰂯"
    readonly property bool isBusy: !!device?.busy
    readonly property bool isPaired: !!device?.paired
    readonly property string name: device?.name || qsTr("Unknown")
    readonly property string statusText: device?.statusText || ""

    signal action(string act, var dev)

    color: rowMa.containsMouse ? Theme.withOpacity(Theme.activeColor, 0.08) : "transparent"
    height: Theme.itemHeight
    radius: Theme.radiusMd

    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }

    MouseArea {
      id: rowMa

      anchors.fill: parent
      cursorShape: row.canConnect ? Qt.PointingHandCursor : Qt.ArrowCursor
      hoverEnabled: true

      onClicked: if (row.canConnect)
        row.action("connect", row.device)
    }
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Theme.spacingSm
      anchors.rightMargin: Theme.spacingSm
      spacing: Theme.spacingSm

      Text {
        color: Theme.textActiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: row.icon
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        OText {
          Layout.fillWidth: true
          color: Theme.textActiveColor
          elide: Text.ElideRight
          text: row.name
        }
        OText {
          color: Theme.textInactiveColor
          size: "xs"
          text: row.statusText
          visible: text !== ""
        }
      }
      BatteryBadge {
        device: row.device
        opacity: 0.7
      }
      Rectangle {
        color: Theme.activeColor
        implicitHeight: 6
        implicitWidth: 6
        opacity: 0.5
        radius: 3
        visible: row.isPaired && !rowMa.containsMouse
      }
      PanelActionIcon {
        id: forgetBtn

        Layout.preferredHeight: 26
        Layout.preferredWidth: 26
        icon: "󰩺"
        tint: Theme.critical
        visible: row.isPaired && (rowMa.containsMouse || forgetBtn.hovered)

        onClicked: row.action("forget", row.device)
      }
      OButton {
        id: pairBtn

        bgColor: "transparent"
        hoverColor: Theme.withOpacity(Theme.activeColor, 0.15)
        size: "xs"
        text: qsTr("Pair")
        textColor: Theme.activeColor
        variant: "ghost"
        visible: !!row.device?.canPair && (rowMa.containsMouse || pairBtn.hovered)

        onClicked: row.action("pair", row.device)
      }
      Text {
        color: Theme.activeColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: "󰇙"
        visible: row.isBusy

        RotationAnimation on rotation {
          duration: 1000
          from: 0
          loops: Animation.Infinite
          running: row.isBusy
          to: 360
        }
      }
    }
  }
  component HeroCard: Rectangle {
    id: hero

    readonly property string addr: device?.address || ""
    readonly property var availableCodecs: device?.availableCodecs || []
    readonly property string currentCodec: device?.currentCodec || ""
    readonly property string currentCodecQuality: availableCodecs.find(c => c.name === currentCodec)?.qualityTier || ""
    property var device: null
    readonly property string icon: device?.icon || "󰂯"
    readonly property bool isAudio: !!device?.isAudio
    readonly property bool isPaired: !!device?.paired
    readonly property string name: device?.name || qsTr("Unknown")
    property string showCodecFor: ""
    readonly property bool showCodecs: showCodecFor === addr && availableCodecs.length > 0

    signal action(string act, var dev)

    border.color: Theme.withOpacity(Theme.activeColor, 0.35)
    border.width: Theme.borderWidthMedium
    color: Theme.activeSubtle
    implicitHeight: visible ? heroCol.implicitHeight + Theme.spacingSm * 2 : 0
    radius: Theme.radiusLg

    Behavior on implicitHeight {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.OutCubic
      }
    }

    ColumnLayout {
      id: heroCol

      anchors.fill: parent
      anchors.leftMargin: Theme.spacingMd
      anchors.margins: Theme.spacingSm
      anchors.rightMargin: Theme.spacingSm
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Text {
          color: Theme.activeColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize * 1.2
          text: hero.icon
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          OText {
            Layout.fillWidth: true
            bold: true
            color: Theme.textActiveColor
            elide: Text.ElideRight
            text: hero.name
          }
          RowLayout {
            spacing: Theme.spacingXs

            OText {
              color: Theme.textInactiveColor
              size: "xs"
              text: qsTr("Connected")
            }
            BatteryBadge {
              device: hero.device
              opacity: 0.85
            }
            Rectangle {
              color: root.codecQualityColor(hero.currentCodecQuality || "basic")
              implicitHeight: 6
              implicitWidth: 6
              radius: 3
              visible: hero.currentCodec !== ""
            }
            InfoBadge {
              badgeColor: Theme.inactiveColor
              opacity: 0.6
              text: hero.currentCodec
            }
          }
        }
        PanelActionIcon {
          Layout.preferredHeight: 30
          Layout.preferredWidth: 30
          icon: "󰓃"
          opacity: hero.showCodecs ? 1.0 : 0.9
          tint: Theme.activeColor
          visible: hero.isAudio

          onClicked: hero.action("toggle-codec", hero.device)
        }
        PanelActionIcon {
          Layout.preferredHeight: 30
          Layout.preferredWidth: 30
          icon: "󰩺"
          tint: Theme.critical
          visible: hero.isPaired

          onClicked: hero.action("forget", hero.device)
        }
        PanelActionIcon {
          Layout.preferredHeight: 30
          Layout.preferredWidth: 30
          icon: "󱘖"
          tint: Theme.critical

          onClicked: hero.action("disconnect", hero.device)
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacingMd
        Layout.topMargin: hero.showCodecs ? Theme.spacingSm : 0
        spacing: 2
        visible: hero.showCodecs

        Repeater {
          model: hero.availableCodecs

          delegate: Rectangle {
            id: codecRow

            readonly property bool isCurrent: modelData.name === hero.currentCodec
            required property var modelData

            Layout.fillWidth: true
            color: codecRow.isCurrent ? Theme.withOpacity(Theme.activeColor, 0.15) : codecRowMa.containsMouse ? Theme.withOpacity(Theme.activeColor, 0.08) : "transparent"
            height: Theme.itemHeight * 0.7
            radius: Theme.radiusMd

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }

            MouseArea {
              id: codecRowMa

              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true

              onClicked: if (!codecRow.isCurrent)
                hero.action("codec:" + codecRow.modelData.profile, hero.device)
            }
            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Theme.spacingSm
              anchors.rightMargin: Theme.spacingSm
              spacing: Theme.spacingSm

              Rectangle {
                color: root.codecQualityColor(codecRow.modelData.qualityTier || "basic")
                implicitHeight: 6
                implicitWidth: 6
                radius: 3
              }
              OText {
                Layout.fillWidth: true
                bold: codecRow.isCurrent
                color: codecRow.isCurrent ? Theme.activeColor : Theme.textActiveColor
                size: "xs"
                text: codecRow.modelData.name || ""
              }
              OText {
                color: Theme.textInactiveColor
                size: "xs"
                text: codecRow.modelData.description || ""
              }
              Text {
                color: Theme.activeColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.8
                text: "󰄬"
                visible: codecRow.isCurrent
              }
            }
          }
        }
      }
    }
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
