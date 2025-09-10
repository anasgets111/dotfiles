pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import qs.Services.SystemInfo
import QtQuick.Window
import qs.Config

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
  visible: NotificationService.visible.length > 0

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

      // Entries from visible wrappers, coalescing by group, up to maxVisible
      property var entries: (function () {
          const svc = popupColumn.svc;
          const vis = svc?.visible || [];
          const max = Math.max(1, Number(svc?.maxVisible || 1));
          const counts = {};
          for (let i = 0; i < vis.length; i++) {
            const gid = String(vis[i]?.groupId || "");
            counts[gid] = (counts[gid] || 0) + 1;
          }
          const seen = new Set();
          const out = [];
          for (let i = 0; i < vis.length && out.length < max; i++) {
            const w = vis[i];
            if (!w)
              continue;
            const gid = String(w.groupId || "");
            if (gid) {
              if (seen.has(gid))
                continue;
              seen.add(gid);
              const g = svc?.groupsMap ? svc.groupsMap[gid] : null;
              out.push((counts[gid] || 0) >= 2 && g ? {
                kind: "group",
                group: g
              } : {
                kind: "single",
                wrapper: w
              });
            } else {
              out.push({
                kind: "single",
                wrapper: w
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

          implicitHeight: col.implicitHeight
          implicitWidth: col.implicitWidth
          width: col.width

          Column {
            id: col

            // Enable OnDemand focus on first click to allow replies
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

                onActionTriggered: id => popupColumn.svc.executeAction(wrapper.id, id)
                onDismiss: popupColumn.svc.dismissNotification(wrapper)
                onReplySubmitted: text => {
                  const r = popupColumn.svc.reply(wrapper.id, text);
                  if (r?.ok)
                    wrapper.popup = false;
                }
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
    visible: NotificationService.dndPolicy?.enabled
    width: txt.implicitWidth + 24

    Text {
      id: txt
      anchors.centerIn: parent
      color: "black"
      text: "Do Not Disturb: " + (NotificationService.dndPolicy?.behavior === "suppress" ? "Suppress" : "Queue")
    }
  }
}
