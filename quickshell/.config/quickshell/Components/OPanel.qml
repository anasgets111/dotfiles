pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Modules.Bar

/**
 * OPanel - Obelisk generic panel component
 *
 * A reusable panel container with positioning, animations, and dismiss logic.
 * Provides a consistent foundation for all context menus and dropdown panels.
 *
 * Usage:
 *   OPanel {
 *     id: myPanel
 *     panelWidth: 350
 *     needsKeyboardFocus: true
 *
 *     ColumnLayout {
 *       // Your content here
 *     }
 *   }
 */
PanelWindow {
  id: root

  // Configuration
  property int panelWidth: 350
  property int panelHeight: 0  // Auto-calculated if 0
  property int maxHeight: 600
  property int screenMargin: 8
  property string panelNamespace: "obelisk-panel"

  // Position tracking
  property bool useButtonPosition: false
  property point buttonPosition: Qt.point(0, 0)
  property int buttonWidth: 0
  property int buttonHeight: 0

  // State
  property bool isOpen: false
  property bool isClosing: false
  property bool needsKeyboardFocus: false
  property bool showInverseCorners: true

  // Content container (for height calculation)
  default property alias content: contentContainer.data
  readonly property real contentHeight: contentContainer.implicitHeight || contentContainer.childrenRect.height
  readonly property real effectiveHeight: panelHeight > 0 ? panelHeight : Math.min(contentHeight, maxHeight)

  // Signals
  signal panelOpened
  signal panelClosed

  // Window properties
  color: "transparent"
  visible: isOpen || isClosing

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: panelNamespace
  WlrLayershell.keyboardFocus: needsKeyboardFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.exclusiveZone: -1

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  // Animation component
  component PanelAnimation: NumberAnimation {
    duration: Theme.animationDuration
    easing.type: Easing.OutQuad
  }

  // Auto-hide timer
  Timer {
    id: hideTimer
    interval: Theme.animationDuration
    repeat: false
    onTriggered: {
      root.isClosing = false;
      root.panelClosed();
    }
  }

  // Position calculation
  function calculateX() {
    if (!useButtonPosition)
      return 0;
    const cornerInset = root.showInverseCorners ? Theme.panelRadius * 3 : 0;
    const centerX = buttonPosition.x + buttonWidth / 2 - panelBackground.width / 2;
    const minX = screenMargin + cornerInset;
    const maxX = root.width - panelBackground.width - screenMargin - cornerInset;
    return Math.max(minX, Math.min(centerX, maxX));
  }

  function calculateY() {
    if (!useButtonPosition)
      return Math.round((root.height - panelBackground.height) / 2);
    const belowY = Theme.panelHeight;
    const aboveY = buttonPosition.y - panelBackground.height - 4;
    const maxY = root.height - panelBackground.height - 8;

    if (belowY + panelBackground.height <= root.height - 8)
      return Math.round(belowY);
    if (aboveY >= 8)
      return Math.round(aboveY);
    return Math.round(Math.min(belowY, maxY));
  }

  // Public API
  function open() {
    if (isClosing) {
      hideTimer.stop();
      isClosing = false;
    }
    useButtonPosition = true;
    isOpen = true;
    panelOpened();
  }

  function close() {
    if (!isOpen)
      return;
    isClosing = true;
    isOpen = false;
    hideTimer.start();
  }

  function openAt(x, y) {
    buttonPosition = Qt.point(x, y);
    buttonWidth = 0;
    buttonHeight = 0;
    open();
  }

  function openAtItem(item, mouseX, mouseY) {
    if (!item)
      return;
    buttonPosition = item.mapToItem(null, mouseX || 0, mouseY || 0);
    buttonWidth = item.width;
    buttonHeight = item.height;
    open();
  }

  // Keyboard shortcuts
  Shortcut {
    sequences: ["Escape"]
    enabled: root.isOpen && !root.isClosing
    onActivated: root.close()
    context: Qt.WindowShortcut
  }

  // Click outside to dismiss
  MouseArea {
    id: dismissArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: false
    enabled: root.isOpen && !root.isClosing

    onPressed: function (mouse) {
      if (!panelBackground)
        return;
      const local = panelBackground.mapFromItem(dismissArea, mouse.x, mouse.y);
      const inside = local.x >= 0 && local.y >= 0 && local.x <= panelBackground.width && local.y <= panelBackground.height;

      if (inside) {
        mouse.accepted = false;
        return;
      }

      root.close();
    }
  }

  // Clip container to prevent menu from appearing above the bar
  Item {
    id: clipContainer
    anchors.fill: parent
    anchors.topMargin: Theme.panelHeight
    clip: true

    Rectangle {
      id: panelBackground

      readonly property real targetY: root.calculateY() - Theme.panelHeight
      readonly property real hiddenY: -height

      width: root.panelWidth
      height: Math.max(1, root.effectiveHeight)

      color: Theme.bgColor
      radius: Theme.itemRadius

      // Only round bottom corners
      topLeftRadius: 0
      topRightRadius: 0
      bottomLeftRadius: Theme.itemRadius
      bottomRightRadius: Theme.itemRadius

      x: root.calculateX()
      y: root.isOpen ? targetY : hiddenY

      Behavior on y {
        PanelAnimation {}
      }

      clip: true

      // Content area
      Item {
        id: contentContainer
        anchors.fill: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
      }
    }

    // Left inverse corner
    RoundCorner {
      visible: root.showInverseCorners
      anchors.right: panelBackground.left
      anchors.rightMargin: -1
      y: panelBackground.y
      color: Theme.bgColor
      orientation: 1 // TOP_RIGHT
      radius: Theme.panelRadius * 3
    }

    // Right inverse corner
    RoundCorner {
      visible: root.showInverseCorners
      anchors.left: panelBackground.right
      anchors.leftMargin: -1
      y: panelBackground.y
      color: Theme.bgColor
      orientation: 0 // TOP_LEFT
      radius: Theme.panelRadius * 3
    }
  }
}
