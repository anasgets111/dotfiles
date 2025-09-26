pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Services.Core as Core
import qs.Services.WM as WM
import qs.Components
import qs.Services.Utils as Utils

Row {
  id: centerSide

  required property bool normalWorkspacesExpanded

  spacing: 8

  IconButton {
    id: launcherButton

    anchors.verticalCenter: parent.verticalCenter
    colorBg: Theme.inactiveColor
    icon: "󰍉"
    tooltipText: qsTr("Open application launcher")

    onClicked: Utils.IPC.launcherActive = !Utils.IPC.launcherActive
  }

  // Active window title display
  ActiveWindow {
    id: activeWindowTitle

    anchors.verticalCenter: parent.verticalCenter
    visible: true
  }

  IconButton {
    id: testWalButton
    anchors.verticalCenter: parent.verticalCenter
    colorBg: Theme.inactiveColor
    icon: "" // image icon (Nerd Font)
    tooltipText: qsTr("Randomize wallpapers on all monitors")
    onClicked: {
      if (!WM.MonitorService || !WM.MonitorService.ready)
        return;
      const pattern = "/mnt/Work/1Wallpapers/Main/*.{jpg,jpeg,png,webp,JPG,JPEG,PNG,WEBP}";
      Core.FileSystemService.listByGlob(pattern, function (files) {
        const list = Array.isArray(files) ? files.filter(f => !!f && f.length > 0) : [];
        if (!list.length)
          return;
        for (let i = 0; i < WM.MonitorService.monitors.count; i++) {
          const mon = WM.MonitorService.monitors.get(i);
          const chosen = list[Math.floor(Math.random() * list.length)];
          Core.WallpaperService.setWallpaper(mon.name, chosen);
        }
      });
    }
  }
}
