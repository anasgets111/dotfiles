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

  readonly property bool displayPowerOffEnabled: IdleService.displayPowerOffEnabled
  readonly property real displayPowerOffTimeout: IdleService.displayPowerOffTimeoutMin
  readonly property int enabledActionCount: IdleService.enabledActionCount
  readonly property var flowSteps: IdleService.flowSteps
  readonly property bool idleEnabled: IdleService.idleEnabled
  readonly property bool inputDisplayBackendReady: InputDisplayService.backendAvailable
  readonly property string inputDisplayStatusText: InputDisplayService.backendCheckComplete ? qsTr("Install showmethekey-cli to use the input overlay.") : qsTr("Checking input overlay availability…")
  readonly property bool lockAfterDisplayPowerOff: IdleService.lockAfterDisplayPowerOff
  readonly property bool lockEnabled: IdleService.lockEnabled
  readonly property real lockTimeout: IdleService.lockTimeoutMin
  readonly property bool suspendEnabled: IdleService.suspendEnabled
  readonly property real suspendTimeout: IdleService.suspendTimeoutMin
  preferredHeight: Theme.idleModalHeight
  preferredWidth: Theme.idleModalWidth

  function formatDuration(value: real): string {
    const totalSeconds = Math.max(0, Math.round((Number(value) || 0) * 60));
    if (totalSeconds === 0)
      return qsTr("Not set");
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    if (minutes > 0 && seconds > 0)
      return qsTr("%1 min %2 sec").arg(minutes).arg(seconds);
    return minutes > 0 ? qsTr("%1 min").arg(minutes) : qsTr("%1 sec").arg(seconds);
  }
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
              disabled: !root.idleEnabled
              icon: "󰌾"
              label: qsTr("Lock screen")
              timeoutValue: root.lockTimeout
              timeoutValues: [0.5, 1, 2, 5, 10, 15, 30]

              onTimeoutChanged: value => IdleService.setLockTimeoutMin(value)
              onToggled: checked => {
                if (checked && root.lockTimeout <= 0)
                  IdleService.setLockTimeoutMin(5);
                IdleService.setLockEnabled(checked);
              }
            }
            SettingRow {
              checked: root.displayPowerOffEnabled
              description: qsTr("Power down displays until activity resumes.")
              disabled: !root.idleEnabled
              icon: "󰍹"
              label: qsTr("Turn off displays")
              timeoutValue: root.displayPowerOffTimeout
              timeoutValues: [0.5, 1, 2, 5, 10, 15]

              onTimeoutChanged: value => IdleService.setDisplayPowerOffTimeoutMin(value)
              onToggled: checked => {
                if (checked && root.displayPowerOffTimeout <= 0)
                  IdleService.setDisplayPowerOffTimeoutMin(1);
                IdleService.setDisplayPowerOffEnabled(checked);
              }
            }
            SettingRow {
              checked: root.suspendEnabled
              description: qsTr("Suspend the device to reduce power use.")
              disabled: !root.idleEnabled
              icon: "󰒚"
              label: qsTr("Suspend system")
              showSeparator: false
              timeoutValue: root.suspendTimeout
              timeoutValues: [5, 10, 15, 30, 60, 120]

              onTimeoutChanged: value => IdleService.setSuspendTimeoutMin(value)
              onToggled: checked => {
                if (checked && root.suspendTimeout <= 0)
                  IdleService.setSuspendTimeoutMin(10);
                IdleService.setSuspendEnabled(checked);
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
                    bgColor: root.lockAfterDisplayPowerOff ? Theme.bgCard : Theme.activeColor
                    size: "sm"
                    text: qsTr("Lock first")
                    textColor: root.lockAfterDisplayPowerOff ? Theme.textInactiveColor : Theme.textContrast(bgColor)

                    onClicked: IdleService.setLockAfterDisplayPowerOff(false)
                  }
                  OButton {
                    Layout.fillWidth: true
                    bgColor: root.lockAfterDisplayPowerOff ? Theme.activeColor : Theme.bgCard
                    size: "sm"
                    text: qsTr("Display first")
                    textColor: root.lockAfterDisplayPowerOff ? Theme.textContrast(bgColor) : Theme.textInactiveColor

                    onClicked: IdleService.setLockAfterDisplayPowerOff(true)
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
                checked: IdleService.respectInhibitorsEnabled
                description: qsTr("Honor application wake requests.")
                disabled: !root.idleEnabled
                icon: "󰈑"
                label: qsTr("Respect inhibitors")

                onToggled: checked => IdleService.setRespectInhibitors(checked)
              }
              SettingRow {
                checked: IdleService.videoAutoInhibitEnabled
                description: qsTr("Stay awake during active media.")
                disabled: !root.idleEnabled
                icon: "󰀈"
                label: qsTr("Keep awake for media")
                showSeparator: false

                onToggled: checked => IdleService.setVideoAutoInhibit(checked)
              }
            }
            SettingsSection {
              Layout.alignment: Qt.AlignTop
              Layout.fillWidth: true
              description: qsTr("Show pressed keys and mouse buttons.")
              icon: "󰖳"
              title: qsTr("Input overlay")

              InlineMessage {
                Layout.fillWidth: true
                icon: InputDisplayService.backendCheckComplete ? "󰅚" : "󰔟"
                text: root.inputDisplayStatusText
                visible: !root.inputDisplayBackendReady
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
                disabled: !InputDisplayService.enabled
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
    tone: root.idleEnabled ? "active" : "standard"
    padding: 0
    implicitHeight: flowLayout.implicitHeight + Theme.spacingMd * 2

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
        model: root.flowSteps

        delegate: RowLayout {
          required property int index
          readonly property bool isDisplay: modelData === "displayPowerOff"
          readonly property bool isLock: modelData === "lock"
          required property var modelData
          readonly property bool stepEnabled: root.idleEnabled && (isLock ? root.lockEnabled : isDisplay ? root.displayPowerOffEnabled : root.suspendEnabled)
          readonly property string stepLabel: isLock ? qsTr("Lock") : isDisplay ? qsTr("Display") : qsTr("Suspend")
          readonly property real timeout: isLock ? root.lockTimeout : isDisplay ? root.displayPowerOffTimeout : root.suspendTimeout

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
            text: parent.stepEnabled ? qsTr("%1 · %2").arg(parent.stepLabel).arg(root.formatDuration(parent.timeout)) : qsTr("%1 · Off").arg(parent.stepLabel)
          }
          OText {
            color: Theme.textInactiveColor
            font.pixelSize: Theme.fontSm
            opacity: Theme.opacityDisabled
            text: "→"
            visible: parent.index < root.flowSteps.length - 1
          }
        }
      }
      OToggle {
        Layout.alignment: Qt.AlignVCenter
        checked: root.idleEnabled
        size: "lg"
        onToggled: checked => IdleService.setIdleEnabled(checked)
      }
    }
  }
  component InlineMessage: PanelCard {
    id: messageRoot

    property string icon: ""
    property string text: ""

    Layout.leftMargin: Theme.spacingLg
    Layout.rightMargin: Theme.spacingLg
    implicitHeight: messageRow.implicitHeight + padding * 2
    padding: Theme.spacingMd

    RowLayout {
      id: messageRow

      anchors.fill: parent
      spacing: Theme.spacingSm

      OText {
        color: Theme.textInactiveColor
        font.pixelSize: Theme.fontMd
        text: messageRoot.icon
      }
      OText {
        Layout.fillWidth: true
        color: Theme.textInactiveColor
        font.pixelSize: Theme.fontSm
        text: messageRoot.text
        wrapMode: Text.Wrap
      }
    }
  }
  component SettingRow: ColumnLayout {
    id: rowRoot

    property bool checked: false
    property string description: ""
    property bool disabled: false
    readonly property var effectiveTimeoutValues: {
      const values = timeoutValues.slice();
      if (timeoutValue > 0 && !values.some(value => Math.abs(value - timeoutValue) < 0.001)) {
        values.push(timeoutValue);
        values.sort((left, right) => left - right);
      }
      return values;
    }
    property string icon: ""
    property string label: ""
    property bool showSeparator: true
    property real timeoutValue: 0
    property var timeoutValues: []

    signal timeoutChanged(real value)
    signal toggled(bool checked)

    function timeoutIndex(): int {
      if (effectiveTimeoutValues.length === 0)
        return -1;
      let closestIndex = 0;
      let closestDistance = Math.abs(effectiveTimeoutValues[0] - timeoutValue);
      for (let i = 1; i < effectiveTimeoutValues.length; i++) {
        const distance = Math.abs(effectiveTimeoutValues[i] - timeoutValue);
        if (distance < closestDistance) {
          closestDistance = distance;
          closestIndex = i;
        }
      }
      return closestIndex;
    }

    Layout.fillWidth: true
    enabled: !disabled
    opacity: disabled ? Theme.opacityDisabled : 1
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
        currentIndex: rowRoot.timeoutIndex()
        model: rowRoot.effectiveTimeoutValues.map(value => root.formatDuration(value))
        visible: rowRoot.timeoutValues.length > 0 && rowRoot.checked

        onActivated: index => rowRoot.timeoutChanged(rowRoot.effectiveTimeoutValues[index])
      }
      OToggle {
        Layout.alignment: Qt.AlignVCenter
        checked: rowRoot.checked
        disabled: rowRoot.disabled
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

    default property alias sectionItems: sectionContent.data
    property string description: ""
    property string icon: ""
    property string title: ""

    padding: 0
    implicitHeight: sectionLayout.implicitHeight + Theme.spacingLg * 2

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
