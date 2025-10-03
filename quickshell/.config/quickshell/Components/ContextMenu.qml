pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Components
import qs.Modules.Bar

/**
 * ContextMenu - Generic context menu component
 *
 * A reusable context menu that can display different types of items:
 * - Action items (clickable with icons)
 * - Text input items (for passwords, PINs, text entry)
 * - Future: toggles, separators, headers
 *
 * Properties:
 *   - model: Array of fixed (always visible) menu items
 *   - scrollableModel: Array of scrollable menu items
 *   - maxScrollableItems: Maximum items before scrolling (default 7)
 *   - menuWidth: Default menu width (default 300)
 *   - textInputMenuWidth: Width when text input is present (default 400)
 *
 * Signals:
 *   - triggered(action, data): Emitted when an item is activated
 *   - menuClosed(): Emitted when menu closes
 */
PanelWindow {
  id: root

  property var model: []
  property var scrollableModel: []
  property int maxScrollableItems: 7
  property real itemHeight: Theme.itemHeight
  property real itemPadding: 8
  property int menuWidth: 350
  property int textInputMenuWidth: 350
  property int screenMargin: 8

  property bool useButtonPosition: false
  property point buttonPosition: Qt.point(0, 0)
  property int buttonWidth: 0
  property int buttonHeight: 0

  property bool isClosing: false
  property bool isOpen: false

  // Calculate if keyboard focus is needed based on item types
  readonly property bool needsKeyboardFocus: {
    const hasTextInput = model.some(item => item?.itemType === "textInput") || scrollableModel.some(item => item?.itemType === "textInput");
    return hasTextInput;
  }

  // Calculate effective menu width based on item types
  readonly property int effectiveMenuWidth: needsKeyboardFocus ? textInputMenuWidth : menuWidth

  signal triggered(string action, var data)
  signal menuClosed

  color: "transparent"
  visible: isOpen || isClosing

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "context-menu"
  WlrLayershell.keyboardFocus: needsKeyboardFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.exclusiveZone: -1

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  component MenuAnimation: NumberAnimation {
    duration: Theme.animationDuration
    easing.type: Easing.OutQuad
  }

  Timer {
    id: hideTimer
    interval: Theme.animationDuration
    repeat: false
    onTriggered: {
      root.closeCompleted();
    }
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

  function open() {
    if (isClosing) {
      hideTimer.stop();
      isClosing = false;
    }
    useButtonPosition = true;
    isOpen = true;
  }

  function close() {
    if (!isOpen)
      return;
    isClosing = true;
    isOpen = false;
    hideTimer.start();
  }

  function closeCompleted() {
    isClosing = false;
    useButtonPosition = false;
    menuClosed();
  }

  function calculateX() {
    if (!useButtonPosition)
      return 0;
    const centerX = buttonPosition.x + buttonWidth / 2 - menuBackground.width / 2;
    const maxX = root.width - menuBackground.width - screenMargin;
    return Math.max(screenMargin, Math.min(centerX, maxX));
  }

  function calculateY() {
    if (!useButtonPosition)
      return Math.round((root.height - menuBackground.height) / 2);
    const belowY = Theme.panelHeight;
    const aboveY = buttonPosition.y - menuBackground.height - 4;
    const maxY = root.height - menuBackground.height - 8;

    if (belowY + menuBackground.height <= root.height - 8)
      return Math.round(belowY);
    if (aboveY >= 8)
      return Math.round(aboveY);
    return Math.round(Math.min(belowY, maxY));
  }

  Shortcut {
    sequences: ["Escape"]
    enabled: root.isOpen && !root.isClosing
    onActivated: root.close()
    context: Qt.WindowShortcut
  }

  MouseArea {
    id: dismissArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: false
    enabled: root.isOpen && !root.isClosing

    onPressed: function (mouse) {
      if (!menuBackground)
        return;
      const local = menuBackground.mapFromItem(dismissArea, mouse.x, mouse.y);
      const inside = local.x >= 0 && local.y >= 0 && local.x <= menuBackground.width && local.y <= menuBackground.height;

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
      id: menuBackground

      readonly property real fixedHeight: fixedList.contentHeight + (root.scrollableModel.length > 0 ? 4 : 0)
      readonly property real scrollableHeight: Math.min(scrollableList.contentHeight, root.maxScrollableItems * root.itemHeight + (root.maxScrollableItems - 1) * 4)
      readonly property real totalContentHeight: fixedHeight + scrollableHeight + root.itemPadding * 2
      readonly property real targetY: root.calculateY() - Theme.panelHeight
      readonly property real hiddenY: -totalContentHeight

      width: root.effectiveMenuWidth
      height: totalContentHeight

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
        MenuAnimation {}
      }

      // Clip content during animation
      clip: true

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.itemPadding
        spacing: 4

        // Fixed items (always visible, not scrollable)
        ListView {
          id: fixedList
          Layout.fillWidth: true
          Layout.preferredHeight: contentHeight
          spacing: 4
          interactive: false
          clip: true
          model: root.model

          delegate: MenuItem {
            itemHeight: root.itemHeight
            itemPadding: root.itemPadding
            parentListView: fixedList

            onTriggered: (action, data) => {
              root.triggered(action, data);
              // Close menu after action (unless it's a textInput that will be shown)
              if (modelData.itemType !== "textInput") {
                root.close();
              }
            }
          }
        }

        // Scrollable section (for networks, devices, etc.)
        ListView {
          id: scrollableList
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(contentHeight, root.maxScrollableItems * root.itemHeight + (root.maxScrollableItems - 1) * 4)
          visible: root.scrollableModel.length > 0
          spacing: 4
          interactive: contentHeight > height
          clip: true
          model: root.scrollableModel

          ScrollBar.vertical: ScrollBar {
            policy: scrollableList.contentHeight > scrollableList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 8
          }

          delegate: MenuItem {
            itemHeight: root.itemHeight
            itemPadding: root.itemPadding
            parentListView: scrollableList

            onTriggered: (action, data) => {
              root.triggered(action, data);
              // Close menu logic based on item type and action
              const shouldClose = modelData.itemType !== "textInput" && !action.startsWith("connect-") || (action.startsWith("connect-") && (modelData.connected || modelData.isSaved));
              if (shouldClose) {
                root.close();
              }
            }
          }
        }
      }
    }

    // Left inverse corner (same Y as menu, touches bar above)
    RoundCorner {
      anchors.right: menuBackground.left
      anchors.rightMargin: -1
      y: menuBackground.y
      color: Theme.bgColor
      orientation: 1 // TOP_RIGHT - creates inverse corner
      radius: Theme.panelRadius * 3
    }

    // Right inverse corner (same Y as menu, touches bar above)
    RoundCorner {
      anchors.left: menuBackground.right
      anchors.leftMargin: -1
      y: menuBackground.y
      color: Theme.bgColor
      orientation: 0 // TOP_LEFT - creates inverse corner
      radius: Theme.panelRadius * 3
    }
  }
}
