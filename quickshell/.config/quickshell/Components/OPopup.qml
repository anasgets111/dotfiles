pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Popup Surface — the Overlay-layer window a Popup's Card is drawn onto. Owns the
// shared layer-shell scaffold (Overlay layer, negative exclusive zone, transparent
// surface, mask region, keyboard-focus policy) so each Popup carries only its Card.
// The modal PolkitDialog is a Dialog, not a Popup, and does not use this.
PanelWindow {
  id: root

  // Exclusive keyboard focus is held while any caller has claimed it; informative
  // popups simply never claim, so they rest at None.
  property int keyboardFocusCount: 0
  // Geometry that forms the input/mask region — the Card. Leave null to make the
  // surface fully click-through (e.g. while a Card fades out).
  property Item maskItem: null

  // The screen this surface renders on (passed through to PanelWindow.screen).
  required property var modelData
  // Base layer-shell namespace; the screen name is appended per surface.
  property string popupNamespace: ""

  function claimKeyboardFocus(): void {
    root.keyboardFocusCount++;
  }
  function releaseKeyboardFocus(): void {
    root.keyboardFocusCount = Math.max(0, root.keyboardFocusCount - 1);
  }

  WlrLayershell.exclusiveZone: -1
  WlrLayershell.keyboardFocus: root.keyboardFocusCount > 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: root.popupNamespace + "-" + (root.screen?.name || "unknown")
  color: "transparent"
  screen: root.modelData
  surfaceFormat.opaque: false

  mask: Region {
    item: root.maskItem
  }

  onVisibleChanged: if (!visible)
    root.keyboardFocusCount = 0

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }
}
