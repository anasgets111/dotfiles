pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config

/**
 * OPanel - Obelisk generic panel component
 *
 * A reusable panel container with positioning, animations, and dismiss logic.
 * Provides a consistent foundation for all context menus and dropdown panels.
 *
 * IMPORTANT: Each panel MUST have a unique panelNamespace to avoid Qt window conflicts.
 *
 * RECOMMENDED USAGE (Component + Loader pattern for independent instances):
 *   Component {
 *     id: myPanelComponent
 *     OPanel {
 *       panelNamespace: "obelisk-my-unique-panel"
 *       panelWidth: 350
 *       needsKeyboardFocus: true
 *
 *       ColumnLayout {
 *         // Your content here
 *       }
 *     }
 *   }
 *
 *   Loader {
 *     id: myPanelLoader
 *     active: false  // Load on demand
 *     sourceComponent: myPanelComponent
 *   }
 *
 * ALTERNATIVE (Direct instantiation - ensure unique namespace):
 *   OPanel {
 *     id: myPanel
 *     panelNamespace: "obelisk-my-unique-panel"  // REQUIRED: Must be unique!
 *     panelWidth: 350
 *     needsKeyboardFocus: true
 *
 *     ColumnLayout {
 *       // Your content here
 *     }
 *   }
 *
 * DON'T do this (creates shared/conflicting instances):
 *   OPanel { panelNamespace: "audio" }
 *   OPanel { panelNamespace: "audio" }  // ❌ Duplicate namespace!
 */
PanelWindow {
  id: root

  property int buttonHeight: 0
  property point buttonPosition: Qt.point(0, 0)
  property int buttonWidth: 0

  // Content container (for height calculation)
  default property alias content: contentContainer.data
  readonly property real contentHeight: contentContainer.implicitHeight || contentContainer.childrenRect.height
  readonly property real effectiveHeight: panelHeight > 0 ? panelHeight : Math.min(contentHeight, maxHeight)
  property bool isClosing: false

  // State
  property bool isOpen: false
  property int maxHeight: 600
  property bool needsKeyboardFocus: false
  property int panelHeight: 0  // Auto-calculated if 0
  required property string panelNamespace  // MUST be unique per panel instance

  // Configuration
  property int panelWidth: 350
  property int screenMargin: Theme.spacingSm
  property bool showInverseCorners: true

  // Position tracking
  property bool useButtonPosition: false

  signal panelClosed

  // Signals
  signal panelOpened

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

  function close() {
    if (!isOpen)
      return;
    isClosing = true;
    isOpen = false;
    hideTimer.start();
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

  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: -1
  WlrLayershell.keyboardFocus: needsKeyboardFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: panelNamespace

  // Window properties
  color: "transparent"
  visible: isOpen || isClosing

  anchors {
    bottom: true
    left: true
    right: true
    top: true
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

  // Keyboard shortcuts
  Shortcut {
    context: Qt.WindowShortcut
    enabled: root.isOpen && !root.isClosing
    sequences: ["Escape"]

    onActivated: root.close()
  }

  // Click outside to dismiss
  MouseArea {
    id: dismissArea

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    anchors.fill: parent
    enabled: root.isOpen && !root.isClosing
    hoverEnabled: false

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

      readonly property real hiddenY: -height
      readonly property real targetY: root.calculateY() - Theme.panelHeight

      bottomLeftRadius: Theme.itemRadius
      bottomRightRadius: Theme.itemRadius
      clip: true
      color: Theme.bgColor
      height: Math.max(1, root.effectiveHeight)
      radius: Theme.itemRadius

      // Only round bottom corners
      topLeftRadius: 0
      topRightRadius: 0
      width: root.panelWidth
      x: root.calculateX()
      y: root.isOpen ? targetY : hiddenY

      Behavior on height {
        NumberAnimation {
          duration: 300
          easing.type: Easing.OutCubic
        }
      }
      Behavior on y {
        PanelAnimation {
        }
      }

      // Content area
      Item {
        id: contentContainer

        anchors.fill: parent
        implicitHeight: childrenRect.height
        implicitWidth: childrenRect.width
      }
    }

    // Left inverse corner
    Loader {
      active: root.showInverseCorners && root.visible
      anchors.right: panelBackground.left
      anchors.rightMargin: -1
      y: panelBackground.y

      sourceComponent: RoundCorner {
        color: Theme.bgColor
        orientation: 1 // TOP_RIGHT
        radius: Theme.panelRadius * 3
      }
    }

    // Right inverse corner
    Loader {
      active: root.showInverseCorners && root.visible
      anchors.left: panelBackground.right
      anchors.leftMargin: -1
      y: panelBackground.y

      sourceComponent: RoundCorner {
        color: Theme.bgColor
        orientation: 0 // TOP_LEFT
        radius: Theme.panelRadius * 3
      }
    }
  }

  // Animation component
  component PanelAnimation: NumberAnimation {
    duration: Theme.animationDuration
    easing.type: Easing.OutQuad
  }
}

/*
 * BEST PRACTICES FOR PANEL INSTANTIATION
 * ========================================
 *
 * While direct instantiation works with unique namespaces, the Component + Loader
 * pattern is recommended for better performance and guaranteed instance isolation:
 *
 * Component {
 *   id: myPanelComponent
 *   OPanel {
 *     panelNamespace: "obelisk-my-panel"
 *     panelWidth: 350
 *     // ... content
 *   }
 * }
 *
 * Loader {
 *   id: myPanelLoader
 *   active: false
 *   sourceComponent: myPanelComponent
 *   onLoaded: item.openAtItem(button, mouseX, mouseY)
 * }
 *
 * // To open:
 * myPanelLoader.active = true
 *
 * // To close (in panel's onPanelClosed handler):
 * myPanelLoader.active = false
 *
 * Benefits:
 * - Lazy loading: Panel is only created when needed
 * - Complete isolation: Each Loader creates independent instances
 * - Better memory management: Panel is destroyed when Loader.active = false
 * - No Qt window conflicts: Guaranteed unique PanelWindow instances
 */
