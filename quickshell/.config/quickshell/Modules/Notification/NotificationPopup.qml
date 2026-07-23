pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Components
import qs.Config
import qs.Services.SystemInfo

OPopup {
  id: root

  property int barOffset: Theme.itemHeight
  property int margin: Theme.spacingMd

  function rebuildBlurRegions(): void {
    root.blurRegion.regions = Array.from({
      length: cardRepeater.count
    }, (_, i) => (cardRepeater.itemAt(i) as NotificationCard)?.popupBlurRegion).filter(Boolean);
  }

  maskItem: popupColumn
  popupNamespace: "obelisk-notification-popup"
  visible: NotificationService.visibleNotifications.length > 0

  blurRegion: Region {
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
        id: cardRepeater

        model: NotificationService.groupedPopups.slice(0, NotificationService.maxVisibleNotifications)

        onItemAdded: Qt.callLater(root.rebuildBlurRegions)
        onItemRemoved: Qt.callLater(root.rebuildBlurRegions)

        NotificationCard {
          id: notificationCard

          required property var modelData

          group: modelData
          groupScope: "popup"
          svc: NotificationService

          popupBlurRegion: Region {
            item: notificationCard

            regions: [
              Region {
                intersection: Intersection.Intersect
                item: blurInset
                radius: Theme.panelRadius
              },
              Region {
                intersection: Intersection.Intersect
                item: popupScroll
              }
            ]
          }

          onInputFocusReleased: root.releaseKeyboardFocus()
          onInputFocusRequested: root.claimKeyboardFocus()

          Item {
            id: blurInset

            anchors.fill: parent
            anchors.margins: 2
          }
        }
      }
    }
  }
}
