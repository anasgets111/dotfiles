pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Config
import qs.Services.SystemInfo

Item {
  id: layer

  // Keyboard focus tracking
  property int _keyboardFocusCount: 0
  property int barOffset: Theme.itemHeight
  property int margin: Theme.spacingMd
  readonly property bool needsKeyboardFocus: layer._keyboardFocusCount > 0
  readonly property real popupHeight: popupScroll.height
  readonly property real popupWidth: popupScroll.width
  readonly property real popupX: popupScroll.x
  readonly property real popupY: popupScroll.y

  function claimKeyboardFocus() {
    layer._keyboardFocusCount++;
  }

  function releaseKeyboardFocus() {
    layer._keyboardFocusCount = Math.max(0, layer._keyboardFocusCount - 1);
  }

  visible: NotificationService.visibleNotifications.length > 0

  onVisibleChanged: if (!visible)
    layer._keyboardFocusCount = 0

  ScrollView {
    id: popupScroll

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

      spacing: Theme.spacingSm

      Repeater {
        model: NotificationService.groupedPopups.slice(0, NotificationService.maxVisibleNotifications)

        NotificationCard {
          required property var modelData

          group: modelData
          groupScope: "popup"
          svc: NotificationService

          onInputFocusReleased: layer.releaseKeyboardFocus()
          onInputFocusRequested: layer.claimKeyboardFocus()
        }
      }
    }
  }
}
