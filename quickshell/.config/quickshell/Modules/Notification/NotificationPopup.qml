pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import qs.Services.SystemInfo

PanelWindow {
  id: layer

  required property var modelData
  property int margin: 12
  property int barOffset: 36

  color: "transparent"
  screen: layer.modelData
  visible: NotificationService.visibleNotifications.length > 0

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: popupColumn.interactionActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  WlrLayershell.exclusiveZone: -1

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  mask: Region {
    item: popupColumn
  }

  ScrollView {
    id: popupScroll
    anchors.top: parent.top
    anchors.topMargin: layer.margin + layer.barOffset
    anchors.right: parent.right
    anchors.rightMargin: layer.margin
    anchors.bottom: parent.bottom
    anchors.bottomMargin: layer.margin
    clip: true

    contentHeight: popupColumn.implicitHeight
    contentWidth: popupColumn.implicitWidth
    width: popupColumn.implicitWidth

    Column {
      id: popupColumn
      spacing: 8

      readonly property var svc: NotificationService
      property bool interactionActive: false

      readonly property var entries: (function () {
          const svc = popupColumn.svc;
          const groups = svc?.groupedPopups ?? [];
          const max = Math.max(1, Number(svc?.maxVisibleNotifications ?? 1));
          const out = [];
          for (let i = 0; i < groups.length && out.length < max; i++) {
            const g = groups[i];
            if (!g?.notifications?.length)
              continue;
            if (g.count <= 1) {
              out.push({
                kind: "single",
                wrapper: g.notifications[0]
              });
            } else {
              out.push({
                kind: "group",
                group: {
                  key: g.key,
                  appName: g.appName,
                  notifications: g.notifications,
                  latestNotification: g.latestNotification,
                  count: g.count,
                  hasInlineReply: g.hasInlineReply,
                  expanded: svc?.expandedGroups ? (svc.expandedGroups[g.key] || false) : false
                }
              });
            }
          }
          return out;
        })()

      Repeater {
        model: popupColumn.entries
        delegate: Item {
          id: del
          required property var modelData
          implicitWidth: col.implicitWidth
          implicitHeight: col.implicitHeight
          width: col.width

          Column {
            id: col

            TapHandler {
              acceptedButtons: Qt.LeftButton
              onTapped: {
                if (!popupColumn.interactionActive) {
                  popupColumn.interactionActive = true;
                }
              }
            }

            Loader {
              active: !!popupColumn.svc && !!del.modelData
              sourceComponent: NotificationCard {
                svc: popupColumn.svc
                wrapper: del.modelData.kind === "single" ? del.modelData.wrapper : null
                group: del.modelData.kind === "group" ? del.modelData.group : null
                onInputFocusRequested: popupColumn.interactionActive = true
              }
            }
          }
        }
      }
    }
  }

  Rectangle {
    id: dndBanner
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    color: Qt.rgba(0.95, 0.55, 0.10, 0.9)
    height: 28
    radius: 6
    width: txt.implicitWidth + 24
    visible: NotificationService ? NotificationService.isDndEnabled() : false

    Text {
      id: txt
      anchors.centerIn: parent
      color: "black"
      text: "Do Not Disturb Enabled"
    }
  }
}
