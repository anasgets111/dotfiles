pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Services
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.WM

Item {
  id: root

  // Theme and tokens
  readonly property color accentColor: theme.mauve
  readonly property color borderSoft: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.08)
  readonly property color borderStrong: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.20)
  readonly property int contentSpacing: LockService.contentSpacing
  readonly property color dividerColor: Qt.rgba(124 / 255, 124 / 255, 148 / 255, 0.25)
  readonly property bool hasScreen: lockSurface?.hasScreen ?? false
  readonly property color inputBg: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.45)
  readonly property color inputBorderDefault: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.18)

  // Derived flags and metrics
  readonly property bool isCompact: width < LockService.compactWidthThreshold
  readonly property bool isPrimaryMonitor: lockSurface?.isMainMonitor ?? false
  required property var lockContext
  required property var lockSurface
  readonly property color panelGradBottom: Qt.rgba(24 / 255, 24 / 255, 37 / 255, 0.66)
  readonly property color panelGradTop: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.70)
  readonly property int panelMargin: LockService.panelMargin
  readonly property color pillBg: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
  readonly property color pillBorder: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
  readonly property int pillPaddingVertical: isCompact ? 6 : 8

  // Use theme from LockService singleton
  readonly property var theme: LockService.theme
  readonly property color warnBg: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.18)
  readonly property color warnBorder: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.36)

  function shake() {
    shakeAnimation.restart();
  }

  anchors.centerIn: parent
  height: contentColumn.implicitHeight + panelMargin * 2
  layer.enabled: hasScreen
  layer.mipmap: false
  opacity: hasScreen ? 1 : 0
  scale: hasScreen ? 1 : 0.98
  visible: hasScreen
  width: parent.width * LockService.panelWidthRatio

  layer.effect: MultiEffect {
    blurEnabled: false
    shadowBlur: 0.9
    shadowColor: Qt.rgba(0, 0, 0, 0.35)
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 10
  }
  Behavior on opacity {
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }
  Behavior on scale {
    NumberAnimation {
      duration: 220
      easing.type: Easing.OutCubic
    }
  }
  transform: Translate {
    id: shakeTransform

    x: 0
  }

  // Keyboard handling is now done at the LockScreen level via LockService.handleGlobalKeyPress
  // The outer FocusScope guarantees input reaches the handler regardless of focus state

  Connections {
    function onAuthStateChanged() {
      const state = root.lockContext.authState;
      if (state === "error" || state === "fail")
        root.shake();
    }

    target: root.lockContext
  }

  SequentialAnimation {
    id: shakeAnimation

    NumberAnimation {
      duration: 40
      easing.type: Easing.OutCubic
      property: "x"
      target: shakeTransform
      to: 10
    }

    NumberAnimation {
      duration: 70
      property: "x"
      target: shakeTransform
      to: -10
    }

    NumberAnimation {
      duration: 60
      property: "x"
      target: shakeTransform
      to: 6
    }

    NumberAnimation {
      duration: 50
      property: "x"
      target: shakeTransform
      to: -4
    }

    NumberAnimation {
      duration: 40
      property: "x"
      target: shakeTransform
      to: 0
    }
  }

  Rectangle {
    anchors.fill: parent
    border.color: root.borderStrong
    border.width: 1
    radius: 16

    gradient: Gradient {
      GradientStop {
        color: root.panelGradTop
        position: 0.0
      }

      GradientStop {
        color: root.panelGradBottom
        position: 1.0
      }
    }

    Rectangle {
      anchors.fill: parent
      border.color: root.borderSoft
      border.width: 1
      color: "transparent"
      radius: 16
    }
  }

  ColumnLayout {
    id: contentColumn

    anchors.fill: parent
    anchors.margins: root.panelMargin
    spacing: root.contentSpacing

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 10

      Text {
        Layout.alignment: Qt.AlignVCenter
        color: root.theme.text
        font.bold: true
        font.pixelSize: 74
        horizontalAlignment: Text.AlignHCenter
        text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "hh:mm")
      }

      Text {
        Layout.alignment: Qt.AlignVCenter
        color: root.theme.subtext1
        font.bold: true
        font.pixelSize: 30
        horizontalAlignment: Text.AlignHCenter
        text: TimeService.format("time", "AP")
        visible: !TimeService.use24Hour && text !== ""
      }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: root.width - 64
      color: root.theme.subtext0
      font.pixelSize: 21
      horizontalAlignment: Text.AlignHCenter
      text: TimeService.format("date", "dddd, d MMMM yyyy")
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: root.width - 64
      Layout.topMargin: 2
      color: root.theme.subtext1
      elide: Text.ElideRight
      font.bold: true
      font.pixelSize: 24
      horizontalAlignment: Text.AlignHCenter
      text: MainService.fullName ?? ""
      visible: root.hasScreen && text.length > 0
    }

    RowLayout {
      id: infoPillsRow

      readonly property int lineHeight: Math.max(hostIcon.font.pixelSize, hostText.font.pixelSize)
      readonly property int pillHeight: Math.max(lineHeight, weatherPill.contentHeight) + root.pillPaddingVertical * 2

      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: root.width - 64
      spacing: 10
      visible: root.hasScreen

      Rectangle {
        id: weatherPill

        property int contentHeight: weatherContent.contentHeight

        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Math.floor((root.width - 64 - parent.spacing) / 2)
        Layout.minimumWidth: 120
        Layout.preferredHeight: infoPillsRow.pillHeight
        border.color: root.pillBorder
        border.width: 1
        color: root.pillBg
        opacity: visible ? 1 : 0
        radius: 10
        visible: WeatherService

        Behavior on opacity {
          NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
          }
        }

        ColumnLayout {
          id: weatherContent

          readonly property int contentHeight: fitsInline ? Math.max(weatherIcon.font.pixelSize, weatherTemp.font.pixelSize, weatherPlaceInline.font.pixelSize) : Math.max(weatherIcon.font.pixelSize, weatherTemp.font.pixelSize) + spacing + (weatherPlace.visible ? weatherPlace.font.pixelSize : 0)
          readonly property bool fitsInline: {
            const needed = weatherIcon.implicitWidth + topRow.spacing + weatherTemp.implicitWidth + (place.length > 0 ? topRow.spacing + weatherPlaceInline.implicitWidth : 0) + (isStale ? topRow.spacing + staleText.implicitWidth + 10 : 0);
            return needed <= width;
          }
          readonly property string icon: WeatherService?.weatherInfo().icon ?? ""
          readonly property bool isStale: WeatherService?.isDataStale() ?? false
          readonly property string place: WeatherService?.locationName ?? ""
          readonly property string temp: WeatherService?.currentTemp ?? ""

          anchors.fill: parent
          anchors.margins: root.isCompact ? 8 : 10
          spacing: 2

          RowLayout {
            id: topRow

            Layout.fillWidth: true
            spacing: 8

            Text {
              id: weatherIcon

              Layout.alignment: Qt.AlignVCenter
              color: root.theme.text
              font.pixelSize: 27
              text: weatherContent.icon
            }

            Text {
              id: weatherTemp

              Layout.alignment: Qt.AlignVCenter
              color: root.theme.text
              font.bold: true
              font.pixelSize: 21
              text: {
                const t = weatherContent.temp;
                const i = t.indexOf("°");
                return i >= 0 ? t.split(" ")[0] : t;
              }
            }

            Text {
              id: weatherPlaceInline

              Layout.alignment: Qt.AlignVCenter
              Layout.fillWidth: true
              color: root.theme.subtext0
              elide: Text.ElideRight
              font.pixelSize: 16
              text: weatherContent.place
              visible: !root.isCompact && text.length > 0 && weatherContent.fitsInline
            }

            Rectangle {
              Layout.alignment: Qt.AlignVCenter
              border.color: root.warnBorder
              border.width: 1
              color: root.warnBg
              implicitHeight: 18
              implicitWidth: staleText.implicitWidth + 10
              radius: 6
              visible: weatherContent.isStale

              Text {
                id: staleText

                anchors.centerIn: parent
                color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 1.0)
                font.bold: true
                font.pixelSize: 16
                text: "stale"
              }
            }
          }

          Text {
            id: weatherPlace

            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            color: root.theme.subtext0
            elide: Text.ElideRight
            font.pixelSize: 16
            text: weatherContent.place
            visible: !root.isCompact && text.length > 0 && !weatherContent.fitsInline
          }
        }
      }

      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Math.floor((root.width - 64 - parent.spacing) / 2)
        Layout.minimumWidth: 120
        Layout.preferredHeight: infoPillsRow.pillHeight
        border.color: root.pillBorder
        border.width: 1
        color: root.pillBg
        opacity: 1
        radius: 10

        RowLayout {
          anchors.fill: parent
          anchors.margins: root.isCompact ? 8 : 10
          spacing: 8

          Text {
            id: hostIcon

            Layout.alignment: Qt.AlignVCenter
            color: root.theme.text
            font.pixelSize: 21
            text: "💻"
          }

          Text {
            id: hostText

            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            color: root.theme.subtext0
            elide: Text.ElideRight
            font.pixelSize: 21
            text: {
              const service = MainService;
              const host = service?.hostname ? String(service.hostname) : "";
              return host.length > 0 ? host : "localhost";
            }
          }
        }
      }
    }

    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredHeight: 1
      Layout.preferredWidth: Math.min(root.width - 64, 420)
      Layout.topMargin: 4
      color: root.dividerColor
      radius: 1
      visible: root.isPrimaryMonitor
    }

    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredHeight: 46
      Layout.preferredWidth: Math.min(root.width - 32, 440)
      border.color: root.lockContext.authState ? root.theme.love : root.inputBorderDefault
      border.width: 1
      color: root.inputBg
      radius: 12
      visible: root.isPrimaryMonitor

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        color: root.theme.overlay1
        font.pixelSize: 21
        opacity: 0.9
        text: "🔒"
      }

      RowLayout {
        anchors.centerIn: parent
        spacing: 7

        Repeater {
          model: root.lockContext.passwordBuffer.length

          delegate: Rectangle {
            color: root.lockContext.authenticating ? root.theme.mauve : root.theme.overlay2
            implicitHeight: 10
            implicitWidth: 10
            radius: 5
            scale: 0.8

            SequentialAnimation on opacity {
              running: true

              NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
                from: 0
                to: 1
              }
            }
            Behavior on scale {
              NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
              }
            }

            Component.onCompleted: scale = 1.0
          }
        }
      }

      Text {
        anchors.centerIn: parent
        color: root.lockContext.authenticating ? root.accentColor : root.lockContext.authState ? root.theme.love : root.theme.overlay1
        font.pixelSize: 21
        opacity: root.lockContext.passwordBuffer.length ? 0 : 1
        text: root.lockContext.statusMessage

        Behavior on color {
          ColorAnimation {
            duration: 140
          }
        }
        Behavior on opacity {
          NumberAnimation {
            duration: 120
          }
        }
      }

      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        border.color: root.pillBorder
        border.width: 1
        color: root.pillBg
        implicitHeight: capsText.height + 7
        implicitWidth: capsText.width + 12
        radius: 8
        visible: KeyboardLayoutService.capsOn

        Text {
          id: capsText

          anchors.centerIn: parent
          color: root.theme.love
          font.pixelSize: 14
          text: "Caps Lock"
        }
      }
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      opacity: 0.9
      spacing: 12
      visible: root.isPrimaryMonitor

      Text {
        color: root.theme.overlay1
        font.pixelSize: 16
        text: "Press Enter to unlock"
      }

      Rectangle {
        color: root.theme.overlay0
        implicitHeight: 4
        implicitWidth: 4
        radius: 2
      }

      Text {
        color: root.theme.overlay1
        font.pixelSize: 16
        text: "Esc clears input"
      }

      Rectangle {
        border.color: root.pillBorder
        border.width: 1
        color: root.pillBg
        implicitHeight: layoutText.height + 7
        implicitWidth: layoutText.width + 12
        radius: 8
        visible: KeyboardLayoutService.currentLayout.length > 0

        Text {
          id: layoutText

          anchors.centerIn: parent
          color: root.theme.overlay1
          font.pixelSize: 14
          text: KeyboardLayoutService.currentLayout
        }
      }
    }
  }
}
