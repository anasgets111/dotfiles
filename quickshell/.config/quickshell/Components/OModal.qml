pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Config

Item {
  id: root

  property bool active: false
  readonly property Region blurRegion: Region {
    height: modalSurface.opacity > 0 ? modalSurface.height * modalSurface.scale : 0
    radius: modalSurface.radius * modalSurface.scale
    width: modalSurface.opacity > 0 ? modalSurface.width * modalSurface.scale : 0
    x: modalSurface.x + (modalSurface.width - width) / 2
    y: modalSurface.y + (modalSurface.height - height) / 2 + modalTranslate.y
  }
  default property alias content: contentSlot.data
  property int preferredHeight: Theme.launcherWindowHeight
  property int preferredWidth: Theme.launcherWindowWidth
  property color scrimColor: Theme.modalScrimColor
  property real scrimOpacity: Theme.modalScrimOpacity
  property var searchInput: null

  signal dismissed
  function close(): void {
    if (!active)
      return;
    active = false;
    closeTimer.restart();
  }
  anchors.fill: parent
  focus: active
  visible: active || closeTimer.running

  onActiveChanged: if (active) {
    closeTimer.stop();
    searchInput?.clear?.();
    Qt.callLater(() => (searchInput ?? modalSurface).forceActiveFocus?.());
  }

  Timer {
    id: closeTimer

    interval: Theme.animationDuration
    onTriggered: root.dismissed()
  }

  Rectangle {
    anchors.fill: parent
    color: root.scrimColor
    opacity: root.active ? root.scrimOpacity : 0

    Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }
  }
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: mouse => {
      const local = modalSurface.mapFromItem(root, mouse.x, mouse.y);
      if (modalSurface.contains(local)) {
        mouse.accepted = false;
        return;
      }
      root.close();
    }
  }
  Rectangle {
    id: modalSurface

    anchors.centerIn: parent
    border.color: Theme.borderLight
    border.width: Theme.borderWidthThin
    clip: true
    color: Theme.bgPanel
    focus: true
    height: Math.min(root.preferredHeight, root.height - Theme.modalMargin * 2)
    opacity: root.active ? 1 : 0
    radius: Theme.modalRadius
    scale: root.active ? 1 : Theme.modalClosedScale
    transform: Translate {
      id: modalTranslate

      y: root.active ? 0 : -Theme.spacingMd
      Behavior on y { NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutCubic } }
    }
    width: Math.min(root.preferredWidth, root.width - Theme.modalMargin * 2)

    Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }
    Behavior on scale { NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutCubic } }

    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape) {
        root.close();
        event.accepted = true;
      }
    }

    Item {
      id: contentSlot
      anchors.fill: parent
    }
  }
}
