pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Modules.Bar.Indicators
import qs.Services.Core

Item {
  id: centerSide

  required property string screenName

  implicitHeight: mediaIndicatorLoader.active ? Theme.panelHeight : activeWindowTitle.implicitHeight
  implicitWidth: mediaIndicatorLoader.active ? Math.round(parent.width / 3) : activeWindowTitle.implicitWidth

  Loader {
    id: mediaIndicatorLoader

    active: MediaService.playbackAvailable
    anchors.fill: parent

    sourceComponent: MediaIndicator {
      screenName: centerSide.screenName
    }
  }
  ActiveWindow {
    id: activeWindowTitle

    anchors.centerIn: parent
  }
}
