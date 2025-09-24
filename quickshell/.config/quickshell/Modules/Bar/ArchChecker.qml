pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import qs.Services.SystemInfo
import qs.Config
import qs.Components

Item {
  id: root

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, button.implicitWidth)

  IconButton {
    id: button
    anchors.fill: parent
    colorBg: UpdateService.busy ? Theme.inactiveColor : (UpdateService.totalUpdates > 0 ? Theme.activeColor : Theme.inactiveColor)
    icon: UpdateService.busy ? "" : (UpdateService.totalUpdates > 0 ? "" : "󰂪")
    tooltipText: UpdateService.busy ? qsTr("Checking for updates…") : (UpdateService.totalUpdates === 0 ? qsTr("No updates available") : (() => {
          const pkgs = UpdateService.allPackages || [];
          const header = UpdateService.totalUpdates === 1 ? qsTr("One package can be upgraded:") : (UpdateService.totalUpdates + " " + qsTr("packages can be upgraded:"));
          // Limit list length to avoid overly tall tooltip
          const maxLines = 10;
          const lines = pkgs.slice(0, maxLines).map(p => `${p.name}: ${p.oldVersion} → ${p.newVersion}`);
          if (pkgs.length > maxLines)
            lines.push(qsTr("…and %1 more").arg(pkgs.length - maxLines));
          return [header].concat(lines).join("\n");
        })())
    onClicked: {
      if (UpdateService.busy)
        return;
      if (UpdateService.totalUpdates > 0)
        UpdateService.runUpdate();
      else
        UpdateService.doPoll(true);
    }
  }
}
