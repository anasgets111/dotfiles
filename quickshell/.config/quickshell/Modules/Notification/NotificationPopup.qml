pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import qs.Services.SystemInfo

PanelWindow {
  id: layer

  // Keyboard focus tracking
  property int _keyboardFocusCount: 0
  property int barOffset: 36
  property int margin: 12
  required property var modelData

  function claimKeyboardFocus() {
    layer._keyboardFocusCount++;
  }

  function releaseKeyboardFocus() {
    layer._keyboardFocusCount = Math.max(0, layer._keyboardFocusCount - 1);
  }

  WlrLayershell.exclusiveZone: -1
  WlrLayershell.keyboardFocus: layer._keyboardFocusCount > 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Overlay
  color: "transparent"
  screen: layer.modelData
  visible: NotificationService.visibleNotifications.length > 0

  mask: Region {
    item: popupColumn
  }

  onVisibleChanged: if (!visible)
    layer._keyboardFocusCount = 0

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }

  ScrollView {
    clip: true
    contentHeight: popupColumn.implicitHeight
    contentWidth: popupColumn.implicitWidth
    width: popupColumn.implicitWidth

    anchors {
      bottom: parent.bottom
      bottomMargin: layer.margin
      right: parent.right
      rightMargin: layer.margin
      top: parent.top
      topMargin: layer.margin + layer.barOffset
    }

    Column {
      id: popupColumn

      spacing: 8

      Repeater {
        model: NotificationService.groupedPopups.slice(0, NotificationService.maxVisibleNotifications)

        NotificationCard {
          required property var modelData

          group: modelData
          svc: NotificationService

          onInputFocusReleased: layer.releaseKeyboardFocus()
          onInputFocusRequested: layer.claimKeyboardFocus()
        }
      }
    }
  }
}
