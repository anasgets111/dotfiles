pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Config
import qs.Components

Item {
  id: root

  // ── Properties ────────────────────────────────────────────────
  property bool active: false
  readonly property bool displayPowerOffEnabled: IdleService.displayPowerOffEnabled
  readonly property real displayPowerOffTimeout: IdleService.displayPowerOffTimeoutMin
  readonly property int enabledActionCount: IdleService.enabledActionCount
  readonly property var flowSteps: IdleService.flowSteps
  readonly property bool idleEnabled: IdleService.idleEnabled
  readonly property bool inputDisplayBackendReady: InputDisplayService.backendAvailable
  readonly property string inputDisplayStatusText: InputDisplayService.backendCheckComplete ? qsTr("Install showmethekey-cli to enable the keyboard and mouse overlay.") : qsTr("Checking for showmethekey-cli...")
  readonly property bool lockAfterDisplayPowerOff: IdleService.lockAfterDisplayPowerOff
  readonly property bool lockEnabled: IdleService.lockEnabled
  readonly property real lockTimeout: IdleService.lockTimeoutMin
  readonly property bool suspendEnabled: IdleService.suspendEnabled
  readonly property real suspendTimeout: IdleService.suspendTimeoutMin
  property int windowHeight: 820
  property int windowWidth: 1000

  signal dismissed

  function close(): void {
    if (!active)
      return;
    active = false;
    dismissed();
  }

  function formatDuration(value: real): string {
    const v = Math.max(0, Number(value) || 0);
    if (v <= 0)
      return qsTr("Never");
    const mins = Math.floor(v);
    const secs = Math.round((v - mins) * 60);
    if (mins > 0 && secs > 0)
      return `${mins}m ${secs}s`;
    return mins > 0 ? `${mins}m` : `${secs}s`;
  }

  function open(): void {
    active = true;
  }

  // ── Root ──────────────────────────────────────────────────────
  anchors.fill: parent
  focus: active
  visible: active

  onActiveChanged: if (active) {
    InputDisplayService.refreshBackendAvailability();
  }

  // ── Scrim ─────────────────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    color: Theme.bgOverlay
    opacity: 0.88
  }

  MouseArea {
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    anchors.fill: parent

    onPressed: mouse => {
      if (popupRect.contains(popupRect.mapFromItem(root, mouse.x, mouse.y))) {
        mouse.accepted = false;
        return;
      }
      root.close();
    }
  }

  // ── Popup Card ────────────────────────────────────────────────
  Rectangle {
    id: popupRect

    anchors.centerIn: parent
    border.color: Theme.withOpacity(Theme.activeColor, 0.18)
    border.width: 1
    clip: true
    color: Theme.bgElevatedAlt
    focus: true
    height: Math.min(root.windowHeight, parent.height - Theme.spacingXl * 2)
    layer.enabled: true
    radius: Theme.radiusXl
    scale: root.active ? 1.0 : 0.96
    width: Math.min(root.windowWidth, parent.width - Theme.spacingXl * 2)

    layer.effect: MultiEffect {
      shadowBlur: 0.9
      shadowColor: Theme.withOpacity(Theme.shadowColorStrong, 0.72)
      shadowEnabled: true
      shadowVerticalOffset: 14
    }
    Behavior on scale {
      NumberAnimation {
        duration: Theme.animationVerySlow
        easing.type: Easing.OutCubic
      }
    }

    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape) {
        root.close();
        event.accepted = true;
      }
    }

    // Inner border shimmer
    Rectangle {
      anchors.fill: parent
      border.color: Theme.withOpacity(Theme.textActiveColor, 0.05)
      border.width: 1
      color: "transparent"
      radius: parent.radius
    }

    // Top accent glow
    Rectangle {
      height: parent.height * 0.4
      radius: parent.radius

      gradient: Gradient {
        GradientStop {
          color: Theme.withOpacity(Theme.activeColor, 0.09)
          position: 0.0
        }

        GradientStop {
          color: "transparent"
          position: 1.0
        }
      }

      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
      }
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      // ── Header ───────────────────────────────────────────────
      ColumnLayout {
        Layout.bottomMargin: Theme.spacingLg
        Layout.fillWidth: true
        Layout.margins: Theme.spacingXl
        spacing: Theme.spacingLg

        RowLayout {
          Layout.fillWidth: true
          spacing: Theme.spacingLg

          Rectangle {
            border.color: Theme.withOpacity(Theme.activeColor, 0.55)
            border.width: 1
            color: Theme.withOpacity(Theme.activeColor, 0.18)
            implicitHeight: Theme.iconSizeXl * 1.8
            implicitWidth: Theme.iconSizeXl * 1.8
            radius: Theme.radiusLg

            OText {
              anchors.centerIn: parent
              color: Theme.activeColor
              font.pixelSize: Theme.fontXl * 1.35
              text: "󰾪"
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            OText {
              bold: true
              font.pixelSize: Theme.fontXxl
              text: qsTr("Idle Settings")
            }

            OText {
              color: Theme.textInactiveColor
              font.pixelSize: Theme.fontMd
              text: root.idleEnabled ? qsTr("Session automation is active — %1 actions armed.").arg(root.enabledActionCount) : qsTr("Session automation is currently paused.")
            }
          }

          Item {
            Layout.fillWidth: true
          }

          IconButton {
            Layout.alignment: Qt.AlignTop
            Layout.preferredHeight: Theme.controlHeightLg
            Layout.preferredWidth: Theme.controlHeightLg
            colorBg: Theme.withOpacity(Theme.bgColor, 0.6)
            icon: "󰅖"
            tooltipText: qsTr("Close")

            onClicked: root.close()
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Theme.spacingSm

          Repeater {
            model: root.flowSteps

            delegate: StatusPill {
              readonly property bool isDisplayPowerOff: modelData === "displayPowerOff"
              readonly property bool isLock: modelData === "lock"
              required property var modelData
              readonly property bool pillActive: root.idleEnabled && (isLock ? root.lockEnabled : isDisplayPowerOff ? root.displayPowerOffEnabled : root.suspendEnabled)

              Layout.fillWidth: true
              active: pillActive
              icon: isLock ? "󰌾" : isDisplayPowerOff ? "󰍹" : "󰒚"
              text: isLock ? (pillActive ? qsTr("Lock • %1").arg(root.formatDuration(root.lockTimeout)) : qsTr("Lock • Off")) : isDisplayPowerOff ? (pillActive ? qsTr("Display • %1").arg(root.formatDuration(root.displayPowerOffTimeout)) : qsTr("Display • Off")) : (pillActive ? qsTr("Suspend • %1").arg(root.formatDuration(root.suspendTimeout)) : qsTr("Suspend • Off"))
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        color: Theme.borderSubtle
        implicitHeight: 1
        opacity: 0.55
      }

      // ── Scroll Body ───────────────────────────────────────────
      ScrollView {
        id: settingsScroll

        Layout.fillHeight: true
        Layout.fillWidth: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        contentWidth: availableWidth

        ColumnLayout {
          spacing: Theme.spacingLg
          width: settingsScroll.availableWidth - Theme.spacingXl * 2
          x: Theme.spacingXl

          Item {
            implicitHeight: Theme.spacingMd
          }

          // ── General + Actions hero card ───────────────────────
          Rectangle {
            Layout.fillWidth: true
            border.color: Theme.withOpacity(Theme.borderLight, 0.6)
            border.width: 1
            clip: true
            color: Theme.bgElevated
            implicitHeight: heroBody.implicitHeight + Theme.spacingLg * 2
            radius: Theme.radiusLg

            Rectangle {
              height: parent.height * 0.45
              radius: parent.radius

              gradient: Gradient {
                GradientStop {
                  color: Theme.withOpacity(Theme.activeColor, 0.05)
                  position: 0.0
                }

                GradientStop {
                  color: "transparent"
                  position: 1.0
                }
              }

              anchors {
                left: parent.left
                right: parent.right
                top: parent.top
              }
            }

            ColumnLayout {
              id: heroBody

              spacing: Theme.spacingMd

              anchors {
                fill: parent
                margins: Theme.spacingLg
              }

              // Hero row
              RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMd

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  OText {
                    bold: true
                    font.pixelSize: Theme.fontXxl * 1.4
                    text: qsTr("Idle Service")
                  }

                  OText {
                    color: Theme.textInactiveColor
                    font.pixelSize: Theme.fontMd
                    text: root.idleEnabled ? qsTr("%1 actions armed").arg(root.enabledActionCount) : qsTr("All automation paused")
                  }
                }

                Item {
                  Layout.fillWidth: true
                }

                OToggle {
                  checked: root.idleEnabled
                  size: "lg"

                  onToggled: c => IdleService.setIdleEnabled(c)
                }
              }

              Rectangle {
                Layout.fillWidth: true
                color: Theme.borderSubtle
                implicitHeight: 1
                opacity: 0.4
              }

              // Nested action rows
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                SettingRow {
                  checked: root.lockEnabled
                  description: qsTr("Secure your session after inactivity.")
                  disabled: !root.idleEnabled
                  hasSlider: true
                  icon: "󰌾"
                  label: qsTr("Lock Screen")
                  sliderMax: 30
                  sliderValue: root.lockTimeout

                  onSliderChanged: v => IdleService.setLockTimeoutMin(v)
                  onToggled: c => IdleService.setLockEnabled(c)
                }

                SettingRow {
                  checked: root.displayPowerOffEnabled
                  description: qsTr("Power down monitors when no activity is detected.")
                  disabled: !root.idleEnabled
                  hasSlider: true
                  icon: "󰍹"
                  label: qsTr("Turn Off Display")
                  sliderMax: 10
                  sliderValue: root.displayPowerOffTimeout

                  onSliderChanged: v => IdleService.setDisplayPowerOffTimeoutMin(v)
                  onToggled: c => IdleService.setDisplayPowerOffEnabled(c)
                }

                SettingRow {
                  checked: root.suspendEnabled
                  description: qsTr("Save power by suspending the device.")
                  disabled: !root.idleEnabled
                  hasSlider: true
                  icon: "󰒚"
                  label: qsTr("Suspend System")
                  sliderMax: 60
                  sliderValue: root.suspendTimeout

                  onSliderChanged: v => IdleService.setSuspendTimeoutMin(v)
                  onToggled: c => IdleService.setSuspendEnabled(c)
                }

                SettingRow {
                  checked: root.lockAfterDisplayPowerOff
                  description: qsTr("Swap the order: display off first, then lock.")
                  disabled: !root.idleEnabled || !root.lockEnabled || !root.displayPowerOffEnabled
                  icon: "󰁯"
                  label: qsTr("Lock After Display Off")
                  showSeparator: false

                  onToggled: c => IdleService.setLockAfterDisplayPowerOff(c)
                }
              }
            }
          }

          // ── Advanced card ─────────────────────────────────────
          Rectangle {
            Layout.fillWidth: true
            border.color: Theme.withOpacity(Theme.borderLight, 0.6)
            border.width: 1
            clip: true
            color: Theme.bgElevated
            implicitHeight: advancedBody.implicitHeight + Theme.spacingLg * 2
            radius: Theme.radiusLg

            Rectangle {
              height: parent.height * 0.45
              radius: parent.radius

              gradient: Gradient {
                GradientStop {
                  color: Theme.withOpacity(Theme.activeColor, 0.05)
                  position: 0.0
                }

                GradientStop {
                  color: "transparent"
                  position: 1.0
                }
              }

              anchors {
                left: parent.left
                right: parent.right
                top: parent.top
              }
            }

            ColumnLayout {
              id: advancedBody

              spacing: 0

              anchors {
                fill: parent
                margins: Theme.spacingLg
              }

              SettingRow {
                checked: IdleService.respectInhibitorsEnabled
                description: qsTr("Honor compositor and app inhibit requests.")
                disabled: !root.idleEnabled
                icon: "󰈑"
                label: qsTr("Respect Inhibitors")

                onToggled: c => IdleService.setRespectInhibitors(c)
              }

              SettingRow {
                checked: IdleService.videoAutoInhibitEnabled
                description: qsTr("Auto-inhibit while media is actively playing.")
                disabled: !root.idleEnabled
                icon: "󰀈"
                label: qsTr("Video Inhibit")
                showSeparator: false

                onToggled: c => IdleService.setVideoAutoInhibit(c)
              }
            }
          }

          // ── Input display card ───────────────────────────────
          Rectangle {
            Layout.fillWidth: true
            border.color: Theme.withOpacity(Theme.borderLight, 0.6)
            border.width: 1
            clip: true
            color: Theme.bgElevated
            implicitHeight: inputDisplayBody.implicitHeight + Theme.spacingLg * 2
            radius: Theme.radiusLg

            Rectangle {
              height: parent.height * 0.45
              radius: parent.radius

              gradient: Gradient {
                GradientStop {
                  color: Theme.withOpacity(Theme.activeColor, 0.05)
                  position: 0.0
                }

                GradientStop {
                  color: "transparent"
                  position: 1.0
                }
              }

              anchors {
                left: parent.left
                right: parent.right
                top: parent.top
              }
            }

            ColumnLayout {
              id: inputDisplayBody

              spacing: 0

              anchors {
                fill: parent
                margins: Theme.spacingLg
              }

              StatusPill {
                Layout.fillWidth: true
                active: false
                icon: InputDisplayService.backendCheckComplete ? "󰅚" : "󰔟"
                text: root.inputDisplayStatusText
                visible: !root.inputDisplayBackendReady
              }

              SettingRow {
                checked: InputDisplayService.enabled
                description: qsTr("Show the keyboard and mouse overlay.")
                icon: "󰖳"
                label: qsTr("Input Display")
                visible: root.inputDisplayBackendReady

                onToggled: c => InputDisplayService.setEnabled(c)
              }

              SettingRow {
                checked: InputDisplayService.showPrintableKeys
                description: qsTr("Letters, digits, punctuation, and space.")
                disabled: !InputDisplayService.enabled
                icon: "󰌌"
                label: qsTr("Show Printable Keys")
                showSeparator: false
                visible: root.inputDisplayBackendReady

                onToggled: c => InputDisplayService.setShowPrintableKeys(c)
              }
            }
          }

          // ── Tip banner ────────────────────────────────────────
          Rectangle {
            Layout.fillWidth: true
            border.color: Theme.withOpacity(Theme.activeColor, 0.2)
            border.width: 1
            color: Theme.withOpacity(Theme.bgElevated, 0.75)
            implicitHeight: tipRow.implicitHeight + Theme.spacingMd * 2
            radius: Theme.radiusMd

            RowLayout {
              id: tipRow

              spacing: Theme.spacingSm

              anchors {
                fill: parent
                leftMargin: Theme.spacingLg
                rightMargin: Theme.spacingLg
              }

              OText {
                color: Theme.activeColor
                font.pixelSize: Theme.fontLg
                text: "󰋼"
              }

              OText {
                Layout.fillWidth: true
                color: Theme.textInactiveColor
                font.pixelSize: Theme.fontMd
                text: root.lockAfterDisplayPowerOff ? qsTr("Tip: current flow is Display Off → Lock → Suspend.") : qsTr("Tip: current flow is Lock → Display Off → Suspend.")
                wrapMode: Text.Wrap
              }
            }
          }

          Item {
            implicitHeight: Theme.spacingMd
          }
        }
      }
    }
  }

  // ── SettingRow ────────────────────────────────────────────────
  component SettingRow: ColumnLayout {
    id: rowRoot

    property bool checked: false
    property string description: ""
    property bool disabled: false
    property bool hasSlider: false
    property string icon: ""
    property string label: ""
    property bool showSeparator: true
    property real sliderMax: 60
    property real sliderValue: 0

    signal sliderChanged(real value)
    signal toggled(bool checked)

    Layout.fillWidth: true
    enabled: !disabled
    opacity: disabled ? Theme.opacityDisabled : 1.0
    spacing: 0

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }

    // Main row
    Rectangle {
      Layout.fillWidth: true
      clip: true
      color: rowHover.containsMouse && !rowRoot.disabled ? Theme.withOpacity(Theme.activeColor, 0.04) : "transparent"
      implicitHeight: rowBody.implicitHeight + Theme.spacingMd * 2

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }

      MouseArea {
        id: rowHover

        acceptedButtons: Qt.NoButton
        anchors.fill: parent
        hoverEnabled: true
      }

      RowLayout {
        id: rowBody

        spacing: Theme.spacingMd

        anchors {
          bottomMargin: Theme.spacingMd
          fill: parent
          leftMargin: Theme.spacingLg
          rightMargin: Theme.spacingMd
          topMargin: Theme.spacingMd
        }

        // Icon badge
        Rectangle {
          border.color: rowRoot.checked ? Theme.withOpacity(Theme.activeColor, 0.55) : Theme.borderSubtle
          border.width: 1
          color: rowRoot.checked ? Theme.withOpacity(Theme.activeColor, 0.18) : Theme.withOpacity(Theme.bgColor, 0.4)
          implicitHeight: Theme.controlHeightMd
          implicitWidth: Theme.controlHeightMd
          radius: Theme.radiusSm

          Behavior on border.color {
            ColorAnimation {
              duration: Theme.animationDuration
            }
          }
          Behavior on color {
            ColorAnimation {
              duration: Theme.animationDuration
            }
          }

          OText {
            anchors.centerIn: parent
            color: rowRoot.checked ? Theme.activeColor : Theme.textInactiveColor
            font.pixelSize: Theme.fontMd
            text: rowRoot.icon

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }
        }

        // Label + description
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          OText {
            bold: rowRoot.checked
            color: rowRoot.checked ? Theme.textActiveColor : Theme.textInactiveColor
            font.pixelSize: Theme.fontLg
            text: rowRoot.label

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }

          OText {
            Layout.fillWidth: true
            color: Theme.textInactiveColor
            font.pixelSize: Theme.fontSm
            opacity: 0.85
            text: rowRoot.hasSlider && rowRoot.checked ? qsTr("Timeout: %1").arg(root.formatDuration(rowRoot.sliderValue)) : rowRoot.description
            visible: text.length > 0
            wrapMode: Text.Wrap
          }
        }

        OToggle {
          checked: rowRoot.checked
          disabled: rowRoot.disabled
          size: "lg"

          onToggled: c => rowRoot.toggled(c)
        }
      }
    }

    // Slider section
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: visible ? sliderInner.implicitHeight + Theme.spacingSm * 2 : 0
      clip: true
      visible: rowRoot.hasSlider && rowRoot.checked

      Behavior on Layout.preferredHeight {
        NumberAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.OutCubic
        }
      }

      ColumnLayout {
        id: sliderInner

        spacing: Theme.spacingXs

        anchors {
          bottomMargin: Theme.spacingSm
          fill: parent
          leftMargin: Theme.spacingLg + Theme.controlHeightMd + Theme.spacingMd
          rightMargin: Theme.spacingMd
          topMargin: Theme.spacingSm
        }

        RowLayout {
          Layout.fillWidth: true

          OText {
            color: Theme.textInactiveColor
            font.pixelSize: Theme.fontSm
            text: qsTr("Timeout")
          }

          Item {
            Layout.fillWidth: true
          }

          OText {
            bold: true
            color: Theme.activeColor
            font.pixelSize: Theme.fontSm
            text: root.formatDuration(rowRoot.sliderValue)
          }
        }

        Slider {
          Layout.fillWidth: true
          Layout.preferredHeight: 24
          fillColor: Theme.activeColor
          interactive: !rowRoot.disabled
          radius: 12
          steps: Math.max(1, Math.round(rowRoot.sliderMax * 2))
          value: rowRoot.sliderMax > 0 ? rowRoot.sliderValue / rowRoot.sliderMax : 0

          onCommitted: v => {
            if (rowRoot.sliderMax <= 0) {
              rowRoot.sliderChanged(0);
              return;
            }
            rowRoot.sliderChanged(Math.round(v * rowRoot.sliderMax * 2) / 2);
          }
        }

        RowLayout {
          Layout.fillWidth: true

          OText {
            color: Theme.textInactiveColor
            font.pixelSize: Theme.fontXs
            opacity: 0.65
            text: qsTr("Never")
          }

          Item {
            Layout.fillWidth: true
          }

          OText {
            color: Theme.textInactiveColor
            font.pixelSize: Theme.fontXs
            opacity: 0.65
            text: root.formatDuration(rowRoot.sliderMax)
          }
        }
      }
    }

    // Separator
    Rectangle {
      Layout.fillWidth: true
      Layout.leftMargin: Theme.spacingLg + Theme.controlHeightMd + Theme.spacingMd
      color: Theme.borderSubtle
      implicitHeight: 1
      opacity: 0.28
      visible: rowRoot.showSeparator
    }
  }

  // ── StatusPill ────────────────────────────────────────────────
  component StatusPill: Rectangle {
    id: pillRoot

    property bool active: true
    property string icon: ""
    property string text: ""

    border.color: active ? Theme.withOpacity(Theme.activeColor, 0.4) : Theme.borderSubtle
    border.width: 1
    color: active ? Theme.withOpacity(Theme.activeColor, 0.15) : Theme.withOpacity(Theme.bgColor, 0.26)
    implicitHeight: Theme.controlHeightLg
    radius: Theme.radiusSm

    Behavior on border.color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }
    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }

    RowLayout {
      spacing: Theme.spacingXs

      anchors {
        fill: parent
        leftMargin: Theme.spacingSm
        rightMargin: Theme.spacingSm
      }

      OText {
        color: pillRoot.active ? Theme.activeColor : Theme.textInactiveColor
        font.pixelSize: Theme.fontMd
        text: pillRoot.icon
      }

      OText {
        Layout.fillWidth: true
        color: pillRoot.active ? Theme.textActiveColor : Theme.textInactiveColor
        elide: Text.ElideRight
        font.pixelSize: Theme.fontSm
        text: pillRoot.text
      }
    }
  }
}
