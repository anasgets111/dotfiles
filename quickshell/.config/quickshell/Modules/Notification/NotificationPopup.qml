pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import qs.Config
import qs.Services.SystemInfo

PanelWindow {
  id: root

  // Keyboard focus tracking
  property int _keyboardFocusCount: 0
  property int barOffset: Theme.itemHeight
  property int margin: Theme.spacingMd
  required property var modelData

  function claimKeyboardFocus() {
    root._keyboardFocusCount++;
  }

  function releaseKeyboardFocus() {
    root._keyboardFocusCount = Math.max(0, root._keyboardFocusCount - 1);
  }

  WlrLayershell.exclusiveZone: -1
  WlrLayershell.keyboardFocus: root._keyboardFocusCount > 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "obelisk-notification-popup-" + (screen?.name || "unknown")
  color: "transparent"
  screen: root.modelData
  surfaceFormat.opaque: false
  visible: NotificationService.visibleNotifications.length > 0

  mask: Region {
    item: popupColumn
  }

  onVisibleChanged: if (!visible)
    root._keyboardFocusCount = 0

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }

  ScrollView {
    id: popupScroll

    clip: true
    contentHeight: popupColumn.implicitHeight
    contentWidth: popupColumn.implicitWidth
    width: popupColumn.implicitWidth

    anchors {
      bottom: parent.bottom
      bottomMargin: root.margin
      right: parent.right
      rightMargin: root.margin
      top: parent.top
      topMargin: root.margin + root.barOffset
    }

    Column {
      id: popupColumn

      spacing: Theme.spacingSm

      Repeater {
        model: NotificationService.groupedPopups.slice(0, NotificationService.maxVisibleNotifications)

        NotificationCard {
          required property var modelData

          group: modelData
          groupScope: "popup"
          svc: NotificationService

          onInputFocusReleased: root.releaseKeyboardFocus()
          onInputFocusRequested: root.claimKeyboardFocus()
        }
      }
    }
  }
}
