pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Services
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.WM

FocusScope {
  id: root

  required property var lockContext
  required property var lockSurface
  required property var theme

  // Theme and tokens
  readonly property color accentColor: theme?.mauve ?? "#cba6f7"
  readonly property color panelGradTop: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.70)
  readonly property color panelGradBottom: Qt.rgba(24 / 255, 24 / 255, 37 / 255, 0.66)
  readonly property color borderStrong: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.20)
  readonly property color borderSoft: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.08)
  readonly property color pillBg: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
  readonly property color pillBorder: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
  readonly property color warnBg: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.18)
  readonly property color warnBorder: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.36)
  readonly property color dividerColor: Qt.rgba(124 / 255, 124 / 255, 148 / 255, 0.25)
  readonly property color inputBg: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.45)
  readonly property color inputBorderDefault: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.18)

  // Derived flags and metrics
  readonly property bool isCompact: width < 440
  readonly property bool hasScreen: lockSurface?.hasScreen ?? false
  readonly property bool isPrimaryMonitor: lockSurface?.isMainMonitor ?? false
  readonly property string screenName: lockSurface?.screen?.name ?? "no-screen"
  readonly property bool shouldShowContent: hasScreen
  readonly property bool shouldAcceptInput: shouldShowContent && isPrimaryMonitor
  readonly property int pillPaddingVertical: isCompact ? 6 : 8
  readonly property int panelMargin: 16
  readonly property int contentSpacing: 14

  anchors.centerIn: parent
  width: parent.width * 0.47
  height: contentColumn.implicitHeight + panelMargin * 2
  focus: true
  visible: shouldShowContent
  opacity: shouldShowContent ? 1 : 0
  scale: shouldShowContent ? 1 : 0.98

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

  layer.enabled: shouldShowContent
  layer.mipmap: false
  layer.effect: MultiEffect {
    blurEnabled: false
    shadowBlur: 0.9
    shadowColor: Qt.rgba(0, 0, 0, 0.35)
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 10
  }

  transform: Translate {
    id: shakeTransform
    x: 0
  }

  function shake() {
    shakeAnimation.restart();
  }
  function requestFocusIfNeeded() {
    if (shouldShowContent && isPrimaryMonitor)
      forceActiveFocus();
  }
  function wakeSystem(action) {
    if (isPrimaryMonitor)
      IdleService.wake(action);
  }
  function focusAndWake(action) {
    wakeSystem(action);
    forceActiveFocus();
  }

  Keys.onPressed: event => {
    wakeSystem("key-press");
    if (!shouldShowContent || lockContext.authenticating)
      return;
    const key = event.key;
    if (key === Qt.Key_Enter || key === Qt.Key_Return) {
      lockContext.submitOrStart();
      event.accepted = true;
      return;
    }
    if (key === Qt.Key_Backspace) {
      const next = (event.modifiers & Qt.ControlModifier) ? "" : lockContext.passwordBuffer.slice(0, -1);
      lockContext.passwordBuffer = next;
      event.accepted = true;
      return;
    }
    if (key === Qt.Key_Escape) {
      lockContext.passwordBuffer = "";
      event.accepted = true;
      return;
    }
    if (event.text && event.text.length === 1) {
      const code = event.text.charCodeAt(0);
      if (code >= 0x20 && code <= 0x7E) {
        lockContext.passwordBuffer = (lockContext.passwordBuffer + event.text);
        event.accepted = true;
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.AllButtons
    propagateComposedEvents: true
    onEntered: root.focusAndWake("pointer-enter")
    onPressed: root.focusAndWake("pointer-press")
    onWheel: root.focusAndWake("pointer-wheel")
  }

  Connections {
    target: root.lockSurface
    function onHasScreenChanged() {
      if (root.lockSurface?.hasScreen)
        root.requestFocusIfNeeded();
    }
  }

  Connections {
    target: root.lockContext
    function onAuthStateChanged() {
      const state = root.lockContext.authState;
      if (state === "error" || state === "fail")
        root.shake();
    }
  }

  Component.onCompleted: requestFocusIfNeeded()

  SequentialAnimation {
    id: shakeAnimation
    NumberAnimation {
      target: shakeTransform
      property: "x"
      to: 10
      duration: 40
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: shakeTransform
      property: "x"
      to: -10
      duration: 70
    }
    NumberAnimation {
      target: shakeTransform
      property: "x"
      to: 6
      duration: 60
    }
    NumberAnimation {
      target: shakeTransform
      property: "x"
      to: -4
      duration: 50
    }
    NumberAnimation {
      target: shakeTransform
      property: "x"
      to: 0
      duration: 40
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 16
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: root.panelGradTop
      }
      GradientStop {
        position: 1.0
        color: root.panelGradBottom
      }
    }
    border.width: 1
    border.color: root.borderStrong

    Rectangle {
      anchors.fill: parent
      radius: 16
      color: "transparent"
      border.width: 1
      border.color: root.borderSoft
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
        horizontalAlignment: Text.AlignHCenter
        color: root.theme.text
        font.bold: true
        font.pixelSize: 74
        text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "hh:mm")
      }

      Text {
        Layout.alignment: Qt.AlignVCenter
        visible: !TimeService.use24Hour && text !== ""
        horizontalAlignment: Text.AlignHCenter
        color: root.theme.subtext1
        font.bold: true
        font.pixelSize: 30
        text: TimeService.format("time", "AP")
      }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: root.width - 64
      horizontalAlignment: Text.AlignHCenter
      color: root.theme.subtext0
      font.pixelSize: 21
      text: TimeService.format("date", "dddd, d MMMM yyyy")
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: root.width - 64
      Layout.topMargin: 2
      visible: root.shouldShowContent && text.length > 0
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      color: root.theme.subtext1
      font.bold: true
      font.pixelSize: 24
      text: MainService.fullName ?? ""
    }

    RowLayout {
      id: infoPillsRow
      readonly property int lineHeight: Math.max(hostIcon.font.pixelSize, hostText.font.pixelSize)
      readonly property int pillHeight: Math.max(lineHeight, weatherPill.contentHeight) + root.pillPaddingVertical * 2

      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: root.width - 64
      visible: root.shouldShowContent
      spacing: 10

      Rectangle {
        id: weatherPill
        property int contentHeight: weatherContent.contentHeight

        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Math.floor((root.width - 64 - parent.spacing) / 2)
        Layout.minimumWidth: 120
        Layout.preferredHeight: infoPillsRow.pillHeight
        visible: WeatherService
        opacity: visible ? 1 : 0
        radius: 10
        color: root.pillBg
        border.width: 1
        border.color: root.pillBorder

        Behavior on opacity {
          NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
          }
        }

        ColumnLayout {
          id: weatherContent
          readonly property string icon: WeatherService?.getWeatherIconFromCode() ?? ""
          readonly property string temp: WeatherService?.currentTemp ?? ""
          readonly property string place: WeatherService?.locationName ?? ""
          readonly property bool isStale: WeatherService?.isStale ?? false
          readonly property int contentHeight: fitsInline ? Math.max(weatherIcon.font.pixelSize, weatherTemp.font.pixelSize, weatherPlaceInline.font.pixelSize) : Math.max(weatherIcon.font.pixelSize, weatherTemp.font.pixelSize) + spacing + (weatherPlace.visible ? weatherPlace.font.pixelSize : 0)
          readonly property bool fitsInline: {
            const needed = weatherIcon.implicitWidth + topRow.spacing + weatherTemp.implicitWidth + (place.length > 0 ? topRow.spacing + weatherPlaceInline.implicitWidth : 0) + (isStale ? topRow.spacing + staleText.implicitWidth + 10 : 0);
            return needed <= width;
          }

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
              visible: !root.isCompact && text.length > 0 && weatherContent.fitsInline
              elide: Text.ElideRight
              color: root.theme.subtext0
              font.pixelSize: 16
              text: weatherContent.place
            }

            Rectangle {
              Layout.alignment: Qt.AlignVCenter
              visible: weatherContent.isStale
              implicitHeight: 18
              implicitWidth: staleText.implicitWidth + 10
              radius: 6
              color: root.warnBg
              border.width: 1
              border.color: root.warnBorder

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
            visible: !root.isCompact && text.length > 0 && !weatherContent.fitsInline
            elide: Text.ElideRight
            color: root.theme.subtext0
            font.pixelSize: 16
            text: weatherContent.place
          }
        }
      }

      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Math.floor((root.width - 64 - parent.spacing) / 2)
        Layout.minimumWidth: 120
        Layout.preferredHeight: infoPillsRow.pillHeight
        opacity: 1
        radius: 10
        color: root.pillBg
        border.width: 1
        border.color: root.pillBorder

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
            elide: Text.ElideRight
            color: root.theme.subtext0
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
      visible: root.isPrimaryMonitor
      radius: 1
      color: root.dividerColor
    }

    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredHeight: 46
      Layout.preferredWidth: Math.min(root.width - 32, 440)
      visible: root.isPrimaryMonitor
      enabled: root.shouldAcceptInput
      radius: 12
      color: root.inputBg
      border.width: 1
      border.color: root.lockContext.authState ? root.theme.love : root.inputBorderDefault

      Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        opacity: root.activeFocus ? 0.55 : 0.0
        border.width: 2
        border.color: root.accentColor
        Behavior on opacity {
          NumberAnimation {
            duration: 160
          }
        }
      }

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
            implicitHeight: 10
            implicitWidth: 10
            radius: 5
            scale: 0.8
            color: root.lockContext.authenticating ? root.theme.mauve : root.theme.overlay2
            Component.onCompleted: scale = 1.0
            Behavior on scale {
              NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
              }
            }
            SequentialAnimation on opacity {
              running: true
              NumberAnimation {
                from: 0
                to: 1
                duration: 90
                easing.type: Easing.OutCubic
              }
            }
          }
        }
      }

      Text {
        anchors.centerIn: parent
        opacity: root.lockContext.passwordBuffer.length ? 0 : 1
        font.pixelSize: 21
        color: root.lockContext.authenticating ? root.accentColor : root.lockContext.authState ? root.theme.love : root.theme.overlay1
        text: root.lockContext.authenticating ? "Authenticating…" : root.lockContext.authState === "error" ? "Error" : root.lockContext.authState === "max" ? "Too many tries" : root.lockContext.authState === "fail" ? "Incorrect password" : "Enter password"
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
        visible: KeyboardLayoutService.capsOn
        implicitHeight: capsText.height + 7
        implicitWidth: capsText.width + 12
        radius: 8
        color: root.pillBg
        border.width: 1
        border.color: root.pillBorder

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
      visible: root.isPrimaryMonitor
      opacity: 0.9
      spacing: 12

      Text {
        color: root.theme.overlay1
        font.pixelSize: 16
        text: "Press Enter to unlock"
      }
      Rectangle {
        implicitHeight: 4
        implicitWidth: 4
        radius: 2
        color: root.theme.overlay0
      }
      Text {
        color: root.theme.overlay1
        font.pixelSize: 16
        text: "Esc clears input"
      }

      Rectangle {
        visible: KeyboardLayoutService.currentLayout.length > 0
        implicitHeight: layoutText.height + 7
        implicitWidth: layoutText.width + 12
        radius: 8
        color: root.pillBg
        border.width: 1
        border.color: root.pillBorder

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
