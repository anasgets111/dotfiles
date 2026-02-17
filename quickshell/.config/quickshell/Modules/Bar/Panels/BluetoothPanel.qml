pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import qs.Config
import qs.Components
import qs.Services.Core

PanelContentBase {
  id: root

  readonly property bool active: BluetoothService.available
    && BluetoothService.enabled
  readonly property var connectedDevices: {
    if (!ready) return [];
    return (BluetoothService.sortedDevices || [])
      .filter(d => d?.connected);
  }
  readonly property var otherDevices: {
    if (!ready) return [];
    return (BluetoothService.sortedDevices || [])
      .filter(d => !d?.connected);
  }
  readonly property real preferredHeight: mainLayout.implicitHeight
    + Theme.spacingMd * 2
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

  onIsOpenChanged: {
    if (isOpen && active) {
      BluetoothService.startDiscovery();
      return;
    }
    showCodecFor = "";
    BluetoothService.stopDiscovery();
  }

  Component.onDestruction: {
    showCodecFor = "";
    BluetoothService.stopDiscovery();
  }

  // ── Outer Shell ──
  Rectangle {
    anchors.fill: parent
    color: Theme.bgElevatedAlt
    radius: 16
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.18)
      shadowVerticalOffset: 4
      shadowBlur: 0.5
    }
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
      Layout.fillWidth: true
      Layout.bottomMargin: Theme.spacingMd
      spacing: Theme.spacingXs

      TogglePill {
        icon: "󰂯"
        label: "Bluetooth"
        active: root.ready
        checked: BluetoothService.enabled
        onToggled: c => {
          if (!c) BluetoothService.stopDiscovery();
          BluetoothService.setEnabled(c);
        }
      }

      TogglePill {
        icon: "󰐾"
        label: "Visible"
        active: root.active
        checked: BluetoothService.discoverable
        onToggled: c => BluetoothService.setDiscoverable(c)
      }

      TogglePill {
        icon: BluetoothService.discovering ? "󰀘" : "󰀘"
        label: "Scan"
        active: root.active
        checked: BluetoothService.discovering
        spinning: BluetoothService.discovering
        onToggled: c => c
          ? BluetoothService.startDiscovery()
          : BluetoothService.stopDiscovery()
      }
    }

    // ═══════════════════════════════════════════
    // SECTION 2 — Connected Device Hero Cards
    // ═══════════════════════════════════════════
    Repeater {
      model: root.connectedDevices

      delegate: HeroCard {
        required property var modelData

        Layout.fillWidth: true
        Layout.bottomMargin: Theme.spacingSm
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
        color: Theme.textInactiveColor
        size: "xs"
        bold: true
        text: "DEVICES"
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(
          deviceList.contentHeight,
          Theme.itemHeight * 6
        )
        color: "transparent"
        clip: true

        ListView {
          id: deviceList

          anchors.fill: parent
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          model: root.otherDevices
          spacing: 2

          ScrollBar.vertical: ScrollBar {
            policy: deviceList.contentHeight > deviceList.height
              ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 4
          }

          delegate: DeviceRow {
            required property var modelData
            required property int index

            width: ListView.view.width
            device: modelData

            onAction: (a, d) => root.handleAction(a, d)
          }
        }
      }
    }

    // ── Empty state ──
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 120
      visible: root.active
        && root.connectedDevices.length === 0
        && root.otherDevices.length === 0

      ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingSm

        Text {
          Layout.alignment: Qt.AlignHCenter
          color: Theme.textInactiveColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize * 2
          text: "󰂲"
          opacity: 0.4
        }

        OText {
          Layout.alignment: Qt.AlignHCenter
          color: Theme.textInactiveColor
          text: BluetoothService.discovering
            ? qsTr("Scanning\u2026") : qsTr("No devices found")
        }
      }
    }

    // ── Disabled state ──
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
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
          text: "󰂲"
          opacity: 0.3
        }

        OText {
          Layout.alignment: Qt.AlignHCenter
          color: Theme.textInactiveColor
          text: !root.ready
            ? qsTr("Bluetooth Unavailable")
            : qsTr("Bluetooth Off")
        }
      }
    }
  }

  // ═══════════════════════════════════════════════
  // INLINE COMPONENTS
  // ═══════════════════════════════════════════════

  // ── Toggle Pill ──
  component TogglePill: Rectangle {
    id: pill

    property bool active: true
    property bool checked: false
    required property string icon
    required property string label
    property bool spinning: false

    signal toggled(bool checked)

    Layout.fillWidth: true
    Layout.preferredHeight: 56
    radius: 12
    color: pill.checked && pill.active
      ? Theme.activeSubtle : Theme.bgElevated
    border.color: pill.checked && pill.active
      ? Qt.rgba(Theme.activeColor.r, Theme.activeColor.g,
          Theme.activeColor.b, 0.3)
      : "transparent"
    border.width: 1
    opacity: pill.active ? 1.0 : Theme.opacityDisabled

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    MouseArea {
      anchors.fill: parent
      cursorShape: pill.active
        ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: pill.active
      onClicked: pill.toggled(!pill.checked)
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: 4

      Text {
        id: pillIcon

        Layout.alignment: Qt.AlignHCenter
        color: pill.checked && pill.active
          ? Theme.activeColor : Theme.textInactiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize * 1.3
        text: pill.icon

        Behavior on color { ColorAnimation { duration: 150 } }

        RotationAnimation on rotation {
          duration: 2000
          from: 0
          to: 360
          loops: Animation.Infinite
          running: pill.spinning
        }
      }

      OText {
        Layout.alignment: Qt.AlignHCenter
        color: pill.checked && pill.active
          ? Theme.activeColor : Theme.textInactiveColor
        size: "xs"
        bold: pill.checked
        text: pill.label

        Behavior on color { ColorAnimation { duration: 150 } }
      }
    }
  }

  // ── Hero Connected Card ──
  component HeroCard: Rectangle {
    id: hero

    property var device: null
    property string showCodecFor: ""

    readonly property string addr: device?.address || ""
    readonly property var availableCodecs:
      BluetoothService.deviceAvailableCodecs[addr] || []
    readonly property string currentCodec:
      BluetoothService.deviceCodecs[addr] || ""
    readonly property bool hasBattery:
      device?.batteryAvailable && device.battery > 0
    readonly property string icon:
      BluetoothService.getDeviceIcon(device)
    readonly property bool isAudio:
      BluetoothService.isAudioDevice(device)
    readonly property bool isPaired:
      device?.paired || device?.trusted || false
    readonly property string name:
      BluetoothService.getDeviceName(device) || qsTr("Unknown")
    readonly property bool showCodecs:
      showCodecFor === addr && availableCodecs.length > 0

    signal action(string act, var dev)

    implicitHeight: visible
      ? heroCol.implicitHeight + Theme.spacingSm * 2 : 0
    radius: 14
    color: Theme.activeSubtle
    border.color: Qt.rgba(Theme.activeColor.r,
      Theme.activeColor.g, Theme.activeColor.b, 0.25)
    border.width: 1

    Behavior on implicitHeight {
      NumberAnimation {
        duration: 200; easing.type: Easing.OutCubic
      }
    }

    ColumnLayout {
      id: heroCol

      anchors.fill: parent
      anchors.margins: Theme.spacingSm
      anchors.leftMargin: Theme.spacingMd
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
            text: hero.name
            bold: true
            color: Theme.activeColor
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          RowLayout {
            spacing: Theme.spacingXs

            OText {
              text: qsTr("Connected")
              size: "xs"
              color: Qt.rgba(Theme.activeColor.r,
                Theme.activeColor.g,
                Theme.activeColor.b, 0.7)
            }

            // Battery badge
            Rectangle {
              visible: hero.hasBattery
              width: battLabel.implicitWidth + 8
              height: Theme.fontSm + 4
              radius: height / 2
              color: {
                const b = hero.device?.battery || 0;
                if (b <= 10) return Theme.critical;
                if (b <= 20) return Theme.warning;
                return Theme.activeColor;
              }
              opacity: 0.85

              OText {
                id: battLabel
                anchors.centerIn: parent
                size: "xs"
                bold: true
                color: Theme.bgColor
                text: BluetoothService.getBattery(hero.device)
              }
            }

            // Codec badge
            Rectangle {
              visible: hero.currentCodec !== ""
              width: codecLabel.implicitWidth + 8
              height: Theme.fontSm + 4
              radius: height / 2
              color: Theme.inactiveColor
              opacity: 0.6

              OText {
                id: codecLabel
                anchors.centerIn: parent
                size: "xs"
                bold: true
                color: Theme.bgColor
                text: hero.currentCodec
              }
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Codec toggle
        Rectangle {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 30
          radius: 8
          visible: hero.isAudio
          color: hero.showCodecs
            ? Qt.rgba(Theme.activeColor.r, Theme.activeColor.g,
                Theme.activeColor.b, 0.2)
            : codecMa.containsMouse
              ? Qt.rgba(Theme.activeColor.r, Theme.activeColor.g,
                  Theme.activeColor.b, 0.1)
              : "transparent"

          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            color: Theme.activeColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: "󰓃"
            opacity: hero.showCodecs || codecMa.containsMouse
              ? 1.0 : 0.5
          }

          MouseArea {
            id: codecMa
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: hero.action("toggle-codec", hero.device)
          }
        }

        // Forget
        Rectangle {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 30
          radius: 8
          visible: hero.isPaired
          color: heroForgetMa.containsMouse
            ? Qt.rgba(Theme.critical.r, Theme.critical.g,
                Theme.critical.b, 0.15)
            : "transparent"

          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            color: Theme.critical
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: "󰩺"
            opacity: heroForgetMa.containsMouse ? 1.0 : 0.5
          }

          MouseArea {
            id: heroForgetMa
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: hero.action("forget", hero.device)
          }
        }

        // Disconnect
        Rectangle {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 30
          radius: 8
          color: heroDiscMa.containsMouse
            ? Qt.rgba(Theme.critical.r, Theme.critical.g,
                Theme.critical.b, 0.15)
            : "transparent"

          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            color: Theme.critical
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: "󱘖"
            opacity: heroDiscMa.containsMouse ? 1.0 : 0.5
          }

          MouseArea {
            id: heroDiscMa
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: hero.action("disconnect", hero.device)
          }
        }
      }

      // ── Codec Selector ──
      ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: hero.showCodecs ? Theme.spacingSm : 0
        Layout.leftMargin: Theme.spacingMd
        spacing: 2
        visible: hero.showCodecs

        Repeater {
          model: hero.availableCodecs

          delegate: Rectangle {
            id: codecRow

            required property var modelData
            required property int index

            readonly property bool isCurrent:
              modelData.name === hero.currentCodec

            Layout.fillWidth: true
            height: Theme.itemHeight * 0.7
            radius: 8
            color: codecRow.isCurrent
              ? Qt.rgba(Theme.activeColor.r, Theme.activeColor.g,
                  Theme.activeColor.b, 0.15)
              : codecRowMa.containsMouse
                ? Qt.rgba(Theme.activeColor.r,
                    Theme.activeColor.g,
                    Theme.activeColor.b, 0.08)
                : "transparent"

            Behavior on color {
              ColorAnimation { duration: 100 }
            }

            MouseArea {
              id: codecRowMa
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onClicked: if (!codecRow.isCurrent)
                hero.action(
                  "codec:" + codecRow.modelData.profile,
                  hero.device)
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Theme.spacingSm
              anchors.rightMargin: Theme.spacingSm
              spacing: Theme.spacingSm

              Rectangle {
                width: 6
                height: 6
                radius: 3
                color: codecRow.modelData.qualityColor
                  || Theme.inactiveColor
              }

              OText {
                Layout.fillWidth: true
                text: codecRow.modelData.name || ""
                size: "xs"
                bold: codecRow.isCurrent
                color: codecRow.isCurrent
                  ? Theme.activeColor
                  : Theme.textActiveColor
              }

              OText {
                text: codecRow.modelData.description || ""
                size: "xs"
                color: Theme.textInactiveColor
              }

              Text {
                visible: codecRow.isCurrent
                color: Theme.activeColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.8
                text: "󰄬"
              }
            }
          }
        }
      }
    }
  }

  // ── Device Row ──
  component DeviceRow: Rectangle {
    id: row

    property var device: null

    readonly property string addr: device?.address || ""
    readonly property bool canConnect:
      device && !device.connected
      && !isBusy && !device.blocked
    readonly property bool hasBattery:
      device?.batteryAvailable && device.battery > 0
    readonly property string icon:
      BluetoothService.getDeviceIcon(device)
    readonly property bool isBusy:
      BluetoothService.isDeviceBusy(device)
    readonly property bool isPaired:
      device?.paired || device?.trusted || false
    readonly property string name:
      BluetoothService.getDeviceName(device) || qsTr("Unknown")
    readonly property string statusText:
      BluetoothService.getStatusString(device)

    signal action(string act, var dev)

    height: Theme.itemHeight
    radius: 10
    color: rowMa.containsMouse
      ? Qt.rgba(Theme.textActiveColor.r,
          Theme.textActiveColor.g,
          Theme.textActiveColor.b, 0.06)
      : "transparent"

    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
      id: rowMa
      anchors.fill: parent
      cursorShape: row.canConnect
        ? Qt.PointingHandCursor : Qt.ArrowCursor
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
          text: row.name
          elide: Text.ElideRight
          color: Theme.textActiveColor
          Layout.fillWidth: true
        }

        OText {
          text: row.statusText
          size: "xs"
          color: Theme.textInactiveColor
          visible: text !== ""
        }
      }

      // Battery
      Rectangle {
        visible: row.hasBattery
        width: rowBattLabel.implicitWidth + 8
        height: Theme.fontSm + 4
        radius: height / 2
        color: {
          const b = row.device?.battery || 0;
          if (b <= 10) return Theme.critical;
          if (b <= 20) return Theme.warning;
          return Theme.activeColor;
        }
        opacity: 0.7

        OText {
          id: rowBattLabel
          anchors.centerIn: parent
          size: "xs"
          bold: true
          color: Theme.bgColor
          text: BluetoothService.getBattery(row.device)
        }
      }

      // Paired dot
      Rectangle {
        visible: row.isPaired && !rowMa.containsMouse
        width: 6
        height: 6
        radius: 3
        color: Theme.activeColor
        opacity: 0.5
      }

      // Forget — visible for paired on hover
      Rectangle {
        visible: row.isPaired && rowMa.containsMouse
        width: 26
        height: 26
        radius: 6
        color: rowForgetMa.containsMouse
          ? Qt.rgba(Theme.critical.r, Theme.critical.g,
              Theme.critical.b, 0.15)
          : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
          anchors.centerIn: parent
          color: Theme.critical
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize * 0.85
          text: "󰩺"
          opacity: rowForgetMa.containsMouse ? 1.0 : 0.45
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
        visible: row.isBusy
        color: Theme.activeColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: "󰇙"

        RotationAnimation on rotation {
          duration: 1000
          from: 0; to: 360
          loops: Animation.Infinite
          running: row.isBusy
        }
      }
    }
  }
}
