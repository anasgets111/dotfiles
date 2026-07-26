pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Modules.Bar.Indicators
import qs.Modules.Notification
import qs.Services.SystemInfo

PanelContentBase {
  id: root

  readonly property var bucketLabels: ({
      earlier: qsTr("Earlier"),
      today: qsTr("Today"),
      urgent: qsTr("Urgent"),
      yesterday: qsTr("Yesterday")
    })
  readonly property bool hasNotifications: NotificationService.notifications.length > 0
  readonly property string historySummary: {
    const count = NotificationService.notifications.length;
    if (count === 0)
      return NotificationService.doNotDisturb ? qsTr("Silenced · history empty") : qsTr("History empty");
    const parts = [qsTr("%1 in history").arg(count)];
    const appCount = NotificationService.groupedNotifications.length;
    if (appCount > 1)
      parts.push(qsTr("%1 apps").arg(appCount));
    if (NotificationService.doNotDisturb)
      parts.push(qsTr("silenced"));
    return parts.join(" · ");
  }
  property var inputFocusOwner: null
  readonly property int padding: Theme.spacingMd

  function setInputFocusOwner(owner: var): void {
    root.inputFocusOwner = owner;
    root.needsKeyboardFocus = owner !== null;
  }

  preferredHeight: Math.min(contentColumn.implicitHeight + root.padding * 2, root.maxAvailableHeight)
  preferredWidth: Theme.notificationPanelWidth

  Component.onDestruction: NotificationService.onOverlayClose()
  onIsOpenChanged: {
    if (isOpen)
      NotificationService.onOverlayOpen();
    else
      NotificationService.onOverlayClose();
  }

  Flickable {
    id: sidebarScroll

    anchors.fill: parent
    anchors.margins: root.padding
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    contentHeight: contentColumn.implicitHeight
    contentWidth: sidebarScroll.width

    ScrollBar.vertical: ScrollBar {
      policy: sidebarScroll.contentHeight > sidebarScroll.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
      width: Theme.spacingXs
    }

    ColumnLayout {
      id: contentColumn

      spacing: Theme.spacingMd
      width: sidebarScroll.width

      WeatherWidget {
        Layout.fillWidth: true
      }
      SystemInfoWidget {
        Layout.fillWidth: true
        active: root.isOpen
      }
      PanelHeader {
        accent: NotificationService.doNotDisturb ? Theme.textInactiveColor : Theme.activeColor
        icon: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
        subtitle: root.historySummary
        title: qsTr("Notifications")

        InfoBadge {
          badgeColor: Theme.critical
          text: qsTr("%1 urgent").arg(NotificationService.criticalCount)
          visible: NotificationService.criticalCount > 0
        }
        PanelActionIcon {
          icon: NotificationService.doNotDisturb ? "󰂚" : "󰂛"
          tint: NotificationService.doNotDisturb ? Theme.textInactiveColor : Theme.activeColor
          tooltipText: NotificationService.doNotDisturb ? qsTr("Disable Do Not Disturb") : qsTr("Enable Do Not Disturb")

          onClicked: NotificationService.toggleDoNotDisturb()
        }
        PanelActionIcon {
          icon: "󰆴"
          tint: Theme.critical
          tooltipText: qsTr("Dismiss all notifications")
          visible: root.hasNotifications

          onClicked: NotificationService.clearAllNotifications()
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        visible: root.hasNotifications

        Repeater {
          model: NotificationService.groupedNotifications

          delegate: ColumnLayout {
            id: historyRow

            required property int index
            required property var modelData
            readonly property bool startsBucket: historyRow.index === 0 || NotificationService.groupedNotifications[historyRow.index - 1]?.bucket !== historyRow.modelData?.bucket

            Layout.fillWidth: true
            spacing: Theme.spacingXs

            PanelSectionHeader {
              Layout.fillWidth: true
              Layout.topMargin: historyRow.index === 0 ? 0 : Theme.spacingSm
              section: historyRow.modelData?.bucket ?? ""
              sectionLabel: root.bucketLabels[historyRow.modelData?.bucket] ?? ""
              visible: historyRow.startsBucket
            }
            NotificationCard {
              id: historyCard

              Layout.fillWidth: true
              group: historyRow.modelData
              groupScope: "history"
              showTimestamp: true
              svc: NotificationService

              Component.onDestruction: if (root.inputFocusOwner === historyCard)
                root.setInputFocusOwner(null)
              onInputFocusReleased: if (root.inputFocusOwner === historyCard)
                root.setInputFocusOwner(null)
              onInputFocusRequested: root.setInputFocusOwner(historyCard)
            }
          }
        }
      }
      PanelEmptyState {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight * 5
        icon: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
        subtext: NotificationService.doNotDisturb ? qsTr("Do Not Disturb is on") : qsTr("You're all caught up!")
        text: qsTr("No Notifications")
        visible: !root.hasNotifications
      }
    }
  }
}
