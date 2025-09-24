pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.Services.SystemInfo
import qs.Config

Item {
  id: groupCard
  required property var group
  property var svc

  implicitWidth: 380
  implicitHeight: cardContent.implicitHeight + 20

  readonly property var items: groupCard.group?.notifications || []
  readonly property var latest: groupCard.items.length > 0 ? groupCard.items[0] : null
  property bool expanded: NotificationService.expandedGroups[group.key] || false

  function urgencyToColor(urgency) {
    switch (urgency) {
    case NotificationUrgency.Critical:
      return "#ff4d4f";
    case NotificationUrgency.Low:
      return Qt.rgba(Theme.disabledColor.r, Theme.disabledColor.g, Theme.disabledColor.b, 0.9);
    default:
      return Theme.activeColor;
    }
  }

  readonly property color accentColor: urgencyToColor(latest?.urgency ?? NotificationUrgency.Normal)

  function toggleExpand() {
    groupCard.svc && groupCard.svc.toggleGroupExpansion(groupCard.group.key);
  }
  function clearGroup() {
    if (groupCard.svc)
      groupCard.svc.dismissGroup(groupCard.group.key);
  }

  // Animation
  property bool _animReady: false
  x: !_animReady ? width + (Theme.popupOffset || 12) : 0
  Behavior on x {
    NumberAnimation {
      duration: (Theme.animationDuration || 200) * 1.4
      easing.type: Easing.OutCubic
    }
  }
  Component.onCompleted: Qt.callLater(() => _animReady = true)

  // Card styling
  CardStyling {
    anchors.fill: parent
    accentColor: groupCard.accentColor
  }

  ColumnLayout {
    id: cardContent
    anchors.fill: parent
    anchors.margins: 10
    spacing: 6

    // Row 1: Control Row - App icon LEFT, Expand + Clear buttons RIGHT
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      // Left: App icon (simplified inline version)
      Rectangle {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        radius: 8
        color: Qt.rgba(Theme.textActiveColor.r, Theme.textActiveColor.g, Theme.textActiveColor.b, 0.07)
        border.width: 1
        border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.05)
        visible: !!(groupCard.group?.appName)
        Image {
          anchors.centerIn: parent
          width: 30
          height: 30
          fillMode: Image.PreserveAspectFit
          smooth: true
          source: Quickshell.iconPath(groupCard.group?.appName || "", true)
          sourceSize.width: 64
          sourceSize.height: 64
          onStatusChanged: if (status === Image.Error)
            parent.visible = false
        }
      }

      // Center spacer
      Item {
        Layout.fillWidth: true
      }

      // Right: Control buttons
      RowLayout {
        spacing: 6

        StandardButton {
          buttonType: "control"
          text: groupCard.expanded ? "▴" : "▾"
          Accessible.name: groupCard.expanded ? "Collapse" : "Expand"
          onClicked: groupCard.toggleExpand()
        }

        StandardButton {
          buttonType: "control"
          text: "×"
          Accessible.name: "Clear group"
          visible: groupCard.items.length > 0
          onClicked: groupCard.clearGroup()
        }
      }
    }

    // Row 2: Content Row - Group title + count center
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        Layout.fillWidth: true
        color: Theme.textActiveColor
        font.bold: true
        elide: Text.ElideRight
        text: (groupCard.group?.appName || "(Group)") + ` (${groupCard.items.length})`
      }
    }

    // Collapsed preview - shows simplified latest notification
    NotificationItem {
      id: preview
      visible: !!groupCard.latest && !groupCard.expanded
      wrapper: groupCard.latest
      mode: "list"
      onActionTriggeredEx: (id, obj) => groupCard.svc && groupCard.svc.executeAction(preview.wrapper, id, obj)
      onDismiss: groupCard.svc && groupCard.svc.dismissNotification(preview.wrapper)
    }

    // Expanded list - shows all notifications as list items
    ColumnLayout {
      spacing: 4
      visible: groupCard.expanded
      Repeater {
        model: groupCard.items
        delegate: NotificationItem {
          required property var modelData
          wrapper: modelData
          mode: "list"
          onActionTriggeredEx: (id, obj) => groupCard.svc && groupCard.svc.executeAction(modelData, id, obj)
          onDismiss: groupCard.svc && groupCard.svc.dismissNotification(modelData)
        }
      }
    }
  }
}
