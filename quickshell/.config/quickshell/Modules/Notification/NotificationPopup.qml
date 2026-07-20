pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Components
import qs.Config
import qs.Services.SystemInfo

OPopup {
  id: root

  property var _cardRegions: []
  property int barOffset: Theme.itemHeight
  property int margin: Theme.spacingMd

  function rebuildBlurRegions() {
    for (const region of root._cardRegions)
      region.destroy();
    const regions = [];
    for (let i = 0; i < cardRepeater.count; i++) {
      const card = cardRepeater.itemAt(i);
      if (card)
        regions.push(cardBlurComponent.createObject(popupBlurRegion, {
          card
        }));
    }
    root._cardRegions = regions;
    popupBlurRegion.regions = regions;
  }

  blurRegion: Region {
    id: popupBlurRegion

  }
  maskItem: popupColumn
  popupNamespace: "obelisk-notification-popup"
  visible: NotificationService.visibleNotifications.length > 0

  Component {
    id: cardBlurComponent

    Region {
      id: cardRegion

      required property NotificationCard card

      item: cardRegion.card

      regions: [
        Region {
          intersection: Intersection.Intersect
          item: cardRegion.card?.blurInsetItem ?? null
          radius: Theme.panelRadius
        },
        Region {
          intersection: Intersection.Intersect
          item: popupScroll
        }
      ]
    }
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
