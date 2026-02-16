pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Config
import qs.Services
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.WM

Item {
  id: root

  readonly property int absoluteMinWidth: 900
  readonly property string authHint: {
    if (LockService.authState === LockService.authStates.fail)
      return "Authentication failed. Press Enter to retry";
    if (LockService.authenticating)
      return "Authenticating…";
    return "Press Enter to unlock";
  }
  required property bool isMainMonitor
  readonly property string layoutIcon: "󰌌"
  readonly property real lockScale: Theme.lockScale
  readonly property string networkIcon: NetworkService.linkType === "ethernet" ? "󰈀" : NetworkService.linkType === "wifi" ? "󰤨" : "󰤮"
  readonly property string networkLabel: NetworkService.linkType === "ethernet" ? "Ethernet" : NetworkService.linkType === "wifi" ? ((NetworkService.wifiAps ?? []).find(a => a?.connected)?.ssid ?? "Wi-Fi") : "Offline"
  readonly property string networkLabelCompact: root.networkLabel.length > 14 ? root.networkLabel.slice(0, 13) + "…" : root.networkLabel
  readonly property string powerIcon: BatteryService.isACPowered ? "󰚥" : "󰂄"
  readonly property real readableScale: Math.max(root.lockScale, 1.05)
  readonly property real rightTextScale: Math.max(root.lockScale, 1.36)
  readonly property real roundedScale: Math.max(root.lockScale, 1.12)
  readonly property int spaceLg: Math.round(Theme.spacingLg * root.lockScale)
  readonly property int spaceMd: Math.round(Theme.spacingMd * root.lockScale)
  readonly property int spaceSm: Math.round(Theme.spacingSm * root.lockScale)
  readonly property int spaceXl: Math.round(root.spaceLg * 1.5)
  readonly property var statusItems: [[root.weatherIcon, root.weatherLabel], [root.powerIcon, BatteryService.isLaptopBattery ? BatteryService.percentage + "%" : "AC"], [root.networkIcon, root.networkLabelCompact], [root.layoutIcon, KeyboardLayoutService.currentLayout || "N/A"],]
  readonly property string userInitials: {
    const source = MainService.fullName || MainService.username || "U";
    return source.split(" ").filter(Boolean).slice(0, 2).map(part => part[0]?.toUpperCase() ?? "").join("") || "U";
  }
  readonly property string weatherIcon: {
    const code = WeatherService.currentWeatherCode;
    if (code < 0)
      return "󰖐";
    if (code === 0 || code === 1)
      return "󰖙";
    if (code === 2 || code === 3)
      return "󰖐";
    if (code === 45 || code === 48)
      return "󰖑";
    if ([51, 53, 55, 61, 63, 65, 80, 81, 82].includes(code))
      return "󰖗";
    if ([56, 57, 66, 67, 71, 73, 75, 77, 85, 86].includes(code))
      return "󰖘";
    if ([95, 96, 99].includes(code))
      return "󰖓";
    return "󰖐";
  }
  readonly property string weatherLabel: (WeatherService.currentTemp || "").split(" ")[0] || "--"

  anchors.centerIn: parent
  implicitHeight: shell.implicitHeight
  implicitWidth: shell.implicitWidth

  transform: Translate {
    id: shakeTransform

  }

  Component.onCompleted: enterAnim.restart()

  ParallelAnimation {
    id: enterAnim

    NumberAnimation {
      duration: 300
      easing.type: Easing.OutCubic
      property: "opacity"
      target: shell
      to: 1
    }

    NumberAnimation {
      duration: 360
      easing.overshoot: 1.1
      easing.type: Easing.OutBack
      property: "scale"
      target: shell
      to: 1
    }
  }

  SequentialAnimation {
    id: shakeAnimation

    PropertyAnimation {
      duration: 44
      easing.type: Easing.OutQuad
      from: 0
      property: "x"
      target: shakeTransform
      to: 6
    }

    PropertyAnimation {
      duration: 88
      easing.type: Easing.InOutQuad
      property: "x"
      target: shakeTransform
      to: -6
    }

    PropertyAnimation {
      duration: 64
      easing.type: Easing.InOutQuad
      property: "x"
      target: shakeTransform
      to: 4
    }

    PropertyAnimation {
      duration: 52
      easing.type: Easing.InQuad
      property: "x"
      target: shakeTransform
      to: 0
    }
  }

  Connections {
    function onAuthStateChanged() {
      if (LockService.authState === LockService.authStates.error || LockService.authState === LockService.authStates.fail)
        shakeAnimation.restart();
    }

    target: LockService
  }

  // ── Main Shell ──────────────────────────────────────────────
  Rectangle {
    id: shell

    border.color: Theme.withOpacity("#ffffff", 0.22)
    border.width: 1
    color: Theme.withOpacity(Theme.bgColor, 0.30)
    implicitHeight: outerColumn.implicitHeight + root.spaceXl * 2
    implicitWidth: Math.max(480, Math.min(Math.round((root.parent ? root.parent.width : root.absoluteMinWidth) * 0.38), 720))
    layer.enabled: true
    opacity: 0
    radius: Theme.radiusXl * 1.2
    scale: 0.96
    transformOrigin: Item.Center

    layer.effect: MultiEffect {
      blurEnabled: false
      shadowBlur: Theme.shadowBlurLg * 1.2
      shadowColor: Theme.shadowColorStrong
      shadowEnabled: true
      shadowVerticalOffset: Theme.shadowOffsetY * 2.5
    }

    // Inner highlight border
    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      border.color: Theme.withOpacity("#ffffff", 0.10)
      border.width: 1
      color: "transparent"
      radius: Math.max(0, shell.radius - 1)
    }

    ColumnLayout {
      id: outerColumn

      anchors.fill: parent
      anchors.margins: root.spaceXl
      spacing: 0

      // ── Hero Clock ────────────────────────────────────────
      OText {
        Layout.fillWidth: true
        color: Theme.textActiveColor
        font.pixelSize: Math.round(Theme.fontHero * 1.4 * root.readableScale)
        horizontalAlignment: Text.AlignHCenter
        text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "h:mm AP")
        weight: "bold"
      }

      OText {
        Layout.fillWidth: true
        Layout.topMargin: root.spaceSm * 0.5
        color: Theme.withOpacity(Theme.textActiveColor, 0.7)
        font.pixelSize: Math.round(Theme.fontLg * root.readableScale)
        horizontalAlignment: Text.AlignHCenter
        text: TimeService.format("date", "dddd, MMMM d")
      }

      // ── Spacer ────────────────────────────────────────────
      Item {
        Layout.preferredHeight: root.spaceXl
      }

      // ── Avatar ────────────────────────────────────────────
      Item {
        readonly property int avatarSize: Math.round(Theme.controlHeightLg * 2.4 * root.roundedScale)

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: avatarSize
        Layout.preferredWidth: avatarSize

        // Glow ring behind avatar
        Rectangle {
          anchors.centerIn: parent
          border.color: Theme.withOpacity(Theme.activeColor, 0.5)
          border.width: 2
          color: "transparent"
          height: parent.avatarSize + 6
          layer.enabled: true
          radius: width / 2
          width: parent.avatarSize + 6

          layer.effect: MultiEffect {
            shadowBlur: 16
            shadowColor: Theme.withOpacity(Theme.activeColor, 0.35)
            shadowEnabled: true
          }
        }

        Rectangle {
          anchors.fill: parent
          color: Theme.withOpacity(Theme.activeColor, 0.22)
          radius: width / 2

          OText {
            anchors.centerIn: parent
            bold: true
            color: Theme.textActiveColor
            font.pixelSize: Math.round(Theme.fontHero * 0.8 * root.readableScale)
            text: root.userInitials
          }
        }
      }

      // ── User Identity ─────────────────────────────────────
      OText {
        Layout.fillWidth: true
        Layout.topMargin: root.spaceMd
        color: Theme.textActiveColor
        font.pixelSize: Math.round(Theme.fontXl * 1.2 * root.readableScale)
        horizontalAlignment: Text.AlignHCenter
        text: MainService.fullName || "User"
        weight: "semibold"
      }

      OText {
        Layout.fillWidth: true
        Layout.topMargin: root.spaceSm * 0.3
        color: Theme.withOpacity(Theme.textActiveColor, 0.55)
        font.pixelSize: Math.round(Theme.fontMd * root.readableScale)
        horizontalAlignment: Text.AlignHCenter
        text: (MainService.username || "user") + "@" + (MainService.hostname || "localhost")
      }

      // ── Spacer ────────────────────────────────────────────
      Item {
        Layout.preferredHeight: root.spaceLg
      }

      // ── Password Field (bare, no card wrapper) ────────────
      Rectangle {
        id: passwordInput

        readonly property bool hasPassword: LockService.passwordBuffer.length > 0
        readonly property bool isFail: LockService.authState === LockService.authStates.fail

        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Math.round(shell.implicitWidth * 0.82)
        Layout.preferredHeight: Math.round(Theme.controlHeightLg * 1.1 * root.roundedScale)
        border.color: passwordInput.isFail ? Theme.critical : LockService.authenticating ? Theme.activeColor : Theme.withOpacity("#ffffff", 0.18)
        border.width: 2
        color: Theme.withOpacity(Theme.bgInput, 0.85)
        layer.enabled: LockService.authenticating
        radius: Theme.radiusFull
        visible: root.isMainMonitor

        Behavior on border.color {
          ColorAnimation {
            duration: Theme.animationDuration
          }
        }
        layer.effect: MultiEffect {
          shadowBlur: 14
          shadowColor: Theme.withOpacity(Theme.activeColor, 0.4)
          shadowEnabled: true
        }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: root.spaceMd
          anchors.rightMargin: root.spaceMd
          spacing: root.spaceSm

          Text {
            color: Theme.withOpacity(Theme.activeColor, 0.8)
            font.family: Theme.iconFontFamily
            font.pixelSize: Math.round(Theme.iconSizeMd * root.readableScale)
            text: "󰌋"
          }

          OText {
            Layout.fillWidth: true
            color: passwordInput.isFail ? Theme.critical : passwordInput.hasPassword ? Theme.textActiveColor : Theme.withOpacity(Theme.textActiveColor, 0.4)
            font.pixelSize: Math.round(Theme.fontLg * root.readableScale)
            text: passwordInput.hasPassword ? "●".repeat(Math.min(LockService.passwordBuffer.length, 32)) : "Password"
          }

          // Caps lock badge
          Rectangle {
            Layout.preferredHeight: Math.round(Theme.controlHeightXs * root.lockScale)
            Layout.preferredWidth: capsRow.implicitWidth + root.spaceSm * 2
            color: Theme.withOpacity(Theme.warning, 0.92)
            radius: Theme.radiusFull
            visible: KeyboardLayoutService.capsOn

            RowLayout {
              id: capsRow

              anchors.centerIn: parent
              spacing: root.spaceSm * 0.5

              Text {
                color: Theme.bgColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Math.round(Theme.iconSizeSm * root.rightTextScale)
                text: "󰘲"
              }

              OText {
                bold: true
                color: Theme.bgColor
                size: "sm"
                sizeMultiplier: root.rightTextScale
                text: "CAPS"
              }
            }
          }
        }
      }

      // ── Auth Hint ─────────────────────────────────────────
      OText {
        Layout.fillWidth: true
        Layout.topMargin: root.spaceSm
        color: Theme.withOpacity(Theme.textActiveColor, 0.45)
        font.pixelSize: Math.round(Theme.fontMd * 0.9 * root.readableScale)
        horizontalAlignment: Text.AlignHCenter
        text: root.isMainMonitor ? root.authHint : "Unlock on main monitor"
        wrapMode: Text.WordWrap
      }

      // ── Spacer (push footer down) ────────────────────────
      Item {
        Layout.preferredHeight: root.spaceXl
      }

      // ── Thin separator ────────────────────────────────────
      Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: 1
        Layout.preferredWidth: parent.width * 0.6
        color: Theme.withOpacity("#ffffff", 0.08)
      }

      Item {
        Layout.preferredHeight: root.spaceSm
      }

      // ── Status Footer ─────────────────────────────────────
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: root.spaceMd

        Repeater {
          model: root.statusItems

          RowLayout {
            id: statusItem

            required property var modelData

            spacing: root.spaceSm * 0.5

            Text {
              color: Theme.withOpacity(Theme.activeColor, 0.6)
              font.family: Theme.iconFontFamily
              font.pixelSize: Math.round(Theme.iconSizeSm * root.readableScale)
              text: statusItem.modelData[0]
              verticalAlignment: Text.AlignVCenter
            }

            OText {
              color: Theme.withOpacity(Theme.textActiveColor, 0.5)
              font.pixelSize: Math.round(Theme.fontSm * root.readableScale)
              text: statusItem.modelData[1]
            }
          }
        }
      }
    }
  }
}
