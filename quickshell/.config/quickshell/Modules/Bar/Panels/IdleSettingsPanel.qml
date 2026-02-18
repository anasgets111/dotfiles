pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Config
import qs.Components

Item {
  id: root

  property bool active: false
  property bool closeOnActivate: false
  property int contentMargin: Theme.spacingLg * 1.5
  property int contentSpacing: Theme.spacingLg
  property real dpmsTimeout: 0
  property real lockTimeout: 5
  property bool showSearchField: false
  property real suspendTimeout: 2
  property int windowHeight: 820
  property int windowWidth: 1024

  signal dismissed

  function close() {
    if (!root.active)
      return;
    root.active = false;
    root.dismissed();
  }

  function isPointInsidePopup(item, x, y) {
    if (!item)
      return false;
    const local = item.mapFromItem(dismissArea, x, y);
    return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
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
    if (!root.active)
      root.active = true;
    loadFromSettings();
  }

  function releaseFocus() {
  }

  function saveDpmsTimeout(v) {
    if (Settings.data?.idleService)
      Settings.data.idleService.dpmsTimeoutSec = Math.round(v * 60);
  }

  function saveLockTimeout(v) {
    if (Settings.data?.idleService)
      Settings.data.idleService.lockTimeoutSec = Math.round(v * 60);
  }

  function saveSuspendTimeout(v) {
    if (Settings.data?.idleService)
      Settings.data.idleService.suspendTimeoutSec = Math.round(v * 60);
  }

  anchors.fill: parent
  focus: active
  visible: active

  Component.onCompleted: loadFromSettings()
  onActiveChanged: {
    if (root.active)
      loadFromSettings();
    else
      root.releaseFocus();
  }

  MouseArea {
    id: dismissArea

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    anchors.fill: parent

    onPressed: function (mouse) {
      if (root.isPointInsidePopup(popupRect, mouse.x, mouse.y)) {
        mouse.accepted = false;
        return;
      }
      root.close();
    }
  }

  Rectangle {
    id: popupRect

    anchors.centerIn: parent
    border.color: Theme.borderLight
    border.width: 1
    color: Theme.bgColor
    focus: true
    height: root.windowHeight
    radius: Theme.radiusLg
    width: root.windowWidth

    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape) {
        root.close();
        event.accepted = true;
      }
    }

    ColumnLayout {
      id: contentColumn

      anchors.fill: parent
      anchors.margins: root.contentMargin
      spacing: root.contentSpacing

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingLg

        Rectangle {
          color: Theme.activeColor
          implicitHeight: Theme.iconSizeXl * 1.4
          implicitWidth: Theme.iconSizeXl * 1.4
          radius: Theme.radiusMd

          OText {
            anchors.centerIn: parent
            color: Theme.bgColor
            font.pixelSize: Theme.fontXl * 1.2
            text: "󰾪"
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          OText {
            bold: true
            font.pixelSize: Theme.fontXl
            text: qsTr("Idle Settings")
          }

          OText {
            color: Theme.textInactiveColor
            font.pixelSize: Theme.fontMd
            text: qsTr("Configure system behavior when inactive")
          }
        }

        IconButton {
          Layout.preferredHeight: Theme.controlHeightLg
          Layout.preferredWidth: Theme.controlHeightLg
          colorBg: Theme.bgElevatedAlt
          icon: "󰅖"
          tooltipText: qsTr("Close")

          onClicked: root.close()
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        color: Theme.borderSubtle
        implicitHeight: 1
      }

      ScrollView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        contentWidth: availableWidth

        ColumnLayout {
          spacing: Theme.spacingXl
          width: parent.width

          SettingGroup {
            title: qsTr("GENERAL")

            SettingRow {
              checked: Settings.data?.idleService?.enabled ?? true
              icon: "󰾪"
              label: qsTr("Idle Service")
              showSeparator: false

              onToggled: c => {
                if (Settings.data?.idleService)
                  Settings.data.idleService.enabled = c;
              }
            }
          }

          SettingGroup {
            disabled: !(Settings.data?.idleService?.enabled ?? true)
            title: qsTr("AUTOMATIC ACTIONS")

            SettingRow {
              checked: Settings.data?.idleService?.lockEnabled ?? true
              disabled: !(Settings.data?.idleService?.enabled ?? true)
              hasSlider: true
              icon: "󰌾"
              label: qsTr("Lock Screen")
              sliderMax: 30
              sliderValue: root.lockTimeout

              onSliderChanged: v => {
                root.lockTimeout = v;
                root.saveLockTimeout(v);
              }
              onToggled: c => {
                if (Settings.data?.idleService)
                  Settings.data.idleService.lockEnabled = c;
              }
            }

            SettingRow {
              checked: Settings.data?.idleService?.suspendEnabled ?? false
              disabled: !(Settings.data?.idleService?.enabled ?? true)
              hasSlider: true
              icon: "󰒚"
              label: qsTr("Suspend System")
              sliderMax: 60
              sliderValue: root.suspendTimeout

              onSliderChanged: v => {
                root.suspendTimeout = v;
                root.saveSuspendTimeout(v);
              }
              onToggled: c => {
                if (Settings.data?.idleService)
                  Settings.data.idleService.suspendEnabled = c;
              }
            }

            SettingRow {
              checked: Settings.data?.idleService?.dpmsEnabled ?? true
              disabled: !(Settings.data?.idleService?.enabled ?? true)
              hasSlider: true
              icon: "󰍹"
              label: qsTr("Turn Off Display")
              showSeparator: false
              sliderMax: 10
              sliderValue: root.dpmsTimeout

              onSliderChanged: v => {
                root.dpmsTimeout = v;
                root.saveDpmsTimeout(v);
              }
              onToggled: c => {
                if (Settings.data?.idleService)
                  Settings.data.idleService.dpmsEnabled = c;
              }
            }
          }

          SettingGroup {
            disabled: !(Settings.data?.idleService?.enabled ?? true)
            title: qsTr("ADVANCED")

            SettingRow {
              checked: Settings.data?.idleService?.respectInhibitors ?? true
              disabled: !(Settings.data?.idleService?.enabled ?? true)
              icon: "󰈑"
              label: qsTr("Respect Inhibitors")

              onToggled: c => {
                if (Settings.data?.idleService)
                  Settings.data.idleService.respectInhibitors = c;
              }
            }

            SettingRow {
              checked: Settings.data?.idleService?.videoAutoInhibit ?? true
              disabled: !(Settings.data?.idleService?.enabled ?? true)
              icon: "󰀈"
              label: qsTr("Video Inhibit")
              showSeparator: false

              onToggled: c => {
                if (Settings.data?.idleService)
                  Settings.data.idleService.videoAutoInhibit = c;
              }
            }
          }
        }
      }
    }
  }

  // Internal Components
  component SettingGroup: ColumnLayout {
    default property alias content: innerColumn.data
    property bool disabled: false
    property string title: ""

    Layout.fillWidth: true
    enabled: !disabled
    opacity: disabled ? Theme.opacityDisabled : 1.0
    spacing: Theme.spacingMd

    OText {
      Layout.leftMargin: Theme.spacingSm
      bold: true
      color: Theme.textInactiveColor
      font.pixelSize: Theme.fontMd
      text: title
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: innerColumn.implicitHeight + Theme.spacingLg * 2
      border.color: Theme.borderSubtle
      border.width: 1
      color: Theme.bgElevated
      radius: Theme.radiusMd

      ColumnLayout {
        id: innerColumn

        anchors.fill: parent
        anchors.margins: Theme.spacingLg
        spacing: Theme.spacingLg
      }
    }
  }
  component SettingRow: ColumnLayout {
    id: rowRoot

    property bool checked: false
    property bool disabled: false
    property bool hasSlider: false
    property string icon: ""
    property string label: ""
    property bool showSeparator: true
    property real sliderMax: 60
    property string sliderSuffix: "min"
    property real sliderValue: 0

    signal sliderChanged(real value)
    signal toggled(bool checked)

    function formatValue(val) {
      if (val === 0)
        return qsTr("Never");
      const mins = Math.floor(val);
      const secs = Math.round((val - mins) * 60);
      let res = "";
      if (mins > 0)
        res += mins + "m";
      if (secs > 0)
        res += (res ? " " : "") + secs + "s";
      return res || "0s";
    }

    Layout.fillWidth: true
    enabled: !disabled
    opacity: disabled ? Theme.opacityDisabled : 1.0
    spacing: Theme.spacingMd

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingLg

      Rectangle {
        border.color: rowRoot.checked ? Theme.activeColor : Theme.borderSubtle
        border.width: 1
        color: rowRoot.checked ? Theme.activeSubtle : Theme.bgElevatedAlt
        implicitHeight: Theme.controlHeightLg
        implicitWidth: Theme.controlHeightLg
        radius: Theme.radiusSm

        OText {
          anchors.centerIn: parent
          color: rowRoot.checked ? Theme.activeColor : Theme.textInactiveColor
          font.pixelSize: Theme.fontLg
          text: rowRoot.icon
        }
      }

      OText {
        Layout.fillWidth: true
        bold: rowRoot.checked
        color: rowRoot.checked ? Theme.textActiveColor : Theme.textInactiveColor
        font.pixelSize: Theme.fontLg
        text: rowRoot.label
      }

      OToggle {
        checked: rowRoot.checked
        disabled: rowRoot.disabled
        size: "lg"

        onToggled: c => rowRoot.toggled(c)
      }
    }

    // Slider section
    ColumnLayout {
      Layout.fillWidth: true
      Layout.leftMargin: Theme.controlHeightLg + Theme.spacingLg
      spacing: Theme.spacingSm
      visible: rowRoot.hasSlider && rowRoot.checked

      RowLayout {
        Layout.fillWidth: true

        OText {
          color: Theme.textInactiveColor
          font.pixelSize: Theme.fontMd
          text: qsTr("Timeout")
        }

        Item {
          Layout.fillWidth: true
        }

        OText {
          bold: true
          color: Theme.activeColor
          font.pixelSize: Theme.fontMd
          text: rowRoot.formatValue(rowRoot.sliderValue)
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 28

        Slider {
          anchors.fill: parent
          fillColor: Theme.activeColor
          interactive: !rowRoot.disabled
          radius: 14
          steps: rowRoot.sliderMax * 2 // 0.5 min steps
          value: rowRoot.sliderValue / rowRoot.sliderMax

          onCommitted: v => rowRoot.sliderChanged(Math.round(v * rowRoot.sliderMax * 2) / 2)
        }
      }

      Item {
        Layout.preferredHeight: Theme.spacingXs
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.leftMargin: Theme.controlHeightLg + Theme.spacingLg
      color: Theme.borderSubtle
      implicitHeight: 1
      opacity: 0.3
      visible: rowRoot.showSeparator
    }
  }
}
