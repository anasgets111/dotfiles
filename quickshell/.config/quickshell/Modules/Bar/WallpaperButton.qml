pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Components
import qs.Services.Core

IconButton {
  id: controlButton

  signal pickerRequested

  function openPicker() {
    controlButton.pickerRequested();
  }

  colorBg: Theme.inactiveColor
  icon: ""
  tooltipText: qsTr("Manage wallpapers")

  onClicked: function (mouse) {
    if (!mouse)
      return;
    if (mouse.button === Qt.LeftButton)
      controlButton.openPicker();
    else if (mouse.button === Qt.RightButton)
      WallpaperService.randomizeAllMonitors();

    mouse.accepted = true;
  }
}
