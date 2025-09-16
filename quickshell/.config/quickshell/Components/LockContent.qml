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
  id: lockPanel

  property color accent: lockContext && lockContext.theme ? lockContext.theme.mauve : "#cba6f7"
  property bool compact: width < 440
  required property var lockContext
  required property var lockSurface
  property int pillPadV: compact ? 6 : 8

  function _maybeRequestFocusOnce(reason) {
    if (!lockSurface || !lockSurface.hasScreen)
      return;
    const isPrimary = lockSurface.isMainMonitor;
    if (isPrimary) {
      lockPanel.forceActiveFocus();
      if (lockPanel.lockContext) {
        Logger.log("LockContent", "single-shot focus request (primary): " + reason);
      }
    }
  }

  function shake() {
    shakeAnim.restart();
  }

  // NEW: Always accept focus and request it when surface appears
  focus: true
  Keys.onPressed: event => {
    // Restrict explicit wake to main monitor surface to avoid duplication
    if (lockPanel.lockSurface && lockPanel.lockSurface.isMainMonitor) {
      IdleService.wake("key-press", lockPanel.lockSurface.screen ? lockPanel.lockSurface.screen.name : "no-screen");
    }
    if (!lockPanel.lockSurface || !lockPanel.lockSurface.hasScreen)
      return;
    if (lockPanel.lockContext.authenticating)
      return;

    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
      lockPanel.lockContext.submitOrStart();
      event.accepted = true;
    } else if (event.key === Qt.Key_Backspace) {
      lockPanel.lockContext.setPasswordBuffer(event.modifiers & Qt.ControlModifier ? "" : lockPanel.lockContext.passwordBuffer.slice(0, -1));
      event.accepted = true;
    } else if (event.key === Qt.Key_Escape) {
      lockPanel.lockContext.setPasswordBuffer("");
      event.accepted = true;
    } else if (event.text && event.text.length === 1) {
      const t = event.text;
      const c = t.charCodeAt(0);
      if (c >= 0x20 && c <= 0x7E) {
        lockPanel.lockContext.setPasswordBuffer(lockPanel.lockContext.passwordBuffer + t);
        event.accepted = true;
      }
    }
  }

  anchors.centerIn: parent
  height: column.implicitHeight + 32
  layer.enabled: lockSurface && lockSurface.hasScreen
  layer.mipmap: false
  opacity: lockSurface && lockSurface.hasScreen ? 1 : 0
  scale: lockSurface && lockSurface.hasScreen ? 1 : 0.98
  visible: lockSurface && lockSurface.hasScreen
  width: parent.width * 0.47

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
    id: lockPanelShake
    x: 0
  }

  Component.onCompleted: {
    _maybeRequestFocusOnce("component completed");
  }

  // NEW: Wake on mouse interactions even before focus is restored
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.AllButtons
    propagateComposedEvents: true
    onEntered: {
      if (lockPanel.lockSurface && lockPanel.lockSurface.isMainMonitor)
        IdleService.wake("pointer-enter", lockPanel.lockSurface.screen ? lockPanel.lockSurface.screen.name : "no-screen");
      lockPanel.forceActiveFocus();
    }
    onPressed: {
      if (lockPanel.lockSurface && lockPanel.lockSurface.isMainMonitor)
        IdleService.wake("pointer-press", lockPanel.lockSurface.screen ? lockPanel.lockSurface.screen.name : "no-screen");
      lockPanel.forceActiveFocus();
    }
    onWheel: {
      if (lockPanel.lockSurface && lockPanel.lockSurface.isMainMonitor)
        IdleService.wake("pointer-wheel", lockPanel.lockSurface.screen ? lockPanel.lockSurface.screen.name : "no-screen");
      lockPanel.forceActiveFocus();
    }
  }

  Connections {
    function onHasScreenChanged() {
      if (!lockPanel.lockSurface)
        return;
      if (lockPanel.lockSurface.hasScreen)
        lockPanel._maybeRequestFocusOnce("hasScreen changed -> true");
    }
    target: lockPanel.lockSurface
  }

  SequentialAnimation {
    id: shakeAnim
    running: false
    NumberAnimation {
      duration: 40
      easing.type: Easing.OutCubic
      from: 0
      property: "x"
      target: lockPanelShake
      to: 10
    }
    NumberAnimation {
      duration: 70
      from: 10
      property: "x"
      target: lockPanelShake
      to: -10
    }
    NumberAnimation {
      duration: 60
      from: -10
      property: "x"
      target: lockPanelShake
      to: 6
    }
    NumberAnimation {
      duration: 50
      from: 6
      property: "x"
      target: lockPanelShake
      to: -4
    }
    NumberAnimation {
      duration: 40
      from: -4
      property: "x"
      target: lockPanelShake
      to: 0
    }
  }

  Connections {
    function onAuthStateChanged() {
      if (lockPanel.lockContext.authState === "error" || lockPanel.lockContext.authState === "fail")
        lockPanel.shake();
    }
    target: lockPanel.lockContext
  }

  Rectangle {
    anchors.fill: parent
    border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.20)
    border.width: 1
    radius: 16
    gradient: Gradient {
      GradientStop {
        color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.70)
        position: 0.0
      }
      GradientStop {
        color: Qt.rgba(24 / 255, 24 / 255, 37 / 255, 0.66)
        position: 1.0
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.08)
    border.width: 1
    color: "transparent"
    radius: 16
  }

  ColumnLayout {
    id: column
    anchors.fill: parent
    anchors.margins: 16
    spacing: 14

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 10
      Text {
        Layout.alignment: Qt.AlignVCenter
        color: lockPanel.lockContext.theme.text
        font.bold: true
        font.pixelSize: 74
        horizontalAlignment: Text.AlignHCenter
        text: TimeService.format("time", TimeService.use24Hour ? "HH:mm" : "hh:mm")
      }
      Text {
        Layout.alignment: Qt.AlignVCenter
        color: lockPanel.lockContext.theme.subtext1
        font.bold: true
        font.pixelSize: 30
        horizontalAlignment: Text.AlignHCenter
        text: TimeService.format("time", "AP")
        visible: !TimeService.use24Hour && text !== ""
      }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: lockPanel.width - 64
      color: lockPanel.lockContext.theme.subtext0
      font.pixelSize: 21
      horizontalAlignment: Text.AlignHCenter
      text: TimeService.format("date", "dddd, d MMMM yyyy")
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: lockPanel.width - 64
      Layout.topMargin: 2
      color: lockPanel.lockContext.theme.subtext1
      elide: Text.ElideRight
      font.bold: true
      font.pixelSize: 24
      horizontalAlignment: Text.AlignHCenter
      text: MainService.fullName ? MainService.fullName : ""
      visible: lockPanel.lockSurface.hasScreen && text.length > 0
    }

    RowLayout {
      id: infoPillsRow

      property int hostLineHeight: Math.max(hostIcon.font.pixelSize, hostText.font.pixelSize)
      property int pillHeight: Math.max(hostLineHeight, weatherPill.contentHeight) + lockPanel.pillPadV * 2

      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: lockPanel.width - 64
      spacing: 10
      visible: lockPanel.lockSurface.hasScreen

      Rectangle {
        id: weatherPill

        property int contentHeight: weatherColumn.contentHeight

        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Math.floor((lockPanel.width - 64 - infoPillsRow.spacing) / 2)
        Layout.minimumWidth: 120
        Layout.preferredHeight: infoPillsRow.pillHeight
        border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
        border.width: 1
        color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
        opacity: visible ? 1 : 0
        radius: 10
        visible: lockPanel.lockSurface.hasScreen && WeatherService

        Behavior on opacity {
          NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
          }
        }

        ColumnLayout {
          id: weatherColumn

          readonly property int contentHeight: fitsInline ? Math.max(weatherIcon.font.pixelSize, weatherTemp.font.pixelSize, weatherPlaceInline.font.pixelSize) : Math.max(weatherIcon.font.pixelSize, weatherTemp.font.pixelSize) + weatherColumn.spacing + (weatherPlace.visible ? weatherPlace.font.pixelSize : 0)
          readonly property bool fitsInline: (weatherIcon.implicitWidth + weatherTopRow.spacing + weatherTemp.implicitWidth + (weatherColumn.place.length > 0 ? weatherTopRow.spacing + weatherPlaceInline.implicitWidth : 0) + (weatherColumn.stale ? weatherTopRow.spacing + weatherStaleBadge.implicitWidth : 0)) <= weatherColumn.width
          property string icon: WeatherService ? WeatherService.getWeatherIconFromCode() : ""
          property string place: WeatherService && WeatherService.locationName ? WeatherService.locationName : ""
          property bool stale: WeatherService ? WeatherService.isStale : false
          property string temp: WeatherService ? WeatherService.currentTemp : ""

          anchors.left: parent.left
          anchors.margins: lockPanel.compact ? 8 : 10
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2

          RowLayout {
            id: weatherTopRow

            Layout.fillWidth: true
            spacing: 8

            Text {
              id: weatherIcon

              Layout.alignment: Qt.AlignVCenter
              color: lockPanel.lockContext.theme.text
              font.pixelSize: 27
              text: weatherColumn.icon
            }

            Text {
              id: weatherTemp

              Layout.alignment: Qt.AlignVCenter
              color: lockPanel.lockContext.theme.text
              font.bold: true
              font.pixelSize: 21
              text: WeatherService ? Math.max(0, weatherColumn.temp.indexOf("°")) >= 0 ? weatherColumn.temp.split(" ")[0] : weatherColumn.temp : ""
            }

            Text {
              id: weatherPlaceInline

              Layout.alignment: Qt.AlignVCenter
              Layout.fillWidth: true
              color: lockPanel.lockContext.theme.subtext0
              elide: Text.ElideRight
              font.pixelSize: 16
              text: weatherColumn.place
              visible: !lockPanel.compact && text.length > 0 && weatherColumn.fitsInline
            }

            Rectangle {
              id: weatherStaleBadge

              Layout.alignment: Qt.AlignVCenter
              border.color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.36)
              border.width: 1
              color: Qt.rgba(250 / 255, 179 / 255, 135 / 255, 0.18)
              implicitHeight: 18
              implicitWidth: weatherStaleText.implicitWidth + 10
              radius: 6
              visible: weatherColumn.stale

              Text {
                id: weatherStaleText

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
            color: lockPanel.lockContext.theme.subtext0
            elide: Text.ElideRight
            font.pixelSize: 16
            text: weatherColumn.place
            visible: !lockPanel.compact && text.length > 0 && !weatherColumn.fitsInline
          }
        }
      }

      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Math.floor((lockPanel.width - 64 - infoPillsRow.spacing) / 2)
        Layout.minimumWidth: 120
        Layout.preferredHeight: infoPillsRow.pillHeight
        border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
        border.width: 1
        color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
        opacity: visible ? 1 : 0
        radius: 10
        visible: lockPanel.lockSurface.hasScreen

        Behavior on opacity {
          NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
          }
        }

        RowLayout {
          id: hostRow

          anchors.left: parent.left
          anchors.margins: lockPanel.compact ? 8 : 10
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8

          Text {
            id: hostIcon

            Layout.alignment: Qt.AlignVCenter
            color: lockPanel.lockContext.theme.text
            font.pixelSize: 21
            text: "💻"
          }

          Text {
            id: hostText

            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            color: lockPanel.lockContext.theme.subtext0
            elide: Text.ElideRight
            font.pixelSize: 21
            text: (MainService && typeof MainService.hostname === "string" && MainService.hostname.length > 0) ? MainService.hostname : "localhost"
          }
        }
      }
    }

    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredHeight: 1
      Layout.preferredWidth: Math.min(lockPanel.width - 64, 420)
      Layout.topMargin: 4
      color: Qt.rgba(124 / 255, 124 / 255, 148 / 255, 0.25)
      radius: 1
      visible: lockPanel.lockSurface.isMainMonitor
    }

    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredHeight: 46
      Layout.preferredWidth: Math.min(lockPanel.width - 32, 440)
      border.color: lockPanel.lockContext.authState ? lockPanel.lockContext.theme.love : Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.18)
      border.width: 1
      color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.45)
      enabled: lockPanel.lockSurface.hasScreen && lockPanel.lockSurface.isMainMonitor
      radius: 12
      visible: lockPanel.lockSurface.isMainMonitor

      Text {
        id: lockIcon

        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        color: lockPanel.lockContext.theme.overlay1
        font.pixelSize: 21
        opacity: 0.9
        text: "🔒"
      }

      Item {
        id: passContent

        anchors.fill: parent
        anchors.leftMargin: lockIcon.anchors.leftMargin + lockIcon.width + 8
        anchors.rightMargin: anchors.leftMargin
      }

      Rectangle {
        id: capsIndicator

        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
        border.width: 1
        color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
        implicitHeight: capsText.height + 7
        implicitWidth: capsText.width + 12
        radius: 8
        visible: KeyboardLayoutService.capsOn

        Text {
          id: capsText

          anchors.centerIn: parent
          color: lockPanel.lockContext.theme.love
          font.pixelSize: 14
          text: "Caps Lock"
        }
      }

      Rectangle {
        anchors.fill: parent
        border.color: lockPanel.accent
        border.width: 2
        color: "transparent"
        opacity: lockPanel.activeFocus ? 0.55 : 0.0
        radius: parent.radius

        Behavior on opacity {
          NumberAnimation {
            duration: 160
          }
        }
      }

      RowLayout {
        anchors.centerIn: passContent
        spacing: 7

        Repeater {
          model: lockPanel.lockContext.passwordBuffer.length

          delegate: Rectangle {
            color: lockPanel.lockContext.authenticating ? lockPanel.lockContext.theme.mauve : lockPanel.lockContext.theme.overlay2
            implicitHeight: 10
            implicitWidth: 10
            radius: 5
            scale: 0.8

            SequentialAnimation on opacity {
              loops: 1
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
        anchors.centerIn: passContent
        color: lockPanel.lockContext.authenticating ? lockPanel.accent : lockPanel.lockContext.authState ? lockPanel.lockContext.theme.love : lockPanel.lockContext.theme.overlay1
        font.pixelSize: 21
        opacity: lockPanel.lockContext.passwordBuffer.length ? 0 : 1
        text: lockPanel.lockContext.authenticating ? "Authenticating…" : lockPanel.lockContext.authState === "error" ? "Error" : lockPanel.lockContext.authState === "max" ? "Too many tries" : lockPanel.lockContext.authState === "fail" ? "Incorrect password" : lockPanel.lockContext.passwordBuffer.length ? "" : "Enter password"

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
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      opacity: 0.9
      spacing: 12
      visible: lockPanel.lockSurface.isMainMonitor

      Text {
        color: lockPanel.lockContext.theme.overlay1
        font.pixelSize: 16
        text: "Press Enter to unlock"
      }

      Rectangle {
        color: lockPanel.lockContext.theme.overlay0
        implicitHeight: 4
        implicitWidth: 4
        radius: 2
      }

      Text {
        color: lockPanel.lockContext.theme.overlay1
        font.pixelSize: 16
        text: "Esc clears input"
      }

      Rectangle {
        id: layoutIndicator

        border.color: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.14)
        border.width: 1
        color: Qt.rgba(49 / 255, 50 / 255, 68 / 255, 0.40)
        implicitHeight: layoutText.height + 7
        implicitWidth: layoutText.width + 12
        radius: 8
        visible: (KeyboardLayoutService.currentLayout.length > 0)

        Text {
          id: layoutText

          anchors.horizontalCenter: layoutIndicator.horizontalCenter
          anchors.verticalCenter: layoutIndicator.verticalCenter
          color: lockPanel.lockContext.theme.overlay1
          font.pixelSize: 14
          text: KeyboardLayoutService.currentLayout
        }
      }
    }
  }
}
