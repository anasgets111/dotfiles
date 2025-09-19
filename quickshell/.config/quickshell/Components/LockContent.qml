pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Services.Utils
import qs.Services
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.WM

FocusScope {
  id: root

  // Public API - Required properties
  required property var lockContext
  required property var lockSurface

  // Public API - Configuration
  readonly property color accentColor: lockContext?.theme?.mauve ?? "#cba6f7"
  readonly property bool isCompact: width < 440
  readonly property bool hasScreen: lockSurface?.hasScreen ?? false
  readonly property bool isPrimaryMonitor: lockSurface?.isMainMonitor ?? false

  // Private constants
  readonly property int pillPaddingVertical: isCompact ? 6 : 8
  readonly property int panelMargin: 16
  readonly property int contentSpacing: 14

  // Computed properties
  readonly property bool shouldShowContent: hasScreen
  readonly property bool shouldAcceptInput: shouldShowContent && isPrimaryMonitor
  readonly property string screenName: lockSurface?.screen?.name ?? "no-screen"

  // Configuration
  focus: true
  anchors.centerIn: parent
  width: parent.width * 0.47
  height: contentColumn.implicitHeight + panelMargin * 2

  // Visibility and animations
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

  // Visual effects
  layer.enabled: shouldShowContent
  layer.mipmap: false
  layer.effect: MultiEffect {
    blurEnabled: false
    shadowBlur: 0.9
    shadowColor: Qt.rgba(0, 0, 0, 0.35)
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 10
  }

  // Shake animation transform
  transform: Translate {
    id: shakeTransform
    x: 0
  }

  // Public methods
  function shake() {
    shakeAnimation.restart();
  }

  // Private methods
  function requestFocusIfNeeded(reason) {
    if (!shouldShowContent || !isPrimaryMonitor)
      return;
    root.forceActiveFocus();
    if (lockContext) {
      Logger.log("LockContent", "single-shot focus request (primary): " + reason);
    }
  }

  function wakeSystem(action) {
    if (isPrimaryMonitor) {
      IdleService.wake(action);
    }
  }

  // Input handling
  Keys.onPressed: event => {
    wakeSystem("key-press");

    if (!shouldShowContent || lockContext.authenticating)
      return;
    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
      lockContext.submitOrStart();
      event.accepted = true;
    } else if (event.key === Qt.Key_Backspace) {
      const newBuffer = event.modifiers & Qt.ControlModifier ? "" : lockContext.passwordBuffer.slice(0, -1);
      lockContext.setPasswordBuffer(newBuffer);
      event.accepted = true;
    } else if (event.key === Qt.Key_Escape) {
      lockContext.setPasswordBuffer("");
      event.accepted = true;
    } else if (event.text?.length === 1) {
      const charCode = event.text.charCodeAt(0);
      if (charCode >= 0x20 && charCode <= 0x7E) {
        lockContext.setPasswordBuffer(lockContext.passwordBuffer + event.text);
        event.accepted = true;
      }
    }
  }

  // Wake system on mouse interactions
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.AllButtons
    propagateComposedEvents: true

    onEntered: {
      root.wakeSystem("pointer-enter");
      root.forceActiveFocus();
    }
    onPressed: {
      root.wakeSystem("pointer-press");
      root.forceActiveFocus();
    }
    onWheel: {
      root.wakeSystem("pointer-wheel");
      root.forceActiveFocus();
    }
  }

  // Connections
  Connections {
    target: root.lockSurface
    function onHasScreenChanged() {
      if (root.lockSurface?.hasScreen) {
        root.requestFocusIfNeeded("hasScreen changed -> true");
      }
    }
  }

  Connections {
    target: root.lockContext
    function onAuthStateChanged() {
      const state = root.lockContext.authState;
      if (state === "error" || state === "fail") {
        root.shake();
      }
    }
  }

  Component.onCompleted: {
    requestFocusIfNeeded("component completed");
  }

  // Shake animation
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

  // Background
  Rectangle {
    anchors.fill: parent
    radius: 16
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.70)
      }
      GradientStop {
        position: 1.0
        color: Qt.rgba(24 / 255, 24 / 255, 37 / 255, 0.66)
      }
    }
    border.width: 1
    border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.20)

    Rectangle {
      anchors.fill: parent
      radius: 16
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.08)
    }
  }

  // Main content
  ColumnLayout {
    id: contentColumn
    anchors.fill: parent
    anchors.margins: root.panelMargin
    spacing: root.contentSpacing

    // Time display
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 10

      Text {
        Layout.alignment: Qt.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        color: root.lockContext.theme.text
        font.bold: true
        font.pixelSize: 74
        text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "hh:mm")
      }

      Text {
        Layout.alignment: Qt.AlignVCenter
        visible: !TimeService.use24Hour && text !== ""
        horizontalAlignment: Text.AlignHCenter
        color: root.lockContext.theme.subtext1
        font.bold: true
        font.pixelSize: 30
        text: TimeService.format("time", "AP")
      }
    }

    // Date display
    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: root.width - 64
      horizontalAlignment: Text.AlignHCenter
      color: root.lockContext.theme.subtext0
      font.pixelSize: 21
      text: TimeService.format("date", "dddd, d MMMM yyyy")
    }

    // User name
    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: root.width - 64
      Layout.topMargin: 2
      visible: root.shouldShowContent && text.length > 0
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      color: root.lockContext.theme.subtext1
      font.bold: true
      font.pixelSize: 24
      text: MainService.fullName ?? ""
    }

    // Info pills row
    RowLayout {
      id: infoPillsRow
      readonly property int lineHeight: Math.max(hostIcon.font.pixelSize, hostText.font.pixelSize)
      readonly property int pillHeight: Math.max(lineHeight, weatherPill.contentHeight) + root.pillPaddingVertical * 2

      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: root.width - 64
      visible: root.shouldShowContent
      spacing: 10

      // Weather pill
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
        color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
        border.width: 1
        border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)

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
            const requiredWidth = weatherIcon.implicitWidth + topRow.spacing + weatherTemp.implicitWidth + (place.length > 0 ? topRow.spacing + weatherPlaceInline.implicitWidth : 0) + (isStale ? topRow.spacing + staleBadge.implicitWidth : 0);
            return requiredWidth <= width;
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
              color: root.lockContext.theme.text
              font.pixelSize: 27
              text: weatherContent.icon
            }

            Text {
              id: weatherTemp
              Layout.alignment: Qt.AlignVCenter
              color: root.lockContext.theme.text
              font.bold: true
              font.pixelSize: 21
              text: {
                const tempStr = weatherContent.temp;
                const degreeIndex = tempStr.indexOf("°");
                return degreeIndex >= 0 ? tempStr.split(" ")[0] : tempStr;
              }
            }

            Text {
              id: weatherPlaceInline
              Layout.alignment: Qt.AlignVCenter
              Layout.fillWidth: true
              visible: !root.isCompact && text.length > 0 && weatherContent.fitsInline
              elide: Text.ElideRight
              color: root.lockContext.theme.subtext0
              font.pixelSize: 16
              text: weatherContent.place
            }

            Rectangle {
              id: staleBadge
              Layout.alignment: Qt.AlignVCenter
              visible: weatherContent.isStale
              implicitHeight: 18
              implicitWidth: staleText.implicitWidth + 10
              radius: 6
              color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.18)
              border.width: 1
              border.color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.36)

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
            color: root.lockContext.theme.subtext0
            font.pixelSize: 16
            text: weatherContent.place
          }
        }
      }

      // Hostname pill
      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Math.floor((root.width - 64 - parent.spacing) / 2)
        Layout.minimumWidth: 120
        Layout.preferredHeight: infoPillsRow.pillHeight
        opacity: 1
        radius: 10
        color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
        border.width: 1
        border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)

        RowLayout {
          anchors.fill: parent
          anchors.margins: root.isCompact ? 8 : 10
          spacing: 8

          Text {
            id: hostIcon
            Layout.alignment: Qt.AlignVCenter
            color: root.lockContext.theme.text
            font.pixelSize: 21
            text: "💻"
          }

          Text {
            id: hostText
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            elide: Text.ElideRight
            color: root.lockContext.theme.subtext0
            font.pixelSize: 21
            text: MainService?.hostname?.length > 0 ? MainService.hostname : "localhost"
          }
        }
      }
    }

    // Separator
    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredHeight: 1
      Layout.preferredWidth: Math.min(root.width - 64, 420)
      Layout.topMargin: 4
      visible: root.isPrimaryMonitor
      radius: 1
      color: Qt.rgba(124 / 255, 124 / 255, 148 / 255, 0.25)
    }

    // Password field
    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredHeight: 46
      Layout.preferredWidth: Math.min(root.width - 32, 440)
      visible: root.isPrimaryMonitor
      enabled: root.shouldAcceptInput
      radius: 12
      color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.45)
      border.width: 1
      border.color: root.lockContext.authState ? root.lockContext.theme.love : Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.18)

      // Focus indicator
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

      // Lock icon
      Text {
        id: lockIcon
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        color: root.lockContext.theme.overlay1
        font.pixelSize: 21
        opacity: 0.9
        text: "🔒"
      }

      // Password dots
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
            color: root.lockContext.authenticating ? root.lockContext.theme.mauve : root.lockContext.theme.overlay2

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

      // Status text
      Text {
        anchors.centerIn: parent
        opacity: root.lockContext.passwordBuffer.length ? 0 : 1
        font.pixelSize: 21
        color: {
          if (root.lockContext.authenticating)
            return root.accentColor;
          if (root.lockContext.authState)
            return root.lockContext.theme.love;
          return root.lockContext.theme.overlay1;
        }
        text: {
          if (root.lockContext.authenticating)
            return "Authenticating…";
          switch (root.lockContext.authState) {
          case "error":
            return "Error";
          case "max":
            return "Too many tries";
          case "fail":
            return "Incorrect password";
          default:
            return "Enter password";
          }
        }

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

      // Caps Lock indicator
      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        visible: KeyboardLayoutService.capsOn
        implicitHeight: capsText.height + 7
        implicitWidth: capsText.width + 12
        radius: 8
        color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
        border.width: 1
        border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)

        Text {
          id: capsText
          anchors.centerIn: parent
          color: root.lockContext.theme.love
          font.pixelSize: 14
          text: "Caps Lock"
        }
      }
    }

    // Help text and indicators
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      visible: root.isPrimaryMonitor
      opacity: 0.9
      spacing: 12

      Text {
        color: root.lockContext.theme.overlay1
        font.pixelSize: 16
        text: "Press Enter to unlock"
      }

      Rectangle {
        implicitHeight: 4
        implicitWidth: 4
        radius: 2
        color: root.lockContext.theme.overlay0
      }

      Text {
        color: root.lockContext.theme.overlay1
        font.pixelSize: 16
        text: "Esc clears input"
      }

      Rectangle {
        visible: KeyboardLayoutService.currentLayout.length > 0
        implicitHeight: layoutText.height + 7
        implicitWidth: layoutText.width + 12
        radius: 8
        color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
        border.width: 1
        border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)

        Text {
          id: layoutText
          anchors.centerIn: parent
          color: root.lockContext.theme.overlay1
          font.pixelSize: 14
          text: KeyboardLayoutService.currentLayout
        }
      }
    }
  }
}
