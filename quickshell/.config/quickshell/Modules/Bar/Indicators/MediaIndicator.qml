pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Services.Core
import qs.Services.UI

Item {
  id: root

  readonly property bool panelOpen: ShellUiState.isPanelOpen("media", root.screenName)
  property bool panelHovered: false
  required property string screenName

  function openPanel(): void {
    ShellUiState.openPanel("media", screenName, ShellUiState.anchorRectForItem(root), root);
  }

  Accessible.name: qsTr("Media controls")
  Accessible.role: Accessible.Button

  Accessible.onPressAction: root.openPanel()
  // Escape/outside-close can destroy the panel HoverHandler without a hovered=false edge.
  onPanelOpenChanged: if (!panelOpen)
    panelHovered = false
  Component.onDestruction: if (panelOpen)
    ShellUiState.closePanel()

  ShaderEffect {
    id: bars

    readonly property var _scratch: new Array(16).fill(0)
    property color barColor: MediaService.playing ? Theme.activeMedium : Theme.activeSubtle
    // Must stay `real`: the shader uniform is a float and Qt will not coerce an int.
    readonly property real barCount: CavaService.values.length
    property real gapPx: Theme.borderWidthThin
    // ponytail: Cava is configured for 256 bars; add another matrix if that ceiling changes.
    readonly property matrix4x4 levels0: bars.levelGroup(0)
    readonly property matrix4x4 levels1: bars.levelGroup(1)
    readonly property matrix4x4 levels2: bars.levelGroup(2)
    readonly property matrix4x4 levels3: bars.levelGroup(3)
    readonly property matrix4x4 levels4: bars.levelGroup(4)
    readonly property matrix4x4 levels5: bars.levelGroup(5)
    readonly property matrix4x4 levels6: bars.levelGroup(6)
    readonly property matrix4x4 levels7: bars.levelGroup(7)
    readonly property matrix4x4 levels8: bars.levelGroup(8)
    readonly property matrix4x4 levels9: bars.levelGroup(9)
    readonly property matrix4x4 levels10: bars.levelGroup(10)
    readonly property matrix4x4 levels11: bars.levelGroup(11)
    readonly property matrix4x4 levels12: bars.levelGroup(12)
    readonly property matrix4x4 levels13: bars.levelGroup(13)
    readonly property matrix4x4 levels14: bars.levelGroup(14)
    readonly property matrix4x4 levels15: bars.levelGroup(15)
    property real minHeightPx: Theme.borderWidthMedium
    property real pxHeight: height
    property real pxWidth: width

    function levelGroup(group: int): matrix4x4 {
      const values = CavaService.values;
      const offset = group * 16;
      for (let i = 0; i < 16; i++)
        bars._scratch[i] = values[offset + i] ?? 0;
      return Qt.matrix4x4(bars._scratch);
    }

    anchors.fill: parent
    anchors.margins: Theme.spacingXs
    fragmentShader: Qt.resolvedUrl("../../../Shaders/qsb/cava_bars.frag.qsb")

    Theme.ColorTransition on barColor {
    }
  }
  Timer {
    interval: Theme.animationSlow
    running: root.panelOpen && !trigger.hovered && !root.panelHovered

    onTriggered: ShellUiState.closePanel()
  }
  HoverHandler {
    id: trigger

    cursorShape: Qt.PointingHandCursor

    onHoveredChanged: if (hovered && (!ShellUiState.isAnyPanelOpen || root.panelOpen))
      root.openPanel()
  }
}
