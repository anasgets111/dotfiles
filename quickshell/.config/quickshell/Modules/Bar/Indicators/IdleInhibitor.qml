import QtQuick
import Quickshell.Wayland
import qs.Components
import qs.Config
import qs.Services.Core
import qs.Services.UI

IconButton {
  id: root

  required property string screenName

  readonly property bool anyInhibit: manualInhibit || IdleService.effectiveInhibited
  property bool manualInhibit: false
  readonly property string reason: !anyInhibit ? "" : [manualInhibit ? qsTr("manual") : "", IdleService.effectiveInhibited ? qsTr("video") : ""].filter(r => r).join(" + ")

  colorBg: anyInhibit ? Theme.activeColor : Theme.inactiveColor
  icon: manualInhibit ? "󰅶" : "󰾪"
  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth
  tooltipText: anyInhibit ? qsTr("Idle inhibition active") + "\n" + qsTr("Reason: %1").arg(reason) : qsTr("Click to prevent idle")

  onClicked: function (mouse) {
    if (mouse.button === Qt.RightButton)
      ShellUiState.openModal("idleSettings", root.screenName);
    else
      root.manualInhibit = !root.manualInhibit;
  }

  IdleInhibitor {
    enabled: root.manualInhibit
    window: IdleService.window
  }
}
