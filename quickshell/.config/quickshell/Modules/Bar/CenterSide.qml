pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Modules.Bar.Indicators
import qs.Services.Core

Item {
  id: centerSide

  required property string screenName

  implicitHeight: activeWindowTitle.implicitHeight
  implicitWidth: Math.max(activeWindowTitle.implicitWidth, mediaIndicatorLoader.active ? Theme.mediaIndicatorWidth : 0)

  Loader {
    id: mediaIndicatorLoader

    active: MediaService.playbackAvailable
    anchors.centerIn: parent
    height: parent.height
    width: Theme.mediaIndicatorWidth

    sourceComponent: MediaIndicator {
      screenName: centerSide.screenName
    }
  }
  ActiveWindow {
    id: activeWindowTitle

    anchors.centerIn: parent
  }
}
