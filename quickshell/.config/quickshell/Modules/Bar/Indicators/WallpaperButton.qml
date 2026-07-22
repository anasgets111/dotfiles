pragma ComponentBehavior: Bound

import QtQuick
import qs.Components
import qs.Services.Core

IconButton {
  id: controlButton

  signal pickerRequested

  icon: ""
  tooltipText: qsTr("Manage wallpapers")

  onClicked: function (mouse) {
    if (!mouse)
      return;
    if (mouse.button === Qt.LeftButton)
      controlButton.pickerRequested();
    else if (mouse.button === Qt.RightButton)
      WallpaperService.randomizeAllMonitors();

    mouse.accepted = true;
  }
}
