pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Components
import qs.Config
import qs.Services.SystemInfo

OPopup {
  id: root

  property int barOffset: Theme.itemHeight
  property int margin: Theme.spacingMd

  maskItem: popupColumn
  popupNamespace: "obelisk-notification-popup"
  visible: NotificationService.visibleNotifications.length > 0

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
