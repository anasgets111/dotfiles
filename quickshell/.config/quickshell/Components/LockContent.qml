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

  readonly property int absoluteMaxWidth: 1400
  readonly property int absoluteMinWidth: 900
  readonly property string authHint: {
    if (LockService.authState === LockService.authStates.fail)
      return "Authentication failed. Press Enter to retry or Esc to cancel";
    if (LockService.authenticating)
      return "Authenticating...";
    return "Press Enter to unlock or Esc to cancel";
  }
  readonly property real fullNameScale: Math.max(root.lockScale, 1.68)
  required property bool isMainMonitor
  readonly property string layoutIcon: "󰌌"
  readonly property real lockScale: Theme.lockScale
  readonly property string networkIcon: NetworkService.linkType === "ethernet" ? "󰈀" : NetworkService.linkType === "wifi" ? "󰤨" : "󰤮"
  readonly property string networkLabel: NetworkService.linkType === "ethernet" ? "Ethernet" : NetworkService.linkType === "wifi" ? (NetworkService.wifiAps.find(a => a?.connected)?.ssid ?? "Wi-Fi") : "Offline"
  readonly property string powerIcon: BatteryService.isACPowered ? "󰚥" : "󰂄"
  readonly property real readableScale: Math.max(root.lockScale, 1.05)
  readonly property real rightTextScale: Math.max(root.lockScale, 1.36)
  readonly property int spaceLg: Math.round(Theme.spacingLg * root.lockScale)
  readonly property int spaceMd: Math.round(Theme.spacingMd * root.lockScale)
  readonly property int spaceSm: Math.round(Theme.spacingSm * root.lockScale)
  readonly property string userHostText: (MainService.username || "user") + "@" + (MainService.hostname || "localhost")
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
  readonly property string weatherLabel: !!WeatherService?.currentTemp ? String(WeatherService.currentTemp).split(" ")[0] : "--"
  readonly property string wmIcon: "󱂬"

  anchors.centerIn: parent
  implicitHeight: shell.implicitHeight
  implicitWidth: shell.implicitWidth

  transform: Translate {
    id: shakeTransform

  }

  SequentialAnimation {
    id: shakeAnimation

    PropertyAnimation {
      duration: 50
      from: 0
      property: "x"
      target: shakeTransform
      to: 10
    }

    PropertyAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: -10
    }

    PropertyAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: 10
    }

    PropertyAnimation {
      duration: 50
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

    border.color: Theme.borderMedium
    border.width: Theme.borderWidthThin
    color: Theme.withOpacity(Theme.bgCard, Theme.opacityStrong)
    implicitHeight: Math.max(leftContent.implicitHeight, rightContent.implicitHeight) + root.spaceLg * 2 + root.spaceMd
    implicitWidth: Math.max(root.absoluteMinWidth, Math.min(Math.round((root.parent ? root.parent.width : root.absoluteMinWidth) * 0.56), root.absoluteMaxWidth))
    layer.enabled: true
    radius: Theme.radiusLg

    layer.effect: MultiEffect {
      blurEnabled: true
      shadowBlur: Theme.shadowBlurMd
      shadowColor: Theme.shadowColorStrong
      shadowEnabled: true
      shadowVerticalOffset: Theme.shadowOffsetY * 2
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: root.spaceLg
      spacing: root.spaceLg

      Rectangle {
        id: leftPane

        Layout.fillHeight: true
        Layout.preferredWidth: Math.round((shell.width - root.spaceLg * 3) * 0.38)
        border.color: Theme.activeSubtle
        border.width: Theme.borderWidthThin
        clip: true
        color: Theme.withOpacity(Theme.activeColor, 0.2)
        radius: Theme.radiusMd

        Rectangle {
          anchors.fill: parent
          color: "transparent"
          radius: parent.radius

          gradient: Gradient {
            GradientStop {
              color: Theme.activeLight
              position: 0
            }

            GradientStop {
              color: Theme.withOpacity(Theme.bgCard, 0)
              position: 0.72
            }
          }
        }

        ColumnLayout {
          id: leftContent

          anchors.fill: parent
          anchors.margins: root.spaceLg
          spacing: root.spaceMd

          OText {
            Layout.fillWidth: true
            color: Theme.textInactiveColor
            size: "xs"
            sizeMultiplier: root.readableScale
            text: "LOCKED"
          }

          OText {
            Layout.fillWidth: true
            bold: true
            color: Theme.textActiveColor
            font.pixelSize: Math.round(Theme.fontHero * 0.94 * root.readableScale)
            text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "h:mm AP")
          }

          OText {
            Layout.fillWidth: true
            color: Theme.textInactiveColor
            size: "md"
            sizeMultiplier: root.readableScale
            text: TimeService.format("date", "dddd, MMMM d")
          }

          ThinDivider {
          }

          Repeater {
            model: [[root.weatherIcon, root.weatherLabel], [root.powerIcon, BatteryService.isLaptopBattery ? BatteryService.percentage + "%" : "Desktop"], [root.networkIcon, root.networkLabel], [root.layoutIcon, KeyboardLayoutService.currentLayout || "N/A"], [root.wmIcon, MainService.currentWM || "unknown"]]

            StatusRow {
              required property var modelData

              icon: modelData[0]
              value: modelData[1]
            }
          }

          Item {
            Layout.preferredHeight: Math.round(root.spaceMd * root.readableScale)
          }
        }
      }

      Rectangle {
        id: rightPane

        Layout.fillHeight: true
        Layout.fillWidth: true
        border.color: Theme.borderLight
        border.width: Theme.borderWidthThin
        clip: true
        color: Theme.withOpacity(Theme.bgElevated, Theme.opacityStrong)
        radius: Theme.radiusMd

        ColumnLayout {
          id: rightContent

          anchors.fill: parent
          anchors.margins: root.spaceLg
          spacing: root.spaceMd

          Item {
            Layout.fillHeight: true
          }

          ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            spacing: root.spaceSm

            OText {
              Layout.fillWidth: true
              bold: true
              color: Theme.textActiveColor
              horizontalAlignment: Text.AlignHCenter
              size: "xl"
              sizeMultiplier: root.fullNameScale
              text: MainService.fullName || "User"
            }

            OText {
              Layout.fillWidth: true
              color: Theme.textInactiveColor
              horizontalAlignment: Text.AlignHCenter
              size: "md"
              sizeMultiplier: root.rightTextScale
              text: root.userHostText
            }
          }

          Rectangle {
            id: authCard

            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            border.color: Theme.withOpacity(Theme.activeColor, Theme.opacityMedium)
            border.width: Theme.borderWidthThin
            color: Theme.withOpacity(Theme.bgElevatedAlt, Theme.opacityStrong)
            implicitHeight: cardColumn.implicitHeight + root.spaceMd * 2
            radius: Theme.radiusMd

            ColumnLayout {
              id: cardColumn

              anchors.fill: parent
              anchors.margins: root.spaceMd
              spacing: root.spaceMd

              RowLayout {
                Layout.fillWidth: true
                spacing: root.spaceSm

                Text {
                  color: Theme.activeColor
                  font.family: Theme.iconFontFamily
                  font.pixelSize: Math.round(Theme.iconSizeMd * root.rightTextScale)
                  text: "󰌾"
                }

                OText {
                  Layout.fillWidth: true
                  bold: true
                  color: Theme.textActiveColor
                  size: "md"
                  sizeMultiplier: root.rightTextScale
                  text: "Authentication"
                }
              }

              Rectangle {
                id: passwordInput

                readonly property bool hasPassword: LockService.passwordBuffer.length > 0

                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Theme.controlHeightLg * root.rightTextScale)
                border.color: LockService.authState === LockService.authStates.fail ? Theme.critical : LockService.authenticating ? Theme.activeColor : Theme.borderMedium
                border.width: Theme.borderWidthMedium
                color: Theme.bgInput
                radius: Theme.radiusSm
                visible: root.isMainMonitor

                Behavior on border.color {
                  ColorAnimation {
                    duration: Theme.animationDuration
                  }
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: root.spaceSm
                  anchors.rightMargin: root.spaceSm
                  spacing: root.spaceSm

                  Text {
                    color: Theme.activeColor
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Math.round(Theme.iconSizeSm * root.rightTextScale)
                    text: "󰌋"
                  }

                  OText {
                    Layout.fillWidth: true
                    color: LockService.authState === LockService.authStates.fail ? Theme.critical : Theme.textActiveColor
                    font.pixelSize: Math.round(Theme.fontLg * root.rightTextScale)
                    text: passwordInput.hasPassword ? "*".repeat(Math.min(LockService.passwordBuffer.length, 32)) : LockService.statusMessage
                  }

                  Rectangle {
                    Layout.preferredHeight: Math.round(Theme.controlHeightXs * root.lockScale)
                    Layout.preferredWidth: capsText.implicitWidth + root.spaceSm * 2
                    color: Theme.warning
                    radius: Theme.radiusSm
                    visible: KeyboardLayoutService.capsOn

                    OText {
                      id: capsText

                      anchors.centerIn: parent
                      bold: true
                      color: Theme.bgColor
                      size: "sm"
                      sizeMultiplier: root.rightTextScale
                      text: "CAPS"
                    }
                  }
                }
              }

              OText {
                Layout.fillWidth: true
                color: Theme.textInactiveColor
                horizontalAlignment: Text.AlignHCenter
                size: "md"
                sizeMultiplier: root.rightTextScale
                text: root.isMainMonitor ? root.authHint : "Unlock on main monitor"
                wrapMode: Text.WordWrap
              }
            }
          }

          Item {
            Layout.fillHeight: true
          }
        }
      }
    }
  }

  component StatusRow: RowLayout {
    property string icon: ""
    property string value: ""

    Layout.fillWidth: true
    spacing: root.spaceSm

    Text {
      Layout.preferredWidth: Math.round(Theme.iconSizeLg * root.readableScale * 1.3)
      color: Theme.activeColor
      font.family: Theme.iconFontFamily
      font.pixelSize: Math.round(Theme.iconSizeMd * root.readableScale)
      text: parent.icon
      verticalAlignment: Text.AlignVCenter
    }

    OText {
      Layout.fillWidth: true
      color: Theme.textActiveColor
      size: "md"
      sizeMultiplier: root.readableScale
      text: parent.value
    }
  }
  component ThinDivider: Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: Theme.borderWidthThin
    color: Theme.borderSubtle
  }
}
