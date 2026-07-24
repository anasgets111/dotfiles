pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Services.Core
import qs.Services.SystemInfo

OModal {
  id: root

  readonly property bool displayPowerOffEnabled: idleSettings.dpmsEnabled
  readonly property real displayPowerOffTimeoutMin: secondsToMinutes(idleSettings.dpmsTimeoutSec)
  readonly property int enabledActionCount: (IdleService.lockActionEnabled ? 1 : 0) + (IdleService.suspendActionEnabled ? 1 : 0) + (IdleService.displayPowerOffActionEnabled ? 1 : 0)
  readonly property bool idleEnabled: IdleService.idleEnabled
  readonly property var idleSettings: Settings.data.idleService
  readonly property bool inputDisplayBackendReady: InputDisplayService.backendAvailable
  readonly property string inputDisplayStatusText: InputDisplayService.backendCheckComplete ? qsTr("Install showmethekey-cli to use the input overlay.") : qsTr("Checking input overlay availability…")
  readonly property bool lockAfterDisplayPowerOff: idleSettings.lockAfterDpms
  readonly property bool lockEnabled: idleSettings.lockEnabled
  readonly property real lockTimeoutMin: secondsToMinutes(idleSettings.lockTimeoutSec)
  readonly property bool suspendEnabled: idleSettings.suspendEnabled
  readonly property real suspendTimeoutMin: secondsToMinutes(idleSettings.suspendTimeoutSec)

  function formatDuration(durationMin: real): string {
    const totalSeconds = Math.max(0, Math.round((durationMin || 0) * 60));
    if (totalSeconds === 0)
      return qsTr("Not set");
    const wholeMinutes = Math.floor(totalSeconds / 60);
    const remainingSeconds = totalSeconds % 60;
    if (wholeMinutes > 0 && remainingSeconds > 0)
      return qsTr("%1 min %2 sec").arg(wholeMinutes).arg(remainingSeconds);
    return wholeMinutes > 0 ? qsTr("%1 min").arg(wholeMinutes) : qsTr("%1 sec").arg(remainingSeconds);
  }
  function minutesToSeconds(value: real): int {
    return Math.round(Math.max(0, value || 0) * 60);
  }
  function secondsToMinutes(value: int): real {
    return Math.max(0, value || 0) / 60;
  }

  preferredHeight: Theme.idleModalHeight
  preferredWidth: Theme.idleModalWidth

  onActiveChanged: if (active)
    InputDisplayService.refreshBackendAvailability()

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: headerLayout.implicitHeight + Theme.spacingXl * 2

      RowLayout {
        id: headerLayout

        anchors.fill: parent
        anchors.leftMargin: Theme.spacingXl
        anchors.rightMargin: Theme.spacingXl
        spacing: Theme.spacingMd

        Rectangle {
          Layout.preferredHeight: Theme.controlHeightXl
          Layout.preferredWidth: Theme.controlHeightXl
          color: Theme.activeSubtle
          radius: Theme.radiusLg

          OText {
            anchors.centerIn: parent
            color: Theme.activeColor
            font.pixelSize: Theme.fontXl
            text: "󰾪"
          }
        }
        ColumnLayout {
          spacing: Theme.spacingXs

          OText {
            bold: true
            font.pixelSize: Theme.fontXxl
            text: qsTr("Idle & Power")
          }
          OText {
            color: Theme.textInactiveColor
            font.pixelSize: Theme.fontMd
            text: root.idleEnabled ? qsTr("%1 automatic actions enabled").arg(root.enabledActionCount) : qsTr("Automatic actions are paused")
          }
        }
        Item {
          Layout.fillWidth: true
        }
      }
    }
    Rectangle {
      Layout.fillWidth: true
      color: Theme.borderSubtle
      implicitHeight: Theme.borderWidthThin
    }
    ScrollView {
      id: scrollView

      Layout.fillHeight: true
      Layout.fillWidth: true
      ScrollBar.vertical.policy: ScrollBar.AsNeeded
      contentWidth: availableWidth

      ColumnLayout {
        spacing: Theme.spacingLg
        width: scrollView.availableWidth - Theme.spacingXl * 2
        x: Theme.spacingXl

        Item {
          Layout.preferredHeight: Theme.spacingSm
        }
        FlowSummary {
          Layout.fillWidth: true
        }
        SettingsSection {
          Layout.fillWidth: true
          description: qsTr("Choose what happens when the session is inactive.")
          icon: "󰒲"
          title: qsTr("Automation")

          SettingRow {
            checked: root.lockEnabled
            description: qsTr("Secure the session after inactivity.")
            enabled: root.idleEnabled
            icon: "󰌾"
            label: qsTr("Lock screen")
            timeoutMin: root.lockTimeoutMin
            timeoutOptionsMin: [0.5, 1, 2, 5, 10, 15, 30]

            onTimeoutSelected: minutes => root.idleSettings.lockTimeoutSec = root.minutesToSeconds(minutes)
            onToggled: checked => {
              if (checked && root.lockTimeoutMin <= 0)
                root.idleSettings.lockTimeoutSec = root.minutesToSeconds(5);
              root.idleSettings.lockEnabled = checked;
            }
          }
          SettingRow {
            checked: root.displayPowerOffEnabled
            description: qsTr("Power down displays until activity resumes.")
            enabled: root.idleEnabled
            icon: "󰍹"
            label: qsTr("Turn off displays")
            timeoutMin: root.displayPowerOffTimeoutMin
            timeoutOptionsMin: [0.5, 1, 2, 5, 10, 15]

            onTimeoutSelected: minutes => root.idleSettings.dpmsTimeoutSec = root.minutesToSeconds(minutes)
            onToggled: checked => {
              if (checked && root.displayPowerOffTimeoutMin <= 0)
                root.idleSettings.dpmsTimeoutSec = root.minutesToSeconds(1);
              root.idleSettings.dpmsEnabled = checked;
            }
          }
          SettingRow {
            checked: root.suspendEnabled
            description: qsTr("Suspend the device to reduce power use.")
            enabled: root.idleEnabled
            icon: "󰒚"
            label: qsTr("Suspend system")
            showSeparator: false
            timeoutMin: root.suspendTimeoutMin
            timeoutOptionsMin: [5, 10, 15, 30, 60, 120]

            onTimeoutSelected: minutes => root.idleSettings.suspendTimeoutSec = root.minutesToSeconds(minutes)
            onToggled: checked => {
              if (checked && root.suspendTimeoutMin <= 0)
                root.idleSettings.suspendTimeoutSec = root.minutesToSeconds(10);
              root.idleSettings.suspendEnabled = checked;
            }
          }
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: Theme.spacingLg

          SettingsSection {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            description: qsTr("Action order and wake requests.")
            icon: "󰒓"
            title: qsTr("Behavior")

            ColumnLayout {
              Layout.fillWidth: true
              Layout.leftMargin: Theme.spacingLg
              Layout.rightMargin: Theme.spacingLg
              Layout.topMargin: Theme.spacingSm
              enabled: root.idleEnabled && root.lockEnabled && root.displayPowerOffEnabled
              opacity: enabled ? 1 : Theme.opacityDisabled
              spacing: Theme.spacingSm

              OText {
                bold: true
                font.pixelSize: Theme.fontLg
                text: qsTr("Action order")
              }
              RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXs

                OButton {
                  Layout.fillWidth: true
                  bgColor: root.lockAfterDisplayPowerOff ? Theme.glassContentColor : Theme.activeColor
                  size: "sm"
                  text: qsTr("Lock first")
                  textColor: root.lockAfterDisplayPowerOff ? Theme.textInactiveColor : Theme.textContrast(bgColor)

                  onClicked: root.idleSettings.lockAfterDpms = false
                }
                OButton {
                  Layout.fillWidth: true
                  bgColor: root.lockAfterDisplayPowerOff ? Theme.activeColor : Theme.glassContentColor
                  size: "sm"
                  text: qsTr("Display first")
                  textColor: root.lockAfterDisplayPowerOff ? Theme.textContrast(bgColor) : Theme.textInactiveColor

                  onClicked: root.idleSettings.lockAfterDpms = true
                }
              }
            }
            Rectangle {
              Layout.fillWidth: true
              Layout.leftMargin: Theme.spacingLg
              color: Theme.borderSubtle
              implicitHeight: Theme.borderWidthThin
              opacity: Theme.opacityMedium
            }
            SettingRow {
              checked: root.idleSettings.respectInhibitors
              description: qsTr("Honor application wake requests.")
              enabled: root.idleEnabled
              icon: "󰈑"
              label: qsTr("Respect inhibitors")

              onToggled: checked => root.idleSettings.respectInhibitors = checked
            }
            SettingRow {
              checked: root.idleSettings.videoAutoInhibit
              description: qsTr("Stay awake during active media.")
              enabled: root.idleEnabled
              icon: "󰀈"
              label: qsTr("Keep awake for media")
              showSeparator: false

              onToggled: checked => root.idleSettings.videoAutoInhibit = checked
            }
          }
          SettingsSection {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            description: qsTr("Show pressed keys and mouse buttons.")
            icon: "󰖳"
            title: qsTr("Input overlay")

            PanelCard {
              Layout.fillWidth: true
              Layout.leftMargin: Theme.spacingLg
              Layout.rightMargin: Theme.spacingLg
              implicitHeight: backendStatusRow.implicitHeight + padding * 2
              padding: Theme.spacingMd
              visible: !root.inputDisplayBackendReady

              RowLayout {
                id: backendStatusRow

                anchors.fill: parent
                spacing: Theme.spacingSm

                OText {
                  color: Theme.textInactiveColor
                  font.pixelSize: Theme.fontMd
                  text: InputDisplayService.backendCheckComplete ? "󰅚" : "󰔟"
                }
                OText {
                  Layout.fillWidth: true
                  color: Theme.textInactiveColor
                  font.pixelSize: Theme.fontSm
                  text: root.inputDisplayStatusText
                  wrapMode: Text.Wrap
                }
              }
            }
            SettingRow {
              checked: InputDisplayService.enabled
              description: qsTr("Show input events on screen.")
              icon: "󰌌"
              label: qsTr("Show input overlay")
              visible: root.inputDisplayBackendReady

              onToggled: checked => InputDisplayService.setEnabled(checked)
            }
            SettingRow {
              checked: InputDisplayService.showPrintableKeys
              description: qsTr("Include letters and punctuation.")
              enabled: InputDisplayService.enabled
              icon: "󰌌"
              label: qsTr("Printable keys")
              showSeparator: false
              visible: root.inputDisplayBackendReady

              onToggled: checked => InputDisplayService.setShowPrintableKeys(checked)
            }
          }
        }
        Item {
          Layout.preferredHeight: Theme.spacingMd
        }
      }
    }
  }

  component FlowSummary: PanelCard {
    implicitHeight: flowLayout.implicitHeight + Theme.spacingMd * 2
    padding: 0
    tone: root.idleEnabled ? "active" : "standard"

    RowLayout {
      id: flowLayout

      anchors.fill: parent
      anchors.leftMargin: Theme.spacingLg
      anchors.rightMargin: Theme.spacingLg
      spacing: Theme.spacingSm

      OText {
        color: root.idleEnabled ? Theme.activeColor : Theme.textInactiveColor
        font.pixelSize: Theme.fontLg
        text: root.idleEnabled ? "󰐊" : "󰏤"
      }
      OText {
        bold: true
        color: root.idleEnabled ? Theme.textActiveColor : Theme.textInactiveColor
        font.pixelSize: Theme.fontSm
        text: root.idleEnabled ? qsTr("Current flow") : qsTr("Automation paused")
      }
      Item {
        Layout.fillWidth: true
      }
      Repeater {
        model: IdleService.flowSteps

        delegate: RowLayout {
          required property int index
          readonly property bool isDisplay: modelData === "displayPowerOff"
          readonly property bool isLock: modelData === "lock"
          required property string modelData
          readonly property bool stepEnabled: root.idleEnabled && (isLock ? root.lockEnabled : isDisplay ? root.displayPowerOffEnabled : root.suspendEnabled)
          readonly property string stepLabel: isLock ? qsTr("Lock") : isDisplay ? qsTr("Display") : qsTr("Suspend")
          readonly property real timeoutMin: isLock ? root.lockTimeoutMin : isDisplay ? root.displayPowerOffTimeoutMin : root.suspendTimeoutMin

          spacing: Theme.spacingSm

          OText {
            color: parent.stepEnabled ? Theme.activeColor : Theme.textInactiveColor
            font.pixelSize: Theme.fontSm
            opacity: parent.stepEnabled ? 1 : 0.45
            text: parent.isLock ? "󰌾" : parent.isDisplay ? "󰍹" : "󰒚"
          }
          OText {
            color: parent.stepEnabled ? Theme.textActiveColor : Theme.textInactiveColor
            font.pixelSize: Theme.fontSm
            opacity: parent.stepEnabled ? 1 : 0.45
            text: parent.stepEnabled ? qsTr("%1 · %2").arg(parent.stepLabel).arg(root.formatDuration(parent.timeoutMin)) : qsTr("%1 · Off").arg(parent.stepLabel)
          }
          OText {
            color: Theme.textInactiveColor
            font.pixelSize: Theme.fontSm
            opacity: Theme.opacityDisabled
            text: "→"
            visible: parent.index < IdleService.flowSteps.length - 1
          }
        }
      }
      OToggle {
        Layout.alignment: Qt.AlignVCenter
        checked: root.idleEnabled
        size: "lg"

        onToggled: checked => root.idleSettings.enabled = checked
      }
    }
  }
  component SettingRow: ColumnLayout {
    id: rowRoot

    property bool checked: false
    property string description: ""
    readonly property var effectiveTimeoutOptionsMin: timeoutMin <= 0 || timeoutOptionsMin.some(value => Math.abs(value - timeoutMin) < 0.001) ? timeoutOptionsMin : [...timeoutOptionsMin, timeoutMin].sort((left, right) => left - right)
    property string icon: ""
    property string label: ""
    property bool showSeparator: true
    readonly property int timeoutIndex: effectiveTimeoutOptionsMin.length ? Math.max(0, effectiveTimeoutOptionsMin.findIndex(value => Math.abs(value - timeoutMin) < 0.001)) : -1
    property real timeoutMin: 0
    property var timeoutOptionsMin: []

    signal timeoutSelected(real minutes)
    signal toggled(bool checked)

    Layout.fillWidth: true
    opacity: enabled ? 1 : Theme.opacityDisabled
    spacing: 0

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }

    RowLayout {
      Layout.bottomMargin: Theme.spacingMd
      Layout.fillWidth: true
      Layout.leftMargin: Theme.spacingLg
      Layout.rightMargin: Theme.spacingLg
      Layout.topMargin: Theme.spacingMd
      spacing: Theme.spacingMd

      OText {
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: Theme.controlHeightMd
        color: rowRoot.checked ? Theme.activeColor : Theme.textInactiveColor
        font.pixelSize: Theme.fontMd
        horizontalAlignment: Text.AlignHCenter
        text: rowRoot.icon
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingXs

        OText {
          Layout.fillWidth: true
          bold: rowRoot.checked
          color: Theme.textActiveColor
          font.pixelSize: Theme.fontLg
          text: rowRoot.label
        }
        OText {
          Layout.fillWidth: true
          color: Theme.textInactiveColor
          font.pixelSize: Theme.fontSm
          text: rowRoot.description
          wrapMode: Text.Wrap
        }
      }
      OComboBox {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Theme.idleTimeoutControlWidth
        currentIndex: rowRoot.timeoutIndex
        model: rowRoot.effectiveTimeoutOptionsMin.map(value => root.formatDuration(value))
        visible: rowRoot.timeoutOptionsMin.length > 0 && rowRoot.checked

        onActivated: index => rowRoot.timeoutSelected(rowRoot.effectiveTimeoutOptionsMin[index])
      }
      OToggle {
        Layout.alignment: Qt.AlignVCenter
        checked: rowRoot.checked
        disabled: !rowRoot.enabled
        size: "lg"

        onToggled: checked => rowRoot.toggled(checked)
      }
    }
    Rectangle {
      Layout.fillWidth: true
      Layout.leftMargin: Theme.spacingLg + Theme.controlHeightMd + Theme.spacingMd
      color: Theme.borderSubtle
      implicitHeight: Theme.borderWidthThin
      opacity: Theme.opacityMedium
      visible: rowRoot.showSeparator
    }
  }
  component SettingsSection: PanelCard {
    id: sectionRoot

    property string description: ""
    property string icon: ""
    default property alias sectionItems: sectionContent.data
    property string title: ""

    implicitHeight: sectionLayout.implicitHeight + Theme.spacingLg * 2
    padding: 0

    ColumnLayout {
      id: sectionLayout

      anchors.bottomMargin: Theme.spacingLg
      anchors.fill: parent
      anchors.topMargin: Theme.spacingLg
      spacing: Theme.spacingMd

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacingLg
        Layout.rightMargin: Theme.spacingLg
        spacing: Theme.spacingSm

        OText {
          color: Theme.activeColor
          font.pixelSize: Theme.fontLg
          text: sectionRoot.icon
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Theme.spacingXs

          OText {
            bold: true
            font.pixelSize: Theme.fontXl
            text: sectionRoot.title
          }
          OText {
            Layout.fillWidth: true
            color: Theme.textInactiveColor
            font.pixelSize: Theme.fontSm
            text: sectionRoot.description
            wrapMode: Text.Wrap
          }
        }
      }
      ColumnLayout {
        id: sectionContent

        Layout.fillWidth: true
        spacing: 0
      }
    }
  }
}
