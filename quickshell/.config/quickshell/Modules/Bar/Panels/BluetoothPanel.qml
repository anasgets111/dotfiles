pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Core

PanelContentBase {
  id: root

  readonly property bool active: BluetoothService.available && BluetoothService.enabled
  readonly property var connectedDevices: {
    if (!ready)
      return [];
    return (BluetoothService.sortedDevices || []).filter(d => d?.connected);
  }
  readonly property var otherDevices: {
    if (!ready)
      return [];
    return (BluetoothService.sortedDevices || []).filter(d => !d?.connected);
  }
  readonly property real preferredHeight: mainLayout.implicitHeight + Theme.spacingMd * 2
  readonly property real preferredWidth: 360
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

  Component.onDestruction: {
    showCodecFor = "";
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

    // ═══════════════════════════════════════════
    // SECTION 1 — Toggle Pills
    // ═══════════════════════════════════════════
    RowLayout {
      Layout.bottomMargin: Theme.spacingMd
      Layout.fillWidth: true
      spacing: Theme.spacingXs

      PanelTogglePill {
        active: root.ready
        checked: BluetoothService.enabled
        icon: "󰂯"
        label: "Bluetooth"

        onToggled: c => {
          if (!c)
            BluetoothService.stopDiscovery();
          BluetoothService.setEnabled(c);
        }
      }

      PanelTogglePill {
        active: root.active
        checked: BluetoothService.discoverable
        icon: "󰐾"
        label: "Visible"

        onToggled: c => BluetoothService.setDiscoverable(c)
      }

      PanelTogglePill {
        active: root.active
        checked: BluetoothService.discovering
        icon: "󰀘"
        label: "Scan"
        spinning: BluetoothService.discovering

        onToggled: c => c ? BluetoothService.startDiscovery() : BluetoothService.stopDiscovery()
      }
    }

    // ═══════════════════════════════════════════
    // SECTION 2 — Connected Device Hero Cards
    // ═══════════════════════════════════════════
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

    // ═══════════════════════════════════════════
    // SECTION 3 — Device List
    // ═══════════════════════════════════════════
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      visible: root.active && root.otherDevices.length > 0

      OText {
        Layout.bottomMargin: Theme.spacingXs
        bold: true
        color: Theme.textInactiveColor
        size: "xs"
        text: "DEVICES"
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
          model: root.otherDevices
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
        }
      }
    }

    // ── Empty state ──
    Item {
      Layout.fillHeight: true
      Layout.fillWidth: true
      Layout.minimumHeight: 120
      visible: root.active && root.connectedDevices.length === 0 && root.otherDevices.length === 0

      ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingSm

        Text {
          Layout.alignment: Qt.AlignHCenter
          color: Theme.textInactiveColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize * 2
          opacity: 0.4
          text: "󰂲"
        }

        OText {
          Layout.alignment: Qt.AlignHCenter
          color: Theme.textInactiveColor
          text: BluetoothService.discovering ? qsTr("Scanning\u2026") : qsTr("No devices found")
        }
      }
    }

    // ── Disabled state ──
    Item {
      Layout.fillHeight: true
      Layout.fillWidth: true
      Layout.minimumHeight: 120
      visible: !root.active

      ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingSm

        Text {
          Layout.alignment: Qt.AlignHCenter
          color: Theme.textInactiveColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize * 2
          opacity: 0.3
          text: "󰂲"
        }

        OText {
          Layout.alignment: Qt.AlignHCenter
          color: Theme.textInactiveColor
          text: !root.ready ? qsTr("Bluetooth Unavailable") : qsTr("Bluetooth Off")
        }
      }
    }
  }

  // ── Device Row ──
  component DeviceRow: Rectangle {
    id: row

    readonly property bool canConnect: device && !device.connected && !isBusy && !device.blocked
    property var device: null
    readonly property bool hasBattery: device?.batteryAvailable && device.battery > 0
    readonly property string icon: BluetoothService.getDeviceIcon(device)
    readonly property bool isBusy: BluetoothService.isDeviceBusy(device)
    readonly property bool isPaired: device?.paired || device?.trusted || false
    readonly property string name: BluetoothService.getDeviceName(device) || qsTr("Unknown")
    readonly property string statusText: BluetoothService.getStatusString(device)

    signal action(string act, var dev)

    color: rowMa.containsMouse ? Qt.rgba(Theme.textActiveColor.r, Theme.textActiveColor.g, Theme.textActiveColor.b, 0.06) : "transparent"
    height: Theme.itemHeight
    radius: 10

    Behavior on color {
      ColorAnimation {
        duration: 120
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

      // Battery
      Rectangle {
        color: {
          const b = row.device?.battery || 0;
          if (b <= 10)
            return Theme.critical;
          if (b <= 20)
            return Theme.warning;
          return Theme.activeColor;
        }
        implicitHeight: Theme.fontSm + 4
        implicitWidth: rowBattLabel.implicitWidth + 8
        opacity: 0.7
        radius: height / 2
        visible: row.hasBattery

        OText {
          id: rowBattLabel

          anchors.centerIn: parent
          bold: true
          color: Theme.bgColor
          size: "xs"
          text: BluetoothService.getBattery(row.device)
        }
      }

      // Paired dot
      Rectangle {
        color: Theme.activeColor
        implicitHeight: 6
        implicitWidth: 6
        opacity: 0.5
        radius: 3
        visible: row.isPaired && !rowMa.containsMouse
      }

      // Forget — visible for paired on hover
      Rectangle {
        color: rowForgetMa.containsMouse ? Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.15) : "transparent"
        implicitHeight: 26
        implicitWidth: 26
        radius: 6
        visible: row.isPaired && rowMa.containsMouse

        Behavior on color {
          ColorAnimation {
            duration: 100
          }
        }

        Text {
          anchors.centerIn: parent
          color: Theme.critical
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize * 0.85
          opacity: rowForgetMa.containsMouse ? 1.0 : 0.45
          text: "󰩺"
        }

        MouseArea {
          id: rowForgetMa

          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          onClicked: row.action("forget", row.device)
        }
      }

      // Busy spinner
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

  // ═══════════════════════════════════════════════
  // INLINE COMPONENTS
  // ═══════════════════════════════════════════════

  // ── Hero Connected Card ──
  component HeroCard: Rectangle {
    id: hero

    readonly property string addr: device?.address || ""
    readonly property var availableCodecs: BluetoothService.deviceAvailableCodecs[addr] || []
    readonly property string currentCodec: BluetoothService.deviceCodecs[addr] || ""
    property var device: null
    readonly property bool hasBattery: device?.batteryAvailable && device.battery > 0
    readonly property string icon: BluetoothService.getDeviceIcon(device)
    readonly property bool isAudio: BluetoothService.isAudioDevice(device)
    readonly property bool isPaired: device?.paired || device?.trusted || false
    readonly property string name: BluetoothService.getDeviceName(device) || qsTr("Unknown")
    property string showCodecFor: ""
    readonly property bool showCodecs: showCodecFor === addr && availableCodecs.length > 0

    signal action(string act, var dev)

    border.color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.25)
    border.width: 1
    color: Theme.activeSubtle
    implicitHeight: visible ? heroCol.implicitHeight + Theme.spacingSm * 2 : 0
    radius: 14

    Behavior on implicitHeight {
      NumberAnimation {
        duration: 200
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
            color: Theme.activeColor
            elide: Text.ElideRight
            text: hero.name
          }

          RowLayout {
            spacing: Theme.spacingXs

            OText {
              color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.7)
              size: "xs"
              text: qsTr("Connected")
            }

            // Battery badge
            Rectangle {
              color: {
                const b = hero.device?.battery || 0;
                if (b <= 10)
                  return Theme.critical;
                if (b <= 20)
                  return Theme.warning;
                return Theme.activeColor;
              }
              implicitHeight: Theme.fontSm + 4
              implicitWidth: battLabel.implicitWidth + 8
              opacity: 0.85
              radius: height / 2
              visible: hero.hasBattery

              OText {
                id: battLabel

                anchors.centerIn: parent
                bold: true
                color: Theme.bgColor
                size: "xs"
                text: BluetoothService.getBattery(hero.device)
              }
            }

            // Codec badge
            Rectangle {
              color: Theme.inactiveColor
              implicitHeight: Theme.fontSm + 4
              implicitWidth: codecLabel.implicitWidth + 8
              opacity: 0.6
              radius: height / 2
              visible: hero.currentCodec !== ""

              OText {
                id: codecLabel

                anchors.centerIn: parent
                bold: true
                color: Theme.bgColor
                size: "xs"
                text: hero.currentCodec
              }
            }
          }
        }

        Item {
          Layout.fillWidth: true
        }

        // Codec toggle
        PanelActionIcon {
          Layout.preferredHeight: 30
          Layout.preferredWidth: 30
          icon: "󰓃"
          opacity: hero.showCodecs ? 1.0 : 0.9
          tint: Theme.activeColor
          visible: hero.isAudio

          onClicked: hero.action("toggle-codec", hero.device)
        }

        // Forget
        PanelActionIcon {
          Layout.preferredHeight: 30
          Layout.preferredWidth: 30
          icon: "󰩺"
          tint: Theme.critical
          visible: hero.isPaired

          onClicked: hero.action("forget", hero.device)
        }

        // Disconnect
        PanelActionIcon {
          Layout.preferredHeight: 30
          Layout.preferredWidth: 30
          icon: "󱘖"
          tint: Theme.critical

          onClicked: hero.action("disconnect", hero.device)
        }
      }

      // ── Codec Selector ──
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
            color: codecRow.isCurrent ? Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.15) : codecRowMa.containsMouse ? Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.08) : "transparent"
            height: Theme.itemHeight * 0.7
            radius: 8

            Behavior on color {
              ColorAnimation {
                duration: 100
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
                color: codecRow.modelData.qualityColor || Theme.inactiveColor
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
}
