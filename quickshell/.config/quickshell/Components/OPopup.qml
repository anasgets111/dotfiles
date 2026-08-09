pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: root

  property int _keyboardFocusCount: 0
  property Region blurRegion: null
  // null keeps the layer-shell surface click-through during card dismissal.
  property Item maskItem: null
  required property var modelData
  property string popupNamespace: ""

  function claimKeyboardFocus(): void {
    root._keyboardFocusCount++;
  }
  function releaseKeyboardFocus(): void {
    root._keyboardFocusCount = Math.max(0, root._keyboardFocusCount - 1);
  }

  BackgroundEffect.blurRegion: root.blurRegion
  WlrLayershell.exclusiveZone: -1
  WlrLayershell.keyboardFocus: root._keyboardFocusCount > 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: root.popupNamespace + "-" + (root.screen?.name || "unknown")
  color: "transparent"
  screen: root.modelData
  surfaceFormat.opaque: false

  mask: Region {
    item: root.maskItem
  }

  onVisibleChanged: if (!visible)
    root._keyboardFocusCount = 0

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }
}
