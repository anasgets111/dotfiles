pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import qs.Services.SystemInfo

PanelWindow {
  id: layer

  property int barOffset: 36
  property int margin: 12
  required property var modelData

  WlrLayershell.exclusiveZone: -1
  WlrLayershell.keyboardFocus: popupColumn.interactionActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Overlay
  color: "transparent"
  screen: layer.modelData
  visible: NotificationService.visibleNotifications.length > 0

  mask: Region {
    item: popupColumn
  }

  onVisibleChanged: if (!visible)
    popupColumn.resetKeyboardFocus()

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }

  ScrollView {
    id: popupScroll

    anchors.bottom: parent.bottom
    anchors.bottomMargin: layer.margin
    anchors.right: parent.right
    anchors.rightMargin: layer.margin
    anchors.top: parent.top
    anchors.topMargin: layer.margin + layer.barOffset
    clip: true
    contentHeight: popupColumn.implicitHeight
    contentWidth: popupColumn.implicitWidth
    width: popupColumn.implicitWidth

    Column {
      id: popupColumn

      readonly property var entries: layer.visible ? computeEntries() : []
      property int focusCaptureCount: 0
      property bool interactionActive: false
      readonly property var svc: NotificationService

      function claimKeyboardFocus() {
        popupColumn.focusCaptureCount = Math.max(0, popupColumn.focusCaptureCount) + 1;
        popupColumn.interactionActive = true;
      }

      function computeEntries() {
        const svc = popupColumn.svc;
        const groups = svc?.groupedPopups ?? [];
        const max = Math.max(1, Number(svc?.maxVisibleNotifications ?? 1));
        return groups.slice(0, max);
      }

      function releaseKeyboardFocus() {
        popupColumn.focusCaptureCount = Math.max(0, popupColumn.focusCaptureCount - 1);
        if (popupColumn.focusCaptureCount <= 0) {
          popupColumn.focusCaptureCount = 0;
          popupColumn.interactionActive = false;
        }
      }

      function resetKeyboardFocus() {
        popupColumn.focusCaptureCount = 0;
        popupColumn.interactionActive = false;
      }

      spacing: 8

      Repeater {
        id: notifRepeater

        model: popupColumn.entries

        delegate: Item {
          id: del

          required property var modelData

          implicitHeight: col.implicitHeight
          implicitWidth: col.implicitWidth
          width: col.width

          Column {
            id: col

            Loader {
              id: cardLoader

              active: !!popupColumn.svc && !!del.modelData
              asynchronous: false

              sourceComponent: Component {
                NotificationCard {
                  group: del.modelData
                  svc: popupColumn.svc

                  onInputFocusReleased: popupColumn.releaseKeyboardFocus()
                  onInputFocusRequested: popupColumn.claimKeyboardFocus()
                }
              }
            }
          }
        }
      }
    }
  }
}
