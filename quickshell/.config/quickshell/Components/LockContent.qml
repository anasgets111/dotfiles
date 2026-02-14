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
      return "Authentication failed. Press Enter to retry or Esc to cancel";
    if (LockService.authenticating)
      return "Authenticating...";
    return "Press Enter to unlock or Esc to cancel";
  }
  required property bool isMainMonitor
  readonly property string layoutIcon: "󰌌"
  readonly property real lockScale: Theme.lockScale
  readonly property string networkIcon: NetworkService.linkType === "ethernet" ? "󰈀" : NetworkService.linkType === "wifi" ? "󰤨" : "󰤮"
  readonly property string networkLabel: NetworkService.linkType === "ethernet" ? "Ethernet" : NetworkService.linkType === "wifi" ? ((NetworkService.wifiAps ?? []).find(a => a?.connected)?.ssid ?? "Wi-Fi") : "Offline"
  readonly property string networkLabelCompact: root.networkLabel.length > 18 ? root.networkLabel.slice(0, 17) + "…" : root.networkLabel
  readonly property string powerIcon: BatteryService.isACPowered ? "󰚥" : "󰂄"
  readonly property real readableScale: Math.max(root.lockScale, 1.05)
  readonly property real rightTextScale: Math.max(root.lockScale, 1.36)
  readonly property real roundedScale: Math.max(root.lockScale, 1.12)
  readonly property int spaceLg: Math.round(Theme.spacingLg * root.lockScale)
  readonly property int spaceMd: Math.round(Theme.spacingMd * root.lockScale)
  readonly property int spaceSm: Math.round(Theme.spacingSm * root.lockScale)
  readonly property var statusItems: [[root.weatherIcon, root.weatherLabel], [root.powerIcon, BatteryService.isLaptopBattery ? BatteryService.percentage + "%" : "Desktop"], [root.networkIcon, root.networkLabelCompact], [root.layoutIcon, KeyboardLayoutService.currentLayout || "N/A"], [root.wmIcon, MainService.currentWM || "unknown"]]
  readonly property string userHostText: (MainService.username || "user") + "@" + (MainService.hostname || "localhost")
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
  readonly property string wmIcon: "󱂬"

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
      duration: 280
      easing.type: Easing.OutCubic
      property: "opacity"
      target: shell
      to: 1
    }

    NumberAnimation {
      duration: 320
      easing.overshoot: 1.15
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

  Rectangle {
    id: shell

    border.color: Theme.withOpacity("#ffffff", 0.28)
    border.width: 1
    color: Theme.withOpacity(Theme.bgColor, 0.34)
    implicitHeight: contentColumn.implicitHeight + root.spaceLg * 2
    implicitWidth: Math.max(540, Math.min(Math.round((root.parent ? root.parent.width : root.absoluteMinWidth) * 0.4), 900))
    layer.enabled: true
    opacity: 0
    radius: Theme.radiusXl
    scale: 0.96
    transformOrigin: Item.Center

    layer.effect: MultiEffect {
      blurEnabled: false
      shadowBlur: Theme.shadowBlurLg
      shadowColor: Theme.shadowColorStrong
      shadowEnabled: true
      shadowVerticalOffset: Theme.shadowOffsetY * 2
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      border.color: Theme.withOpacity("#ffffff", 0.16)
      border.width: 1
      color: "transparent"
      radius: Math.max(0, shell.radius - 1)
    }

    ColumnLayout {
      id: contentColumn

      anchors.fill: parent
      anchors.margins: root.spaceLg
      spacing: root.spaceMd

      OText {
        Layout.fillWidth: true
        color: Theme.withOpacity(Theme.textActiveColor, 0.78)
        font.pixelSize: Math.round(Theme.fontMd * 0.9 * root.readableScale)
        horizontalAlignment: Text.AlignHCenter
        size: "xs"
        text: "LOCKED"
      }

      OText {
        Layout.fillWidth: true
        color: Theme.textActiveColor
        font.pixelSize: Math.round(Theme.fontHero * 1.06 * root.readableScale)
        horizontalAlignment: Text.AlignHCenter
        text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "h:mm AP")
        weight: "medium"
      }

      OText {
        Layout.fillWidth: true
        color: Theme.withOpacity(Theme.textActiveColor, 0.86)
        font.pixelSize: Math.round(Theme.fontLg * root.readableScale)
        horizontalAlignment: Text.AlignHCenter
        text: TimeService.format("date", "dddd, MMMM d")
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: statusRow.implicitHeight

        RowLayout {
          id: statusRow

          anchors.horizontalCenter: parent.horizontalCenter
          spacing: root.spaceSm

          Repeater {
            model: root.statusItems

            StatusPill {
              required property var modelData

              icon: modelData[0]
              value: modelData[1]
            }
          }
        }
      }

      OText {
        Layout.fillWidth: true
        color: Theme.textActiveColor
        font.pixelSize: Math.round(Theme.fontXl * 1.15 * root.readableScale)
        horizontalAlignment: Text.AlignHCenter
        text: MainService.fullName || "User"
        weight: "semibold"
      }

      OText {
        Layout.fillWidth: true
        color: Theme.withOpacity(Theme.textActiveColor, 0.9)
        font.pixelSize: Math.round(Theme.fontLg * root.readableScale)
        horizontalAlignment: Text.AlignHCenter
        text: root.userHostText
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.withOpacity("#ffffff", 0.14)
      }

      Rectangle {
        id: authCard

        Layout.fillWidth: true
        border.color: Theme.withOpacity("#ffffff", 0.24)
        border.width: 1
        color: Theme.withOpacity(Theme.bgElevated, 0.62)
        implicitHeight: cardColumn.implicitHeight + root.spaceMd * 2
        radius: Theme.radiusLg

        ColumnLayout {
          id: cardColumn

          anchors.fill: parent
          anchors.margins: root.spaceMd
          spacing: root.spaceSm

          RowLayout {
            Layout.fillWidth: true
            spacing: root.spaceSm

            Rectangle {
              Layout.preferredHeight: Math.round(Theme.controlHeightLg * root.roundedScale)
              Layout.preferredWidth: Math.round(Theme.controlHeightLg * root.roundedScale)
              color: Theme.withOpacity(Theme.activeColor, 0.3)
              radius: Theme.radiusFull

              OText {
                anchors.centerIn: parent
                bold: true
                color: Theme.textActiveColor
                font.pixelSize: Math.round(Theme.fontLg * 1.1 * root.readableScale)
                text: root.userInitials
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0

              OText {
                Layout.fillWidth: true
                bold: true
                color: Theme.textActiveColor
                font.pixelSize: Math.round(Theme.fontLg * root.readableScale)
                text: "Authentication"
              }

              OText {
                Layout.fillWidth: true
                color: Theme.withOpacity(Theme.textActiveColor, 0.84)
                font.pixelSize: Math.round(Theme.fontMd * root.readableScale)
                text: "Secure session"
              }
            }
          }

          Rectangle {
            id: passwordInput

            readonly property bool hasPassword: LockService.passwordBuffer.length > 0

            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(Theme.controlHeightLg * root.roundedScale)
            border.color: LockService.authState === LockService.authStates.fail ? Theme.critical : LockService.authenticating ? Theme.activeColor : Theme.borderMedium
            border.width: 2
            color: Theme.withOpacity(Theme.bgInput, 0.9)
            layer.enabled: LockService.authenticating
            radius: Theme.radiusFull
            visible: root.isMainMonitor

            Behavior on border.color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
            layer.effect: MultiEffect {
              shadowBlur: 12
              shadowColor: Theme.activeColor
              shadowEnabled: true
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: root.spaceSm
              anchors.rightMargin: root.spaceSm
              spacing: root.spaceSm

              Text {
                color: Theme.activeColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Math.round(Theme.iconSizeMd * root.readableScale)
                text: "󰌋"
              }

              OText {
                Layout.fillWidth: true
                color: LockService.authState === LockService.authStates.fail ? Theme.critical : Theme.textActiveColor
                font.pixelSize: Math.round(Theme.fontLg * root.readableScale)
                text: passwordInput.hasPassword ? "*".repeat(Math.min(LockService.passwordBuffer.length, 32)) : LockService.statusMessage
              }

              Rectangle {
                Layout.preferredHeight: Math.round(Theme.controlHeightXs * root.lockScale)
                Layout.preferredWidth: capsRow.implicitWidth + root.spaceSm * 2
                color: Theme.withOpacity(Theme.warning, 0.95)
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
                    id: capsText

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

          OText {
            Layout.fillWidth: true
            color: Theme.withOpacity(Theme.textActiveColor, 0.9)
            font.pixelSize: Math.round(Theme.fontMd * root.readableScale)
            horizontalAlignment: Text.AlignHCenter
            text: root.isMainMonitor ? root.authHint : "Unlock on main monitor"
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  component StatusPill: Rectangle {
    id: pillRoot

    property string icon: ""
    property string value: ""

    border.color: Theme.withOpacity("#ffffff", 0.2)
    border.width: 1
    color: Theme.withOpacity(Theme.bgElevated, 0.58)
    implicitHeight: pillRow.implicitHeight + Math.round(root.spaceSm * 1.25)
    implicitWidth: pillRow.implicitWidth + root.spaceMd
    radius: Theme.radiusFull

    RowLayout {
      id: pillRow

      anchors.centerIn: parent
      spacing: root.spaceSm * 0.7

      Text {
        color: Theme.activeColor
        font.family: Theme.iconFontFamily
        font.pixelSize: Math.round(Theme.iconSizeMd * root.readableScale)
        text: pillRoot.icon
        verticalAlignment: Text.AlignVCenter
      }

      OText {
        color: Theme.textActiveColor
        font.pixelSize: Math.round(Theme.fontMd * root.readableScale)
        text: pillRoot.value
      }
    }
  }
}
