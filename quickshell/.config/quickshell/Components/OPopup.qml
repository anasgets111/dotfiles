pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: root

  property Region blurRegion: null
  property int keyboardFocusCount: 0
  // null keeps the layer-shell surface click-through during card dismissal.
  property Item maskItem: null
  required property var modelData
  property string popupNamespace: ""

  function claimKeyboardFocus(): void {
    root.keyboardFocusCount++;
  }
  function releaseKeyboardFocus(): void {
    root.keyboardFocusCount = Math.max(0, root.keyboardFocusCount - 1);
  }

  BackgroundEffect.blurRegion: root.blurRegion
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
