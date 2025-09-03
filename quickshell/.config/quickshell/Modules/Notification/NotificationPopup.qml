pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import qs.Services.SystemInfo
import QtQuick.Window

PanelWindow {
  id: layer

  property int barOffset: 36
  property int margin: 12
  required property var modelData

  WlrLayershell.exclusiveZone: -1
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
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

  // property int shadowPad: 16
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

      // Build entries from currently visible wrappers, honoring svc.maxVisible.
      // Coalesce by group so you get at most one entry per group id.
      property var entries: (function () {
          const svc = popupColumn.svc;
          const max = Math.max(1, Number(svc?.maxVisible || 1));
          const result = [];
          const seenGroups = new Set();
          const vis = svc?.visible || [];
          // Iterate visible wrappers in order, collect up to 'max' distinct entries
          for (let i = 0; i < vis.length && result.length < max; ++i) {
            const w = vis[i];
            if (!w)
              continue;
            const gid = String(w.groupId || "");
            if (gid) {
              if (seenGroups.has(gid))
                continue;
              const g = (svc?.groupsMap && svc.groupsMap[gid]) || null;
              if (g) {
                result.push({
                  kind: "group",
                  group: g
                });
                seenGroups.add(gid);
              } else {
                result.push({
                  kind: "single",
                  wrapper: w
                });
              }
            } else {
              result.push({
                kind: "single",
                wrapper: w
              });
            }
          }
          // If grouping compressed entries below max, try to fill from the rest
          for (let i = 0; i < vis.length && result.length < max; ++i) {
            const w = vis[i];
            if (!w)
              continue;
            const gid = String(w.groupId || "");
            if (gid) {
              if (!seenGroups.has(gid)) {
                const g = (svc?.groupsMap && svc.groupsMap[gid]) || null;
                if (g) {
                  result.push({
                    kind: "group",
                    group: g
                  });
                  seenGroups.add(gid);
                }
              }
            } else {
              // ensure we don't duplicate singles already included
              if (!result.some(e => e.kind === "single" && e.wrapper === w))
                result.push({
                  kind: "single",
                  wrapper: w
                });
            }
          }
          return result;
        })()
      // local handle to the service to avoid unqualified access inside delegates
      readonly property var svc: NotificationService

      spacing: 8

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

            // Only create cards when inputs are present to avoid undefined access
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
