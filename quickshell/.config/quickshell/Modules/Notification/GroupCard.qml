pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services.SystemInfo
import Qt5Compat.GraphicalEffects

Control {
  id: groupCard

  required property var group // { id, title, children, expanded, updatedAt, appName }
  // Provide access to service
  property var svc: NotificationService

  implicitWidth: 380
  padding: 10

  // Visible wrappers in this group (sorted by group.children order)
  readonly property var items: {
    const svc = groupCard.svc;
    const gid = String(groupCard.group?.id || "");
    const ids = groupCard.group?.children || [];
    return (svc?.visible || [])
      .filter(w => String(w?.groupId || "") === gid)
      .sort(
        (a, b) =>
          ids.indexOf(String(a?.id)) - ids.indexOf(String(b?.id))
      );
  }
  readonly property var latest: items && items.length ? items[0] : null
  // Local reactive expanded state
  property bool expanded:
    (groupCard.group && groupCard.group.expanded) === true

  readonly property int maxShow:
    Math.max(1, Number(groupCard.svc?.maxVisible || 1))
  readonly property var limitedItems:
    groupCard.items.slice(0, groupCard.maxShow)

  // Urgency -> accent color
  readonly property string _urgency:
    NotificationService._urgencyToString(latest?.urgency)
  readonly property color accentColor:
    _urgency === "critical"
      ? "#ff4d4f"
      : _urgency === "low"
      ? "#3a3f4a"
      : "#3b82f6"

  function toggleExpand() {
    if (!groupCard.group)
      return;
    groupCard.expanded = !groupCard.expanded;
    if (groupCard.svc)
      groupCard.svc.toggleGroup(groupCard.group.id, groupCard.expanded);
  }

  function clearGroup() {
    if (!groupCard.svc)
      return;
    groupCard.items.slice().forEach(w =>
      groupCard.svc.dismissNotification(w)
    );
  }

  background: Rectangle {
    id: bg
    radius: 12
    color: Qt.rgba(0.10, 0.10, 0.11, 0.78)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.06)
    layer.enabled: true
    layer.smooth: true
    layer.effect: DropShadow {
      horizontalOffset: 0
      verticalOffset: 3
      radius: 24
      samples: 32
      color: Qt.rgba(0, 0, 0, 0.55)
      transparentBorder: true
    }

    // Accent bar on the left
    Rectangle {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      width: 4
      radius: 2
      color: groupCard.accentColor
    }
  }

  contentItem: ColumnLayout {
    spacing: 6

    // Header row: title, app, count, expand/collapse, clear
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        Layout.fillWidth: true
        color: "white"
        elide: Text.ElideRight
        font.bold: true
        text:
          (groupCard.group?.title || "(Group)") +
          " — " +
          (groupCard.group?.appName || "")
      }

      Rectangle {
        Layout.preferredWidth: implicitWidth
        implicitHeight: 20
        implicitWidth: Math.max(22, countText.implicitWidth + 12)
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.07)

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: groupCard.toggleExpand()
        }

        Text {
          id: countText
          anchors.centerIn: parent
          color: "#e0e0e0"
          font.pixelSize: 11
          text: String(groupCard.items.length)
        }
      }

      ToolButton {
        icon.name: groupCard.expanded ? "pan-up" : "pan-down"
        display: AbstractButton.IconOnly
        Accessible.name: groupCard.expanded ? "Collapse" : "Expand"
        visible: !!groupCard.group
        onClicked: groupCard.toggleExpand()
      }

      ToolButton {
        icon.name: "edit-clear"
        display: AbstractButton.IconOnly
        Accessible.name: "Clear group"
        visible: !!groupCard.group && groupCard.items.length > 0
        onClicked: groupCard.clearGroup()
      }
    }

    // Collapsed: preview latest
    Item {
      implicitHeight: previewCard.implicitHeight
      implicitWidth: previewCard.implicitWidth
      visible: !!groupCard.group && !groupCard.expanded && !!groupCard.latest

      NotificationCard {
        id: previewCard
        wrapper: groupCard.latest
        Layout.fillWidth: true

        onActionTriggered: id =>
          groupCard.svc.executeAction(wrapper.id, id)
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
      visible: !!groupCard.group && groupCard.expanded

      Repeater {
        model: groupCard.limitedItems

        delegate: NotificationCard {
          required property var modelData
          wrapper: modelData
          Layout.fillWidth: true

          onActionTriggered: id =>
            groupCard.svc.executeAction(modelData.id, id)
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