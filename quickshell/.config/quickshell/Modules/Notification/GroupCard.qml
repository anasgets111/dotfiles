pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services.SystemInfo

Control {
  id: groupCard

  required property var group      // { id, title, children, expanded, updatedAt, appName }

  // Resolve wrappers from svc.all matching group.id
  readonly property var items: {
    const out = [];
    const ids = (groupCard.group?.children || []);
    const all = (groupCard.svc?.all || []);
    for (let i = 0; i < all.length; ++i) {
      const w = all[i];
      if (!w)
        continue;
      if (String(w.groupId || "") !== String(groupCard.group?.id || ""))
        continue;
      out.push(w);
    }
    // keep order by arrival or group.children order
    // children is newest-first by your _touchGroup; mirror that:
    out.sort((a, b) => ids.indexOf(String(a.id)) - ids.indexOf(String(b.id)));
    return out;
  }
  readonly property var latest: (items && items.length) ? items[0] : null
  // Provide access to service
  property var svc: NotificationService

  implicitWidth: 380
  padding: 10

  background: Rectangle {
    border.color: "#2a2a2a"
    border.width: 1
    color: "#282828"
    radius: 8
  }
  contentItem: ColumnLayout {
    spacing: 8

    // Header row: title, app, count, expand/collapse
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        Layout.fillWidth: true
        color: "white"
        elide: Text.ElideRight
        font.bold: true
        text: ((groupCard.group && groupCard.group.title) || "(Group)") + " — " + ((groupCard.group && groupCard.group.appName) || "")
      }

      Rectangle {
        Layout.preferredWidth: implicitWidth
        color: "#3a3a3a"
        implicitHeight: 20
        implicitWidth: Math.max(20, countText.implicitWidth + 10)
        radius: 10

        Text {
          id: countText

          anchors.centerIn: parent
          color: "white"
          font.pixelSize: 11
          text: String(groupCard.items.length)
        }
      }

      ToolButton {
        text: groupCard.group && groupCard.group.expanded ? "Collapse" : "Expand"
        visible: !!groupCard.group

        onClicked: {
          if (!groupCard.group)
            return;
          // Optimistic local toggle so UI updates immediately
          groupCard.group.expanded = !groupCard.group.expanded;
          if (groupCard.svc)
            groupCard.svc.toggleGroup(groupCard.group.id, groupCard.group.expanded);
        }
      }
    }

    // Collapsed: preview latest
    Item {
      implicitHeight: previewCard.implicitHeight
      implicitWidth: previewCard.implicitWidth
      visible: !!groupCard.group && !groupCard.group.expanded && !!groupCard.latest

      NotificationCard {
        id: previewCard

        wrapper: groupCard.latest

        onActionTriggered: id => groupCard.svc.executeAction(wrapper.id, id)
        onDismiss: groupCard.svc.dismissNotification(wrapper)
        onReplySubmitted: text => {
          const r = groupCard.svc.reply(wrapper.id, text);
          if (r?.ok)
            wrapper.popup = false;
        }
      }
    }

    // Expanded: list all items
    ColumnLayout {
      spacing: 6
      visible: !!groupCard.group && groupCard.group.expanded

      Repeater {
        model: groupCard.items

        delegate: NotificationCard {
          required property var modelData

          wrapper: modelData

          onActionTriggered: id => groupCard.svc.executeAction(modelData.id, id)
          onDismiss: groupCard.svc.dismissNotification(modelData)
          onReplySubmitted: text => {
            const r = groupCard.svc.reply(modelData.id, text);
            if (r?.ok)
              modelData.popup = false;
          }
        }
      }
    }
  }
}
