pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Services.Core
import qs.Services.UI

Item {
  id: root

  readonly property bool panelOpen: ShellUiState.isPanelOpen("media", root.screenName)
  required property string screenName

  function openPanel(): void {
    closeTimer.stop();
    ShellUiState.openPanel("media", screenName, ShellUiState.anchorRectForItem(root), root);
  }
  function setPanelHovered(hovered: bool): void {
    closeTimer.stop();
    if (!hovered && !trigger.hovered && panelOpen)
      closeTimer.restart();
  }

  Accessible.name: qsTr("Media controls")
  Accessible.onPressAction: root.openPanel()
  Accessible.role: Accessible.Button
  Component.onDestruction: if (panelOpen)
    ShellUiState.closePanel()

  Row {
    id: bars

    anchors.fill: parent
    anchors.margins: Theme.spacingXs
    opacity: MediaService.playing ? Theme.opacityMedium : Theme.opacitySubtle
    spacing: Theme.borderWidthThin

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }

    Repeater {
      model: CavaService.barCount

      delegate: Item {
        id: barSlot

        required property int index

        height: parent.height
        width: (bars.width - bars.spacing * (CavaService.barCount - 1)) / CavaService.barCount

        Rectangle {
          anchors.bottom: parent.bottom
          color: Theme.activeColor
          height: Math.max(Theme.borderWidthMedium, parent.height * CavaService.values[barSlot.index])
          radius: width / 2
          width: parent.width
        }
      }
    }
  }
  Timer {
    id: closeTimer

    interval: Theme.animationSlow

    onTriggered: if (!trigger.hovered && root.panelOpen)
      ShellUiState.closePanel()
  }
  HoverHandler {
    id: trigger

    cursorShape: Qt.PointingHandCursor

    onHoveredChanged: {
      if (hovered)
        root.openPanel();
      else if (root.panelOpen)
        closeTimer.restart();
    }
  }
}
