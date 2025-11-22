pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Services
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.WM
import qs.Config

Item {
  id: root

  readonly property color accent: Theme.activeColor

  // Theme aliases
  readonly property var cTheme: LockService.theme // Catppuccin palette
  readonly property color colBase: root.cTheme.base
  readonly property color colLove: root.cTheme.love
  readonly property color colMauve: root.cTheme.mauve
  readonly property color colSurface0: root.cTheme.surface0
  readonly property color colSurface1: root.cTheme.surface1
  readonly property color colSurface2: root.cTheme.surface2
  readonly property color errorColor: Theme.critical
  readonly property bool hasScreen: lockSurface?.hasScreen ?? false
  readonly property bool isCompact: width < LockService.compactWidthThreshold
  readonly property bool isPrimaryMonitor: lockSurface?.isMainMonitor ?? false

  // --- Properties ---
  required property var lockContext
  required property var lockSurface
  readonly property color textPrimary: Theme.textActiveColor
  readonly property color textSecondary: Theme.textInactiveColor

  // --- Layout & Animation ---
  anchors.centerIn: parent
  height: contentColumn.implicitHeight + 60
  opacity: hasScreen ? 1 : 0
  scale: hasScreen ? 1 : 0.95
  visible: hasScreen
  width: Math.min(parent.width * 0.9, 500) // Max width for the card

  Behavior on opacity {
    NumberAnimation {
      duration: 300
      easing.type: Easing.OutCubic
    }
  }
  Behavior on scale {
    NumberAnimation {
      duration: 300
      easing.type: Easing.OutCubic
    }
  }

  // Shake Animation for errors
  transform: Translate {
    id: shakeTransform

  }

  SequentialAnimation {
    id: shakeAnimation

    NumberAnimation {
      duration: 50
      from: 0
      property: "x"
      target: shakeTransform
      to: 10
    }

    NumberAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: -10
    }

    NumberAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: 10
    }

    NumberAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: 0
    }
  }

  Connections {
    function onAuthStateChanged() {
      if (root.lockContext.authState === "error" || root.lockContext.authState === "fail") {
        shakeAnimation.restart();
      }
    }

    target: root.lockContext
  }

  // --- Background Card ---
  Rectangle {
    anchors.fill: parent
    border.color: Qt.rgba(root.colSurface1.r, root.colSurface1.g, root.colSurface1.b, 0.4)
    border.width: 1
    color: Qt.rgba(root.colBase.r, root.colBase.g, root.colBase.b, 0.6)
    layer.enabled: true
    radius: 32

    layer.effect: MultiEffect {
      blur: 0.2
      blurEnabled: true
      blurMax: 32
      shadowBlur: 20
      shadowColor: Qt.rgba(0, 0, 0, 0.2)
      shadowEnabled: true
      shadowVerticalOffset: 10
    }
  }

  // --- Content ---
  ColumnLayout {
    id: contentColumn

    anchors.centerIn: parent
    spacing: 24
    width: parent.width - 60

    // 1. Clock Section
    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: -10

      Text {
        Layout.alignment: Qt.AlignHCenter
        color: root.textPrimary
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: 86
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.1)
        text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "hh:mm")
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        color: root.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: 22
        font.weight: Font.Medium
        text: TimeService.format("date", "dddd, MMMM d")
      }
    }

    // 2. User Info (Optional)
    Text {
      Layout.alignment: Qt.AlignHCenter
      color: root.textPrimary
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: 18
      opacity: 0.8
      text: MainService.fullName || "User"
      visible: text.length > 0
    }

    // 3. Status Chips (Weather, Host)
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 12
      visible: root.hasScreen

      // Weather Chip
      Rectangle {
        Layout.preferredHeight: 36
        Layout.preferredWidth: weatherRow.implicitWidth + 24
        border.color: Qt.rgba(root.colSurface1.r, root.colSurface1.g, root.colSurface1.b, 0.3)
        color: Qt.rgba(root.colSurface0.r, root.colSurface0.g, root.colSurface0.b, 0.5)
        radius: 18
        visible: WeatherService

        RowLayout {
          id: weatherRow

          anchors.centerIn: parent
          spacing: 8

          Text {
            color: root.textPrimary
            font.pixelSize: 18
            text: WeatherService?.weatherInfo().icon ?? ""
          }

          Text {
            color: root.textPrimary
            font.bold: true
            font.family: Theme.fontFamily
            font.pixelSize: 14
            text: {
              const t = String(WeatherService?.currentTemp ?? "");
              return t.split(" ")[0]; // Just the number + unit
            }
          }
        }
      }

      // Host Chip
      Rectangle {
        Layout.preferredHeight: 36
        Layout.preferredWidth: hostRow.implicitWidth + 24
        border.color: Qt.rgba(root.colSurface1.r, root.colSurface1.g, root.colSurface1.b, 0.3)
        color: Qt.rgba(root.colSurface0.r, root.colSurface0.g, root.colSurface0.b, 0.5)
        radius: 18

        RowLayout {
          id: hostRow

          anchors.centerIn: parent
          spacing: 8

          Text {
            font.pixelSize: 16
            text: "💻"
          }

          Text {
            color: root.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 14
            text: MainService.hostname || "localhost"
          }
        }
      }

      // Battery Chip
      Rectangle {
        Layout.preferredHeight: 36
        Layout.preferredWidth: batteryRow.implicitWidth + 24
        border.color: Qt.rgba(root.colSurface1.r, root.colSurface1.g, root.colSurface1.b, 0.3)
        color: Qt.rgba(root.colSurface0.r, root.colSurface0.g, root.colSurface0.b, 0.5)
        radius: 18
        visible: BatteryService.isLaptopBattery

        RowLayout {
          id: batteryRow
          anchors.centerIn: parent
          spacing: 8

          Text {
            font.pixelSize: 16
            text: BatteryService.isCharging ? "⚡" : "🔋"
          }

          Text {
            color: root.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 14
            text: BatteryService.percentage + "%"
          }
        }
      }

      // Network Chip
      Rectangle {
        id: networkChip
        Layout.preferredHeight: 36
        Layout.preferredWidth: networkRow.implicitWidth + 24
        border.color: Qt.rgba(root.colSurface1.r, root.colSurface1.g, root.colSurface1.b, 0.3)
        color: Qt.rgba(root.colSurface0.r, root.colSurface0.g, root.colSurface0.b, 0.5)
        radius: 18
        visible: NetworkService.ready

        readonly property var active: NetworkService.chooseActiveDevice(NetworkService.deviceList)
        readonly property var ap: NetworkService.wifiAps.find(ap => ap?.connected)
        readonly property string link: NetworkService.linkType || "disconnected"
        readonly property string ssid: (ap && ap.ssid) ? String(ap.ssid) : ((active && active.type === "wifi") ? (active.connectionName || "") : "")

        RowLayout {
          id: networkRow
          anchors.centerIn: parent
          spacing: 8

          Text {
            font.pixelSize: 16
            text: networkChip.link === "ethernet" ? "󰈀" : (networkChip.link === "wifi" ? "󰤨" : "󰤭")
          }

          Text {
            color: root.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 14
            text: networkChip.link === "ethernet" ? "Ethernet" : (networkChip.link === "wifi" ? networkChip.ssid : "Offline")
          }
        }
      }
    }

    // 4. Password Input Area
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: 60
      Layout.topMargin: 10
      visible: root.isPrimaryMonitor

      Rectangle {
        anchors.centerIn: parent
        border.color: root.lockContext.authState === "fail" ? root.errorColor : root.lockContext.authenticating ? root.accent : Qt.rgba(root.colSurface2.r, root.colSurface2.g, root.colSurface2.b, 0.5)
        border.width: 2
        color: Qt.rgba(root.colSurface0.r, root.colSurface0.g, root.colSurface0.b, 0.8)
        height: 50
        radius: 25
        width: Math.min(parent.width, 300)

        Behavior on border.color {
          ColorAnimation {
            duration: 150
          }
        }

        // Lock Icon / Status
        Text {
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          font.pixelSize: 18
          opacity: 0.7
          text: "🔒"
        }

        // Password Dots
        Row {
          anchors.centerIn: parent
          spacing: 6
          visible: root.lockContext.passwordBuffer.length > 0

          Repeater {
            model: Math.min(root.lockContext.passwordBuffer.length, 12) // Limit dots

            Rectangle {
              color: root.textPrimary
              height: 8
              radius: 4
              width: 8
            }
          }
        }

        // Placeholder / Status Text
        Text {
          anchors.centerIn: parent
          color: root.lockContext.authState === "fail" ? root.errorColor : root.textSecondary
          font.family: Theme.fontFamily
          font.pixelSize: 14
          text: root.lockContext.statusMessage
          visible: root.lockContext.passwordBuffer.length === 0
        }

        // Caps Lock Indicator
        Rectangle {
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          color: root.errorColor
          height: 24
          radius: 12
          visible: KeyboardLayoutService.capsOn
          width: 24

          Text {
            anchors.centerIn: parent
            color: root.colBase
            font.bold: true
            font.pixelSize: 14
            text: "A"
          }
        }
      }
    }

    // 5. Footer Info
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      opacity: 0.6
      spacing: 16
      visible: root.isPrimaryMonitor

      Text {
        color: root.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: 12
        text: "Enter to unlock"
      }

      Rectangle {
        color: root.textSecondary
        height: 12
        width: 1
      }

      Text {
        color: root.textSecondary
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: 12
        text: KeyboardLayoutService.currentLayout
        visible: KeyboardLayoutService.currentLayout.length > 0
      }
    }
  }
}
