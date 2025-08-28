import QtQuick
import QtQuick.Controls
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Services.SystemInfo

// ToastManager overlay hooked to OSDService
PanelWindow {
  id: root

  property var modelData

  // Local helpers and animations (scoped at root to avoid binding loops)
  function _baseDurationFor(level, hasDetails) {
    if (level === OSDService.levelError && hasDetails)
      return OSDService.durationErrorWithDetails;

    if (level === OSDService.levelError)
      return OSDService.durationError;

    if (level === OSDService.levelWarn)
      return OSDService.durationWarn;

    return OSDService.durationInfo;
  }

  WlrLayershell.exclusiveZone: -1
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Overlay
  color: "transparent"

  // screen: MainService.mainMon
  visible: OSDService.toastVisible

  mask: Region {
    item: toast
  }

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }

  Rectangle {
    id: toast

    // Cap content width relative to screen; avoids binding loops by not depending on toast.width
    property int maxContentWidth: Math.round(parent.width * 0.15)
    property int padding: 12
    property int spacing: 6
    // Progress from 1 -> 0 for the progress bar
    property real toastProgress: 0

    anchors.bottom: parent.bottom
    anchors.bottomMargin: 24
    anchors.horizontalCenter: parent.horizontalCenter
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
    clip: true
    color: "transparent"
    height: contentCol.implicitHeight + (padding * 2)
    layer.enabled: true
    opacity: OSDService.toastVisible ? 1 : 0
    radius: 12
    scale: OSDService.toastVisible ? 1 : 0.98
    visible: OSDService.toastVisible

    // Bottom-up width: sized to content, clamped by maxContentWidth
    width: Math.min(maxContentWidth + (padding * 2), contentCol.implicitWidth + (padding * 2))
    y: OSDService.toastVisible ? 0 : 16

    gradient: Gradient {
      GradientStop {
        color: Qt.rgba(0.1, 0.08, 0.12, 0.92)
        position: 0
      }

      GradientStop {
        color: Qt.rgba(0.1, 0.08, 0.12, 0.82)
        position: 1
      }
    }
    layer.effect: MultiEffect {
      shadowBlur: 30
      shadowColor: Qt.rgba(0, 0, 0, 0.45)
      shadowEnabled: true
      shadowVerticalOffset: 6
    }
    Behavior on opacity {
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutQuad
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: 220
        easing.type: Easing.OutQuad
      }
    }
    Behavior on y {
      NumberAnimation {
        duration: 220
        easing.type: Easing.OutQuad
      }
    }

    // Content
    Column {
      id: contentCol

      anchors.fill: parent
      anchors.margins: toast.padding
      spacing: toast.spacing

      // Header row: level badge + message + optional repeat count
      Row {
        anchors.horizontalCenter: undefined
        spacing: 8

        // Level badge
        Rectangle {
          id: levelBadge

          color: {
            switch (OSDService.currentLevel) {
            case OSDService.levelError:
              return Qt.rgba(0.9, 0.28, 0.32, 1);
            case OSDService.levelWarn:
              return Qt.rgba(0.98, 0.73, 0.2, 1);
            default:
              return Qt.rgba(0.4, 0.7, 1, 1);
            }
          }
          height: levelText.implicitHeight + 4
          radius: 4
          width: levelText.implicitWidth + 8

          Text {
            id: levelText

            anchors.centerIn: parent
            color: "white"
            font.bold: true
            font.letterSpacing: 0.5
            font.pixelSize: 12
            text: (OSDService.currentLevel === OSDService.levelError ? "⛔ ERROR" : OSDService.currentLevel === OSDService.levelWarn ? "⚠️ WARN" : "ℹ️ INFO")
          }
        }

        // Main message
        Text {
          color: "white"
          elide: Text.ElideRight
          font.pixelSize: 18
          font.weight: Font.Medium
          text: OSDService.currentMessage
          // Constrain to available space after badge and repeat chip
          width: Math.min(implicitWidth, Math.max(0, toast.maxContentWidth - (levelBadge.width + (repChip.visible ? repChip.width : 0) + 16)))
          wrapMode: Text.Wrap
        }

        // Repeat count chip
        Rectangle {
          id: repChip

          border.width: 0
          color: Qt.rgba(1, 1, 1, 0.12)
          height: repText.implicitHeight + 4
          radius: 8
          visible: OSDService.currentRepeatCount > 0
          width: repText.implicitWidth + 10

          Text {
            id: repText

            anchors.centerIn: parent
            color: "white"
            font.bold: true
            font.pixelSize: 12
            text: "×" + (OSDService.currentRepeatCount + 1)
          }
        }
      }

      // Details (optional)
      Text {
        color: "white"
        font.pixelSize: 14
        font.weight: Font.Normal
        opacity: 0.9
        text: OSDService.currentDetails
        visible: OSDService.hasDetails
        width: Math.min(implicitWidth, toast.maxContentWidth)
        wrapMode: Text.Wrap
      }

      // Status line (queue, DND)
      Row {
        opacity: 0.9
        spacing: 12

        Text {
          color: "white"
          font.pixelSize: 12
          text: "📥 Queue: " + OSDService.toastQueue.length
        }

        Text {
          color: "white"
          font.pixelSize: 12
          text: OSDService.doNotDisturb ? "🔕 DND: on" : "🔔 DND: off"
        }
      }

      // Wallpaper error status (optional external status)
      Text {
        color: "white"
        font.pixelSize: 12
        opacity: 0.95
        text: OSDService.wallpaperErrorStatus
        visible: OSDService.wallpaperErrorStatus.length > 0
        width: Math.min(implicitWidth, toast.maxContentWidth)
        wrapMode: Text.Wrap
      }
    }

    // Progress bar: rounded track + clipped fill, inset to avoid corner overlap
    Rectangle {
      id: progressTrack

      anchors.horizontalCenter: parent.horizontalCenter
      clip: true
      color: Qt.rgba(1, 1, 1, 0.1)
      height: 1
      radius: 2
      width: Math.max(0, Math.min(contentCol.width - 4, toast.maxContentWidth - 4))

      Rectangle {
        id: progressFill

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(0.8, 0.7, 1, 0.9) // mauve accent
        height: parent.height
        radius: parent.radius
        width: parent.width * toast.toastProgress
      }
    }
  }

  Connections {
    function onResetToastState() {
      // Optionally reset animation or position here
      toast.opacity = 1;
      // Restart progress animation
      toast.toastProgress = 1;
      progressAnim.stop();
      progressAnim.duration = root._baseDurationFor(OSDService.currentLevel, OSDService.hasDetails);
      progressAnim.start();
    }

    target: OSDService
  }

  // Animate toast progress from 1 -> 0 each time a toast starts/reset
  NumberAnimation {
    id: progressAnim

    duration: 3000 // will be overridden on start
    easing.type: Easing.Linear
    from: 1
    property: "toastProgress"
    running: false
    target: toast
    to: 0
  }
}
