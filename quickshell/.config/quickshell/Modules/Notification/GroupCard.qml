pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.Services.SystemInfo
import qs.Config

CardBase {
  id: groupCard

  required property var group // New structure: { key, appName, notifications, latestNotification, count, hasInlineReply, expanded }
  // Provide access to service
  property var svc: NotificationService

  implicitWidth: 380
  shown: groupCard.items.length > 0  // All items are popups by construction of groupedPopups

  // Visible wrappers in this group (already filtered/sorted in groupedPopups)
  readonly property var items: groupCard.group?.notifications || []
  readonly property var latest: groupCard.items.length > 0 ? groupCard.items[0] : null
  // Reactive expanded state from service
  property bool expanded: NotificationService.expandedGroups[group.key] || false

  readonly property int maxShow: Math.max(1, Number(groupCard.svc?.maxVisibleNotifications || 1))
  readonly property var limitedItems: groupCard.items.slice(0, groupCard.maxShow)

  // Local urgency string for latest
  readonly property string _urgency: (function () {
      const u = groupCard.latest?.urgency ?? 0;
      switch (u) {
      case NotificationUrgency.Low:
        return "low";
      case NotificationUrgency.Critical:
        return "critical";
      default:
        return "normal";
      }
    })()
  accentColor: _urgency === "critical" ? "#ff4d4f" : _urgency === "low" ? Qt.rgba(Theme.disabledColor.r, Theme.disabledColor.g, Theme.disabledColor.b, 0.9) : Theme.activeColor

  function toggleExpand() {
    groupCard.svc.toggleGroupExpansion(groupCard.group.key);
  }

  function clearGroup() {
    if (!groupCard.svc)
      return;
    groupCard.svc.dismissGroup(groupCard.group.key);
  }

  ColumnLayout {
    spacing: 6

    // Header row: appName, count, expand/collapse, clear
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        Layout.fillWidth: true
        color: "white"
        elide: Text.ElideRight
        font.bold: true
        text: (groupCard.group?.appName || "(Group)") + ` (${groupCard.items.length})`  // No title; use appName + count
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
        id: expandBtn
        text: groupCard.expanded ? "▴" : "▾"
        display: AbstractButton.TextOnly
        Accessible.name: groupCard.expanded ? "Collapse" : "Expand"
        visible: !!groupCard.group
        onClicked: groupCard.toggleExpand()
        background: Rectangle {
          radius: 10
          color: expandBtn.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
          border.width: 1
          border.color: Qt.rgba(255, 255, 255, 0.07)
        }
        padding: 4
        leftPadding: 8
        rightPadding: 8
      }

      ToolButton {
        id: clearBtn
        text: "×"
        display: AbstractButton.TextOnly
        Accessible.name: "Clear group"
        visible: !!groupCard.group && groupCard.items.length > 0
        onClicked: groupCard.clearGroup()
        background: Rectangle {
          radius: 10
          color: clearBtn.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
          border.width: 1
          border.color: Qt.rgba(255, 255, 255, 0.07)
        }
        padding: 4
        leftPadding: 8
        rightPadding: 8
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

        onActionTriggered: id => groupCard.svc && groupCard.svc.executeAction(previewCard.wrapper, id)
        onActionTriggeredEx: (id, actionObj) => groupCard.svc && groupCard.svc.executeAction(previewCard.wrapper, id, actionObj)
        onDismiss: groupCard.svc.dismissNotification(previewCard.wrapper)
        // Reply omitted
      }
    }

    // Expanded: list all items
    ColumnLayout {
      spacing: 6
      visible: !!groupCard.group && groupCard.expanded

      Repeater {
        model: groupCard.limitedItems

        delegate: NotificationCard {
          required property var modelData  // Wrapper
          wrapper: modelData
          Layout.fillWidth: true

          onActionTriggered: id => groupCard.svc && groupCard.svc.executeAction(modelData, id)
          onActionTriggeredEx: (id, actionObj) => groupCard.svc && groupCard.svc.executeAction(modelData, id, actionObj)
          onDismiss: groupCard.svc.dismissNotification(modelData)
          // Reply omitted
        }
      }
    }
  }
}
