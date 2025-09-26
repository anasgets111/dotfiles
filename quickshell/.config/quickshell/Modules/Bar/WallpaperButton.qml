pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Components
import qs.Services.Core as Core
import qs.Services.WM as WM

IconButton {
  id: controlButton

  property string wallpaperGlob: "/mnt/Work/1Wallpapers/Main/*.{jpg,jpeg,png,webp,JPG,JPEG,PNG,WEBP}"
  property bool enableRandomizeFallback: true
  signal pickerRequested
  signal randomized

  colorBg: Theme.inactiveColor
  icon: ""
  tooltipText: qsTr("Manage wallpapers")

  onClicked: function (mouse) {
    if (!mouse)
      return;
    if (mouse.button === Qt.LeftButton)
      controlButton.openPicker();
    else if (mouse.button === Qt.RightButton)
      controlButton.randomizeAll();
    mouse.accepted = true;
  }

  function openPicker() {
    controlButton.pickerRequested();
  }

  function randomizeAll() {
    if (!WM.MonitorService || !WM.MonitorService.ready)
      return;
    Core.FileSystemService.listByGlob(controlButton.wallpaperGlob, function (files) {
      const list = Array.isArray(files) ? files.filter(f => !!f) : [];
      if (!list.length) {
        if (controlButton.enableRandomizeFallback)
          console.warn("WallpaperControl: no wallpapers found for", controlButton.wallpaperGlob);
        return;
      }
      for (let i = 0; i < WM.MonitorService.monitors.count; i++) {
        const mon = WM.MonitorService.monitors.get(i);
        const chosen = list[Math.floor(Math.random() * list.length)];
        Core.WallpaperService.setWallpaper(mon.name, chosen);
      }
      controlButton.randomized();
    });
  }
}
