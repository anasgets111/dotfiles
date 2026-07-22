pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Config

Item {
  id: root

  property bool active: false
  readonly property Region blurRegion: Region {
    height: root.visible ? modalSurface.height * modalSurface.scale : 0
    radius: modalSurface.radius * modalSurface.scale
    width: root.visible ? modalSurface.width * modalSurface.scale : 0
    x: modalSurface.x + (modalSurface.width - width) / 2
    y: modalSurface.y + (modalSurface.height - height) / 2 + modalTranslate.y
  }
  default property alias content: contentSlot.data
  property int preferredHeight: Theme.launcherWindowHeight
  property int preferredWidth: Theme.launcherWindowWidth
  property real progress: 0
  property var searchInput: null

  signal dismissed

  function close(): void {
    if (!active)
      return;
    active = false;
  }

  anchors.fill: parent
  focus: active
  visible: active || progressAnimation.running || progress > 0

  onActiveChanged: {
    progressAnimation.easing.type = active ? Easing.OutCubic : Easing.InCubic;
    progressAnimation.to = active ? 1 : 0;
    progressAnimation.restart();
    if (active) {
      searchInput?.clear?.();
      Qt.callLater(() => {
        if (active)
          (searchInput ?? modalSurface).forceActiveFocus?.();
      });
    }
  }

  NumberAnimation {
    id: progressAnimation

    duration: Theme.animationDuration
    property: "progress"
    target: root

    onFinished: if (!root.active)
      root.dismissed()
  }
  Rectangle {
    anchors.fill: parent
    color: Theme.modalScrimColor
    opacity: Theme.modalScrimOpacity * root.progress
  }
  MouseArea {
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    anchors.fill: parent

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
    border.color: Theme.glassBorderColor
    border.width: Theme.borderWidthThin
    clip: true
    color: Theme.glassSurfaceColor
    focus: true
    height: Math.min(root.preferredHeight, root.height - Theme.modalMargin * 2)
    radius: Theme.modalRadius
    scale: Theme.modalClosedScale + (1 - Theme.modalClosedScale) * root.progress
    width: Math.min(root.preferredWidth, root.width - Theme.modalMargin * 2)

    transform: Translate {
      id: modalTranslate

      y: -Theme.spacingMd * (1 - root.progress)
    }

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
