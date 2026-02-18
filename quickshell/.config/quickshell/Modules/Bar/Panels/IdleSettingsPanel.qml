pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import qs.Config
import qs.Components

Item {
  id: root

  // ── Properties ────────────────────────────────────────────────
  property bool active: false
  readonly property bool dpmsEnabled: idleData?.dpmsEnabled ?? true
  property real dpmsTimeout: 0
  readonly property int enabledActionCount: (lockEnabled ? 1 : 0) + (suspendEnabled ? 1 : 0) + (dpmsEnabled ? 1 : 0)
  readonly property var idleData: Settings.data?.idleService ?? null
  readonly property bool idleEnabled: idleData?.enabled ?? true
  readonly property bool lockEnabled: idleData?.lockEnabled ?? true
  property real lockTimeout: 5
  readonly property bool suspendEnabled: idleData?.suspendEnabled ?? false
  property real suspendTimeout: 2
  property int windowHeight: 820
  property int windowWidth: 1000

  signal dismissed

  function close() {
    if (!active)
      return;
    active = false;
    dismissed();
  }

  function formatDuration(v) {
    if (v <= 0)
      return qsTr("Never");
    const mins = Math.floor(v);
    const secs = Math.round((v - mins) * 60);
    if (mins > 0 && secs > 0)
      return `${mins}m ${secs}s`;
    return mins > 0 ? `${mins}m` : `${secs}s`;
  }

  function loadFromSettings() {
    const idle = Settings.data?.idleService;
    if (!idle)
      return;
    lockTimeout = (idle.lockTimeoutSec ?? 300) / 60;
    suspendTimeout = (idle.suspendTimeoutSec ?? 120) / 60;
    dpmsTimeout = (idle.dpmsTimeoutSec ?? 30) / 60;
  }

  function open() {
    active = true;
  }

  function saveTimeout(key, v) {
    if (Settings.data?.idleService)
      Settings.data.idleService[key] = Math.round(v * 60);
  }

  // ── Root ──────────────────────────────────────────────────────
  anchors.fill: parent
  focus: active
  visible: active

  Component.onCompleted: loadFromSettings()
  onActiveChanged: if (active)
    loadFromSettings()

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

          StatusPill {
            Layout.fillWidth: true
            active: root.idleEnabled && root.lockEnabled
            icon: "󰌾"
            text: active ? qsTr("Lock • %1").arg(root.formatDuration(root.lockTimeout)) : qsTr("Lock • Off")
          }

          StatusPill {
            Layout.fillWidth: true
            active: root.idleEnabled && root.dpmsEnabled
            icon: "󰍹"
            text: active ? qsTr("Display • %1").arg(root.formatDuration(root.dpmsTimeout)) : qsTr("Display • Off")
          }

          StatusPill {
            Layout.fillWidth: true
            active: root.idleEnabled && root.suspendEnabled
            icon: "󰒚"
            text: active ? qsTr("Suspend • %1").arg(root.formatDuration(root.suspendTimeout)) : qsTr("Suspend • Off")
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

                  onToggled: c => {
                    if (root.idleData)
                      root.idleData.enabled = c;
                  }
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

                  onSliderChanged: v => {
                    root.lockTimeout = v;
                    root.saveTimeout("lockTimeoutSec", v);
                  }
                  onToggled: c => {
                    if (root.idleData)
                      root.idleData.lockEnabled = c;
                  }
                }

                SettingRow {
                  checked: root.dpmsEnabled
                  description: qsTr("Power down monitors when no activity is detected.")
                  disabled: !root.idleEnabled
                  hasSlider: true
                  icon: "󰍹"
                  label: qsTr("Turn Off Display")
                  sliderMax: 10
                  sliderValue: root.dpmsTimeout

                  onSliderChanged: v => {
                    root.dpmsTimeout = v;
                    root.saveTimeout("dpmsTimeoutSec", v);
                  }
                  onToggled: c => {
                    if (root.idleData)
                      root.idleData.dpmsEnabled = c;
                  }
                }

                SettingRow {
                  checked: root.suspendEnabled
                  description: qsTr("Save power by suspending the device.")
                  disabled: !root.idleEnabled
                  hasSlider: true
                  icon: "󰒚"
                  label: qsTr("Suspend System")
                  showSeparator: false
                  sliderMax: 60
                  sliderValue: root.suspendTimeout

                  onSliderChanged: v => {
                    root.suspendTimeout = v;
                    root.saveTimeout("suspendTimeoutSec", v);
                  }
                  onToggled: c => {
                    if (root.idleData)
                      root.idleData.suspendEnabled = c;
                  }
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
                checked: root.idleData?.respectInhibitors ?? true
                description: qsTr("Honor compositor and app inhibit requests.")
                disabled: !root.idleEnabled
                icon: "󰈑"
                label: qsTr("Respect Inhibitors")

                onToggled: c => {
                  if (root.idleData)
                    root.idleData.respectInhibitors = c;
                }
              }

              SettingRow {
                checked: root.idleData?.videoAutoInhibit ?? true
                description: qsTr("Auto-inhibit while media is actively playing.")
                disabled: !root.idleEnabled
                icon: "󰀈"
                label: qsTr("Video Inhibit")
                showSeparator: false

                onToggled: c => {
                  if (root.idleData)
                    root.idleData.videoAutoInhibit = c;
                }
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
                text: qsTr("Tip: set timeouts in this order for a clean flow: Lock → Display Off → Suspend.")
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

    function formatValue(val) {
      if (val <= 0)
        return qsTr("Never");
      const mins = Math.floor(val), secs = Math.round((val - mins) * 60);
      let r = mins > 0 ? mins + "m" : "";
      if (secs > 0)
        r += (r ? " " : "") + secs + "s";
      return r || "0s";
    }

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
            text: rowRoot.hasSlider && rowRoot.checked ? qsTr("Timeout: %1").arg(rowRoot.formatValue(rowRoot.sliderValue)) : rowRoot.description
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
            text: rowRoot.formatValue(rowRoot.sliderValue)
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
            text: rowRoot.formatValue(rowRoot.sliderMax)
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
