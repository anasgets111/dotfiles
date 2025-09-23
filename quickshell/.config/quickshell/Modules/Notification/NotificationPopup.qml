pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import qs.Components
import qs.Services.SystemInfo
import QtQuick.Window

PanelWindow {
  id: layer

  property int barOffset: 36
  property int margin: 12
  required property var modelData

  WlrLayershell.exclusiveZone: -1
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Overlay
  color: "transparent"
  screen: layer.modelData
  visible: NotificationService.visibleNotifications.length > 0

  mask: Region {
    item: popupColumn
  }

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }

  // Scrollable stack to avoid growing off-screen; still stacks vertically
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
    // Size viewport to content width
    width: popupColumn.implicitWidth

    Column {
      id: popupColumn
      spacing: 8

      // Local handle to the service
      readonly property var svc: NotificationService
      // Whether user explicitly interacted (for keyboard focus)
      property bool interactionActive: false

      // Entries from grouped popups, up to maxVisible.
      // Coalesce: if group.count == 1, show as single; else show a group entry.
      property var entries: {
        const svc = popupColumn.svc;
        const groups = (svc && svc.groupedPopups) ? svc.groupedPopups : [];
        const max = Math.max(1, Number((svc && svc.maxVisibleNotifications) ? svc.maxVisibleNotifications : 1));
        const out = [];
        for (let i = 0; i < groups.length && out.length < max; i++) {
          const g = groups[i];
          if (!g || !g.notifications || g.notifications.length === 0)
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
                expanded: svc && svc.expandedGroups ? (svc.expandedGroups[g.key] || false) : false
              }
            });
          }
        }
        return out;
      }

      Repeater {
        model: popupColumn.entries

        delegate: Item {
          id: del

          required property var modelData

          implicitHeight: col.implicitHeight
          implicitWidth: col.implicitWidth
          width: col.width

          Column {
            id: col

            // Enable OnDemand focus on first click to allow replies/interactions
            TapHandler {
              acceptedButtons: Qt.LeftButton
              onTapped: {
                if (!popupColumn.interactionActive) {
                  popupColumn.interactionActive = true;
                  if (layer.WlrLayershell) {
                    layer.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand;
                  }
                }
              }
            }

            Loader {
              active: del.modelData.kind === "single" && !!del.modelData.wrapper
              sourceComponent: NotificationCard {
                wrapper: del.modelData.wrapper

                onActionTriggered: id => popupColumn.svc && popupColumn.svc.executeAction(del.modelData.wrapper, id)
                // Prefer extended signal with action object when available
                onActionTriggeredEx: (id, actionObj) => popupColumn.svc && popupColumn.svc.executeAction(del.modelData.wrapper, id, actionObj)
                onDismiss: popupColumn.svc.dismissNotification(del.modelData.wrapper)
                // Reply omitted in refactor; add back if notification.replySupported etc. is implemented
                // e.g., onReplySubmitted: text => { del.modelData.wrapper.notification.sendReply(text); popupColumn.svc.dismissNotification(del.modelData.wrapper); }
              }
            }

            Loader {
              active: del.modelData.kind === "group" && !!del.modelData.group
              sourceComponent: GroupCard {
                group: del.modelData.group
                svc: popupColumn.svc
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
    visible: (typeof OSDService !== "undefined" && OSDService.doNotDisturb) ? true : false  // Guarded access
    width: txt.implicitWidth + 24

    Text {
      id: txt
      anchors.centerIn: parent
      color: "black"
      text: "Do Not Disturb Enabled"  // Simplified; no behavior distinction in new API
    }
  }
}
