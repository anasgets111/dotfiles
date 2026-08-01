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

  readonly property var acProfile: idleSettings?.acProfile ?? null
  readonly property string activeProfileLabel: BatteryService.isOnBattery ? qsTr("Battery") : qsTr("AC power")
  readonly property var batteryProfile: idleSettings?.batteryProfile ?? null
  readonly property real displayPowerOffTimeoutMin: secondsToMinutes(IdleService.displayPowerOffTimeoutSec)
  readonly property int enabledActionCount: (IdleService.lockActionEnabled ? 1 : 0) + (IdleService.suspendActionEnabled ? 1 : 0) + (IdleService.displayPowerOffActionEnabled ? 1 : 0)
  readonly property bool idleEnabled: IdleService.idleEnabled
  readonly property var idleSettings: Settings.data?.idleService ?? null
  readonly property bool inputDisplayBackendReady: InputDisplayService.backendAvailable
  readonly property string inputDisplayStatusText: InputDisplayService.backendCheckComplete ? qsTr("Install showmethekey-cli to use the input overlay.") : qsTr("Checking input overlay availability…")
  readonly property real lockTimeoutMin: secondsToMinutes(IdleService.lockTimeoutSec)
  readonly property int profileColumnWidth: Theme.idleTimeoutControlWidth + Theme.spacingXl
  readonly property real suspendTimeoutMin: secondsToMinutes(IdleService.suspendTimeoutSec)

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
  function profileActionEnabled(profile: var, enabledKey: string, timeoutKey: string, defaultEnabled: bool, defaultTimeoutSec: int): bool {
    return (profile?.[enabledKey] ?? defaultEnabled) && (profile?.[timeoutKey] ?? defaultTimeoutSec) > 0;
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
            text: root.idleEnabled ? qsTr("%1 actions enabled · %2").arg(root.enabledActionCount).arg(root.activeProfileLabel) : qsTr("Automatic actions are paused")
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
          description: qsTr("Configure AC power and battery behavior side by side.")
          icon: "󰒲"
          title: qsTr("Automation")

          ProfileHeader {
          }
          ActionSettingRow {
            defaultTimeoutSec: 300
            description: qsTr("Secure the session after inactivity.")
            enabledKey: "lockEnabled"
            icon: "󰌾"
            label: qsTr("Lock screen")
            timeoutKey: "lockTimeoutSec"
            timeoutOptionsMin: [0.5, 1, 2, 5, 10, 15, 30]
          }
          ActionSettingRow {
            defaultTimeoutSec: 30
            description: qsTr("Power down displays until activity resumes.")
            enabledKey: "dpmsEnabled"
            icon: "󰍹"
            label: qsTr("Turn off displays")
            timeoutKey: "dpmsTimeoutSec"
            timeoutOptionsMin: [0.5, 1, 2, 5, 10, 15]
          }
          ActionSettingRow {
            defaultTimeoutSec: 120
            defaultEnabled: false
            description: qsTr("Suspend the device to reduce power use.")
            enabledKey: "suspendEnabled"
            icon: "󰒚"
            label: qsTr("Suspend system")
            timeoutKey: "suspendTimeoutSec"
            timeoutOptionsMin: [5, 10, 15, 30, 60, 120]
          }
          ActionOrderRow {
          }
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: Theme.spacingLg

          SettingsSection {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            description: qsTr("Wake requests shared by both profiles.")
            icon: "󰒓"
            title: qsTr("Behavior")

            SharedSettingRow {
              checked: root.idleSettings?.respectInhibitors ?? true
              description: qsTr("Honor application wake requests in both profiles.")
              enabled: root.idleEnabled
              icon: "󰈑"
              label: qsTr("Respect inhibitors")

              onToggled: checked => root.idleSettings.respectInhibitors = checked
            }
            SharedSettingRow {
              checked: root.idleSettings?.videoAutoInhibit ?? true
              description: qsTr("Stay awake during active media in both profiles.")
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
            SharedSettingRow {
              checked: InputDisplayService.enabled
              description: qsTr("Show input events on screen.")
              icon: "󰌌"
              label: qsTr("Show input overlay")
              visible: root.inputDisplayBackendReady

              onToggled: checked => InputDisplayService.setEnabled(checked)
            }
            SharedSettingRow {
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

  component ActionOrderRow: RowLayout {
    Layout.bottomMargin: Theme.spacingMd
    Layout.fillWidth: true
    Layout.leftMargin: Theme.spacingLg
    Layout.rightMargin: Theme.spacingLg
    Layout.topMargin: Theme.spacingMd
    opacity: root.idleEnabled ? 1 : Theme.opacityDisabled
    spacing: Theme.spacingMd

    SettingInfo {
      description: qsTr("Choose whether locking or display power-off happens first.")
      highlighted: true
      icon: "󰒓"
      label: qsTr("Action order")
    }
    OrderControl {
      profile: root.acProfile
    }
    OrderControl {
      profile: root.batteryProfile
    }
  }
  component ActionSettingRow: ColumnLayout {
    id: actionRow

    readonly property bool anyEnabled: root.profileActionEnabled(root.acProfile, enabledKey, timeoutKey, defaultEnabled, defaultTimeoutSec) || root.profileActionEnabled(root.batteryProfile, enabledKey, timeoutKey, defaultEnabled, defaultTimeoutSec)
    required property int defaultTimeoutSec
    property bool defaultEnabled: true
    required property string description
    required property string enabledKey
    required property string icon
    required property string label
    required property string timeoutKey
    required property var timeoutOptionsMin

    Layout.fillWidth: true
    opacity: root.idleEnabled ? 1 : Theme.opacityDisabled
    spacing: 0

    RowLayout {
      Layout.bottomMargin: Theme.spacingMd
      Layout.fillWidth: true
      Layout.leftMargin: Theme.spacingLg
      Layout.rightMargin: Theme.spacingLg
      Layout.topMargin: Theme.spacingMd
      spacing: Theme.spacingMd

      SettingInfo {
        description: actionRow.description
        highlighted: actionRow.anyEnabled
        icon: actionRow.icon
        label: actionRow.label
      }
      ProfileControl {
        defaultEnabled: actionRow.defaultEnabled
        defaultTimeoutSec: actionRow.defaultTimeoutSec
        enabledKey: actionRow.enabledKey
        profile: root.acProfile
        timeoutKey: actionRow.timeoutKey
        timeoutOptionsMin: actionRow.timeoutOptionsMin
      }
      ProfileControl {
        defaultEnabled: actionRow.defaultEnabled
        defaultTimeoutSec: actionRow.defaultTimeoutSec
        enabledKey: actionRow.enabledKey
        profile: root.batteryProfile
        timeoutKey: actionRow.timeoutKey
        timeoutOptionsMin: actionRow.timeoutOptionsMin
      }
    }
    Rectangle {
      Layout.fillWidth: true
      Layout.leftMargin: Theme.spacingLg + Theme.controlHeightMd + Theme.spacingMd
      color: Theme.borderSubtle
      implicitHeight: Theme.borderWidthThin
      opacity: Theme.opacityMedium
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
        text: root.idleEnabled ? qsTr("Current flow · %1").arg(root.activeProfileLabel) : qsTr("Automation paused")
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
          readonly property bool stepEnabled: root.idleEnabled && (isLock ? IdleService.lockActionEnabled : isDisplay ? IdleService.displayPowerOffActionEnabled : IdleService.suspendActionEnabled)
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
  component OrderControl: OComboBox {
    required property var profile
    readonly property bool profileActionsEnabled: root.profileActionEnabled(profile, "lockEnabled", "lockTimeoutSec", true, 300) && root.profileActionEnabled(profile, "dpmsEnabled", "dpmsTimeoutSec", true, 30)

    Layout.preferredWidth: root.profileColumnWidth
    currentIndex: (profile?.lockAfterDpms ?? false) ? 1 : 0
    enabled: root.idleEnabled && profileActionsEnabled
    model: [qsTr("Lock first"), qsTr("Display first")]

    onActivated: index => profile.lockAfterDpms = index === 1
  }
  component ProfileControl: OComboBox {
    id: profileControl

    readonly property bool actionEnabled: root.profileActionEnabled(profile, enabledKey, timeoutKey, defaultEnabled, defaultTimeoutSec)
    required property bool defaultEnabled
    required property int defaultTimeoutSec
    readonly property var effectiveTimeoutOptionsMin: timeoutMin <= 0 || timeoutOptionsMin.some(value => Math.abs(value - timeoutMin) < 0.001) ? timeoutOptionsMin : [...timeoutOptionsMin, timeoutMin].sort((left, right) => left - right)
    required property string enabledKey
    required property var profile
    readonly property real timeoutMin: root.secondsToMinutes(profile?.[timeoutKey] ?? defaultTimeoutSec)
    readonly property int timeoutIndex: effectiveTimeoutOptionsMin.length ? Math.max(0, effectiveTimeoutOptionsMin.findIndex(value => Math.abs(value - timeoutMin) < 0.001)) : -1
    required property string timeoutKey
    required property var timeoutOptionsMin

    Layout.preferredWidth: root.profileColumnWidth
    currentIndex: actionEnabled ? timeoutIndex + 1 : 0
    enabled: root.idleEnabled
    model: [qsTr("Off"), ...effectiveTimeoutOptionsMin.map(value => root.formatDuration(value))]

    onActivated: index => {
      if (index === 0) {
        profile[enabledKey] = false;
        return;
      }
      profile[timeoutKey] = root.minutesToSeconds(effectiveTimeoutOptionsMin[index - 1]);
      profile[enabledKey] = true;
    }
  }
  component ProfileHeader: RowLayout {
    Layout.bottomMargin: Theme.spacingSm
    Layout.fillWidth: true
    Layout.leftMargin: Theme.spacingLg
    Layout.rightMargin: Theme.spacingLg
    Layout.topMargin: Theme.spacingSm
    spacing: Theme.spacingMd

    Item {
      Layout.preferredWidth: Theme.controlHeightMd
    }
    OText {
      Layout.fillWidth: true
      bold: true
      color: Theme.textInactiveColor
      font.pixelSize: Theme.fontSm
      text: qsTr("Action")
    }
    ProfileHeading {
      battery: false
    }
    ProfileHeading {
      battery: true
    }
  }
  component ProfileHeading: OText {
    required property bool battery
    readonly property bool isActive: battery === BatteryService.isOnBattery

    Layout.preferredWidth: root.profileColumnWidth
    bold: true
    color: isActive ? Theme.activeColor : Theme.textInactiveColor
    font.pixelSize: Theme.fontSm
    horizontalAlignment: Text.AlignHCenter
    text: battery ? (isActive ? qsTr("Battery · Active") : qsTr("Battery")) : (isActive ? qsTr("AC power · Active") : qsTr("AC power"))
  }
  component SettingInfo: RowLayout {
    id: infoRoot

    required property string description
    property bool highlighted: false
    required property string icon
    required property string label

    Layout.fillWidth: true
    spacing: Theme.spacingMd

    OText {
      Layout.alignment: Qt.AlignTop
      Layout.preferredWidth: Theme.controlHeightMd
      color: infoRoot.highlighted ? Theme.activeColor : Theme.textInactiveColor
      font.pixelSize: Theme.fontMd
      horizontalAlignment: Text.AlignHCenter
      text: infoRoot.icon
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingXs

      OText {
        Layout.fillWidth: true
        bold: infoRoot.highlighted
        color: Theme.textActiveColor
        font.pixelSize: Theme.fontLg
        text: infoRoot.label
      }
      OText {
        Layout.fillWidth: true
        color: Theme.textInactiveColor
        font.pixelSize: Theme.fontSm
        text: infoRoot.description
        wrapMode: Text.Wrap
      }
    }
  }
  component SharedSettingRow: ColumnLayout {
    id: rowRoot

    required property bool checked
    required property string description
    required property string icon
    required property string label
    property bool showSeparator: true

    signal toggled(bool checked)

    Layout.fillWidth: true
    opacity: enabled ? 1 : Theme.opacityDisabled
    spacing: 0

    Theme.NumberTransition on opacity {
    }

    RowLayout {
      Layout.bottomMargin: Theme.spacingMd
      Layout.fillWidth: true
      Layout.leftMargin: Theme.spacingLg
      Layout.rightMargin: Theme.spacingLg
      Layout.topMargin: Theme.spacingMd
      spacing: Theme.spacingMd

      SettingInfo {
        description: rowRoot.description
        highlighted: rowRoot.checked
        icon: rowRoot.icon
        label: rowRoot.label
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
