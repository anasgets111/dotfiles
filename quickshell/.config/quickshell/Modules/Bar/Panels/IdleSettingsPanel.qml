pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Config
import qs.Components
import qs.Services.Utils

Item {
  id: root

  property bool active: false
  property bool closeOnActivate: false
  property int contentMargin: Theme.spacingLg * 1.5
  property int contentSpacing: Theme.spacingLg
  property bool showSearchField: false
  property int windowHeight: 820
  property int windowWidth: 1024

  property real lockTimeout: 5
  property real suspendTimeout: 2
  property real dpmsTimeout: 0

  signal dismissed

  function close() {
    if (!root.active)
      return;
    root.active = false;
    root.dismissed();
  }

  function open() {
    if (!root.active)
      root.active = true;
    loadFromSettings();
  }

  function loadFromSettings() {
    const idle = Settings.data?.idleService;
    if (!idle) return;
    lockTimeout = (idle.lockTimeoutSec ?? 300) / 60;
    suspendTimeout = (idle.suspendTimeoutSec ?? 120) / 60;
    dpmsTimeout = (idle.dpmsTimeoutSec ?? 30) / 60;
  }

  function saveLockTimeout(v) {
    if (Settings.data?.idleService) Settings.data.idleService.lockTimeoutSec = Math.round(v * 60);
  }

  function saveSuspendTimeout(v) {
    if (Settings.data?.idleService) Settings.data.idleService.suspendTimeoutSec = Math.round(v * 60);
  }

  function saveDpmsTimeout(v) {
    if (Settings.data?.idleService) Settings.data.idleService.dpmsTimeoutSec = Math.round(v * 60);
  }

  anchors.fill: parent
  focus: active
  visible: active

  onActiveChanged: {
    if (root.active)
      loadFromSettings();
    else
      root.releaseFocus();
  }

  Component.onCompleted: loadFromSettings()

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
          width: Theme.iconSizeXl * 1.4
          height: Theme.iconSizeXl * 1.4
          radius: Theme.radiusMd
          color: Theme.activeColor

          OText {
            anchors.centerIn: parent
            color: Theme.bgColor
            font.pixelSize: Theme.fontXl * 1.2
            text: "󰾪"
          }
        }

        ColumnLayout {
          spacing: 2
          Layout.fillWidth: true
          OText {
            bold: true
            font.pixelSize: Theme.fontXl
            text: qsTr("Idle Settings")
          }
          OText {
            font.pixelSize: Theme.fontMd
            color: Theme.textInactiveColor
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
        height: 1
        color: Theme.borderSubtle
      }

      ScrollView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        contentWidth: availableWidth
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
          width: parent.width
          spacing: Theme.spacingXl

          SettingGroup {
            title: qsTr("GENERAL")

            SettingRow {
              icon: "󰾪"
              label: qsTr("Idle Service")
              checked: Settings.data?.idleService?.enabled ?? true
              showSeparator: false
              onToggled: c => { if (Settings.data?.idleService) Settings.data.idleService.enabled = c; }
            }
          }

          SettingGroup {
            title: qsTr("AUTOMATIC ACTIONS")
            disabled: !(Settings.data?.idleService?.enabled ?? true)

            SettingRow {
              icon: "󰌾"
              label: qsTr("Lock Screen")
              checked: Settings.data?.idleService?.lockEnabled ?? true
              disabled: !(Settings.data?.idleService?.enabled ?? true)
              hasSlider: true
              sliderValue: root.lockTimeout
              sliderMax: 30
              onToggled: c => { if (Settings.data?.idleService) Settings.data.idleService.lockEnabled = c; }
              onSliderChanged: v => { root.lockTimeout = v; root.saveLockTimeout(v); }
            }

            SettingRow {
              icon: "󰒚"
              label: qsTr("Suspend System")
              checked: Settings.data?.idleService?.suspendEnabled ?? false
              disabled: !(Settings.data?.idleService?.enabled ?? true)
              hasSlider: true
              sliderValue: root.suspendTimeout
              sliderMax: 60
              onToggled: c => { if (Settings.data?.idleService) Settings.data.idleService.suspendEnabled = c; }
              onSliderChanged: v => { root.suspendTimeout = v; root.saveSuspendTimeout(v); }
            }

            SettingRow {
              icon: "󰍹"
              label: qsTr("Turn Off Display")
              checked: Settings.data?.idleService?.dpmsEnabled ?? true
              disabled: !(Settings.data?.idleService?.enabled ?? true)
              hasSlider: true
              sliderValue: root.dpmsTimeout
              sliderMax: 10
              showSeparator: false
              onToggled: c => { if (Settings.data?.idleService) Settings.data.idleService.dpmsEnabled = c; }
              onSliderChanged: v => { root.dpmsTimeout = v; root.saveDpmsTimeout(v); }
            }
          }

          SettingGroup {
            title: qsTr("ADVANCED")
            disabled: !(Settings.data?.idleService?.enabled ?? true)

            SettingRow {
              icon: "󰈑"
              label: qsTr("Respect Inhibitors")
              checked: Settings.data?.idleService?.respectInhibitors ?? true
              disabled: !(Settings.data?.idleService?.enabled ?? true)
              onToggled: c => { if (Settings.data?.idleService) Settings.data.idleService.respectInhibitors = c; }
            }

            SettingRow {
              icon: "󰀈"
              label: qsTr("Video Inhibit")
              checked: Settings.data?.idleService?.videoAutoInhibit ?? true
              disabled: !(Settings.data?.idleService?.enabled ?? true)
              showSeparator: false
              onToggled: c => { if (Settings.data?.idleService) Settings.data.idleService.videoAutoInhibit = c; }
            }
          }
        }
      }
    }
  }

  function isPointInsidePopup(item, x, y) {
    if (!item)
      return false;
    const local = item.mapFromItem(dismissArea, x, y);
    return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
  }

  function releaseFocus() {
  }

  // Internal Components
  component SettingGroup: ColumnLayout {
    default property alias content: innerColumn.data
    property string title: ""
    property bool disabled: false

    Layout.fillWidth: true
    spacing: Theme.spacingMd
    opacity: disabled ? Theme.opacityDisabled : 1.0
    enabled: !disabled

    OText {
      text: title
      font.pixelSize: Theme.fontMd
      bold: true
      color: Theme.textInactiveColor
      Layout.leftMargin: Theme.spacingSm
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: innerColumn.implicitHeight + Theme.spacingLg * 2
      color: Theme.bgElevated
      radius: Theme.radiusMd
      border.color: Theme.borderSubtle
      border.width: 1

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
    property string icon: ""
    property string label: ""
    property bool showSeparator: true
    property bool disabled: false
    property bool hasSlider: false
    property real sliderValue: 0
    property real sliderMax: 60
    property string sliderSuffix: "min"
    property bool checked: false

    function formatValue(val) {
      if (val === 0) return qsTr("Never");
      const mins = Math.floor(val);
      const secs = Math.round((val - mins) * 60);
      let res = "";
      if (mins > 0) res += mins + "m";
      if (secs > 0) res += (res ? " " : "") + secs + "s";
      return res || "0s";
    }

    signal toggled(bool checked)
    signal sliderChanged(real value)

    Layout.fillWidth: true
    spacing: Theme.spacingMd
    opacity: disabled ? Theme.opacityDisabled : 1.0
    enabled: !disabled

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingLg

      Rectangle {
        width: Theme.controlHeightLg
        height: Theme.controlHeightLg
        radius: Theme.radiusSm
        color: rowRoot.checked ? Theme.activeSubtle : Theme.bgElevatedAlt
        border.color: rowRoot.checked ? Theme.activeColor : Theme.borderSubtle
        border.width: 1

        OText {
          anchors.centerIn: parent
          text: rowRoot.icon
          color: rowRoot.checked ? Theme.activeColor : Theme.textInactiveColor
          font.pixelSize: Theme.fontLg
        }
      }

      OText {
        text: rowRoot.label
        Layout.fillWidth: true
        font.pixelSize: Theme.fontLg
        bold: rowRoot.checked
        color: rowRoot.checked ? Theme.textActiveColor : Theme.textInactiveColor
      }

      OToggle {
        size: "lg"
        checked: rowRoot.checked
        disabled: rowRoot.disabled
        onToggled: c => rowRoot.toggled(c)
      }
    }

    // Slider section
    ColumnLayout {
      Layout.fillWidth: true
      visible: hasSlider && checked
      spacing: Theme.spacingSm
      Layout.leftMargin: Theme.controlHeightLg + Theme.spacingLg

      RowLayout {
        Layout.fillWidth: true
        OText {
          text: qsTr("Timeout")
          font.pixelSize: Theme.fontMd
          color: Theme.textInactiveColor
        }
        Item { Layout.fillWidth: true }
        OText {
          text: formatValue(sliderValue)
          font.pixelSize: Theme.fontMd
          bold: true
          color: Theme.activeColor
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 28

        Slider {
          anchors.fill: parent
          value: sliderValue / sliderMax
          steps: sliderMax * 2 // 0.5 min steps
          fillColor: Theme.activeColor
          radius: 14
          interactive: !rowRoot.disabled

          onCommitted: v => rowRoot.sliderChanged(Math.round(v * sliderMax * 2) / 2)
        }
      }

      Item { Layout.preferredHeight: Theme.spacingXs }
    }

    Rectangle {
      visible: showSeparator
      Layout.fillWidth: true
      height: 1
      color: Theme.borderSubtle
      Layout.leftMargin: Theme.controlHeightLg + Theme.spacingLg
      opacity: 0.3
    }
  }
}
