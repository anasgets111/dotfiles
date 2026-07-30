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
  Accessible.role: Accessible.Button

  Accessible.onPressAction: root.openPanel()
  Component.onDestruction: if (panelOpen)
    ShellUiState.closePanel()

  Item {
    id: bars

    readonly property real barPitch: (width + Theme.borderWidthThin) / Math.max(1, CavaService.barCount)

    anchors.fill: parent
    anchors.margins: Theme.spacingXs
    opacity: MediaService.playing ? Theme.opacityMedium : Theme.opacitySubtle

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }

    Repeater {
      model: CavaService.barCount

      // Never give these a radius: see the antialiasing note in AGENTS.md.
      delegate: Rectangle {
        required property int index

        anchors.bottom: bars.bottom
        color: Theme.activeColor
        height: Math.max(Theme.borderWidthMedium, bars.height * CavaService.values[index])
        width: bars.barPitch - Theme.borderWidthThin
        x: index * bars.barPitch
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
      if (hovered && (!ShellUiState.isAnyPanelOpen || root.panelOpen))
        root.openPanel();
      else if (root.panelOpen)
        closeTimer.restart();
    }
  }
}
