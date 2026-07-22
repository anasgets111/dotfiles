import QtQuick
import qs.Components
import qs.Config
import qs.Services.Core
import qs.Services.UI

IconButton {
  id: root

  readonly property bool anyInhibit: IdleService.inhibited
  readonly property string reason: !anyInhibit ? "" : [IdleService.manualInhibit ? qsTr("manual") : "", IdleService.fullscreenInhibitorActive ? qsTr("fullscreen") : "", IdleService.videoInhibitorActive ? qsTr("video") : ""].filter(r => r).join(" + ")
  required property string screenName

  colorBg: anyInhibit ? Theme.activeColor : Theme.glassControlColor
  icon: IdleService.manualInhibit ? "󰅶" : "󰾪"
  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemWidth
  tooltipText: anyInhibit ? qsTr("Idle inhibition active") + "\n" + qsTr("Reason: %1").arg(reason) : qsTr("Click to prevent idle")

  onClicked: function (mouse) {
    if (mouse.button === Qt.RightButton)
      ShellUiState.openModal("idleSettings", root.screenName);
    else
      IdleService.manualInhibit = !IdleService.manualInhibit;
  }
}
