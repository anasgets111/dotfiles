import QtQuick
import Quickshell.Wayland
import qs.Components
import qs.Config
import qs.Services.Core

IconButton {
  id: root

  readonly property bool anyInhibit: manualInhibit || IdleService.effectiveInhibited
  property bool manualInhibit: false
  readonly property string reason: !anyInhibit ? "" : [manualInhibit ? qsTr("manual") : "", IdleService.effectiveInhibited ? qsTr("video") : ""].filter(r => r).join(" + ")

  colorBg: anyInhibit ? Theme.activeColor : Theme.inactiveColor
  icon: manualInhibit ? "󰅶" : "󰾪"
  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth
  tooltipText: anyInhibit ? qsTr("Idle inhibition active") + "\n" + qsTr("Reason: %1").arg(reason) : qsTr("Click to prevent idle")

  onClicked: manualInhibit = !manualInhibit

  IdleInhibitor {
    enabled: root.manualInhibit
    window: IdleService.window
  }
}
