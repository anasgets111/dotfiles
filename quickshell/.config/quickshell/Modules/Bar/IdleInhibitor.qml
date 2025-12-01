import QtQuick
import Quickshell.Wayland
import qs.Components
import qs.Config
import qs.Services.Core

IconButton {
  id: root

  readonly property bool anyInhibit: manualInhibit || IdleService.effectiveInhibited
  property bool manualInhibit: false
  readonly property string reason: {
    if (!anyInhibit)
      return "";
    const reasons = [];
    if (manualInhibit)
      reasons.push(qsTr("manual"));
    if (MediaService.anyVideoPlaying)
      reasons.push(qsTr("video"));
    else if (IdleService.effectiveInhibited)
      reasons.push(qsTr("external"));
    return reasons.join(" + ");
  }

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
