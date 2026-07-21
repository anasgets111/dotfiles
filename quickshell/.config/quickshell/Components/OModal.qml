pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Config

Item {
  id: root

  property bool active: false
  readonly property Region blurRegion: Region {
    height: root.visible ? modalSurface.height - Theme.borderWidthMedium * 2 : 0
    radius: Theme.modalRadius
    width: root.visible ? modalSurface.width - Theme.borderWidthMedium * 2 : 0
    x: modalSurface.x + Theme.borderWidthMedium
    y: modalSurface.y + Theme.borderWidthMedium
  }
  default property alias content: contentSlot.data
  property Item initialFocusItem: null
  property int preferredHeight: Theme.launcherWindowHeight
  property int preferredWidth: Theme.launcherWindowWidth
  property color scrimColor: Theme.modalScrimColor
  property real scrimOpacity: Theme.modalScrimOpacity
  property var searchInput: null

  signal dismissed
  signal keyPressed(var event)

  function close(): void {
    if (!active)
      return;
    active = false;
    closeTimer.restart();
  }
  function open(): void {
    closeTimer.stop();
    active = true;
  }
  function resetFocus(): void {
    if (searchInput) {
      searchInput.clear?.();
      if (searchInput.text !== undefined)
        searchInput.text = "";
    }
    Qt.callLater(() => (initialFocusItem ?? searchInput ?? modalSurface).forceActiveFocus?.());
  }

  anchors.fill: parent
  focus: active
  visible: active || closeTimer.running

  onActiveChanged: if (active)
    resetFocus()

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
      if (local.x >= 0 && local.y >= 0 && local.x <= modalSurface.width && local.y <= modalSurface.height) {
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
        return;
      }
      root.keyPressed(event);
    }

    Item {
      id: contentSlot
      anchors.fill: parent
    }
  }
}
