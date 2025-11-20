pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Config
import qs.Components
import qs.Services.SystemInfo
import qs.Modules.Notification

OPanel {
  id: root

  readonly property real cardHeight: Theme.itemHeight * 5.5
  readonly property bool hasNotifications: root.notificationCount > 0
  readonly property int maxVisibleCards: 3
  readonly property int notificationCount: NotificationService.notifications?.length || 0
  readonly property var notificationGroups: NotificationService.groupedNotifications || []
  readonly property int padding: 16

  needsKeyboardFocus: false
  panelNamespace: "obelisk-notification-panel"
  panelWidth: 420

  onPanelClosed: NotificationService.onOverlayClose()
  onPanelOpened: NotificationService.onOverlayOpen()

  ColumnLayout {
    spacing: 0
    width: parent.width
    x: 0
    y: 0

    // Weather Widget
    WeatherWidget {
      id: weatherWidget

      Layout.bottomMargin: 8
      Layout.fillWidth: true
      Layout.leftMargin: root.padding
      Layout.rightMargin: root.padding
      Layout.topMargin: root.padding
    }

    // Header
    Rectangle {
      id: header

      Layout.fillWidth: true
      Layout.margins: root.padding
      Layout.preferredHeight: Theme.itemHeight * 1.2
      Layout.topMargin: 0 // Remove top margin since weather is above
      color: Qt.lighter(Theme.bgColor, 1.2)
      radius: Theme.itemRadius

      RowLayout {
        spacing: 16

        anchors {
          fill: parent
          leftMargin: root.padding
          rightMargin: root.padding
        }

        RowLayout {
          spacing: 6

          OText {
            font.bold: true
            sizeMultiplier: 1.15
            text: qsTr("Notifications")
          }

          OText {
            font.bold: true
            opacity: 0.8
            sizeMultiplier: 0.95
            text: root.hasNotifications ? `(${root.notificationCount})` : ""
            useActiveColor: true
            visible: root.hasNotifications
          }
        }

        Item {
          Layout.fillWidth: true
        }

        IconButton {
          Layout.preferredHeight: Theme.itemHeight * 0.9
          Layout.preferredWidth: Theme.itemHeight * 0.9
          icon: "󰩹"
          tooltipText: qsTr("Clear All")
          visible: root.hasNotifications

          onClicked: {
            NotificationService.clearAllNotifications();
            root.close();
          }
        }

        Rectangle {
          Layout.preferredHeight: Theme.itemHeight * 0.6
          Layout.preferredWidth: 1
          color: Theme.textInactiveColor
          opacity: 0.2
          visible: root.hasNotifications
        }

        RowLayout {
          spacing: 8

          OText {
            opacity: NotificationService.doNotDisturb ? 1.0 : 0.5
            sizeMultiplier: 0.9
            text: qsTr("DND")
            useActiveColor: NotificationService.doNotDisturb
          }

          OToggle {
            Layout.preferredHeight: Theme.itemHeight * 0.55
            Layout.preferredWidth: Theme.itemHeight * 1.2
            checked: NotificationService.doNotDisturb

            onToggled: checked => NotificationService.toggleDnd()
          }
        }
      }
    }

    // Scrollable Notifications Area
    Flickable {
      id: notificationFlickable

      Layout.bottomMargin: root.padding
      Layout.fillWidth: true
      Layout.leftMargin: root.padding
      Layout.preferredHeight: {
        const weatherH = weatherWidget.implicitHeight + root.padding + 8; // top + bottom margins
        const headerH = header.Layout.preferredHeight + root.padding; // bottom margin (top is 0)
        const flickableMargins = 8 + root.padding; // top + bottom
        const otherContent = weatherH + headerH + flickableMargins;

        const available = root.maxHeight - otherContent;
        const desired = Math.min(root.cardHeight * root.maxVisibleCards, notificationColumn.implicitHeight);

        return Math.max(0, Math.min(desired, available));
      }
      Layout.rightMargin: root.padding
      Layout.topMargin: 8
      clip: true
      contentHeight: notificationColumn.implicitHeight
      contentWidth: width
      interactive: true // Always allow interaction if content overflows
      visible: root.hasNotifications

      ScrollBar.vertical: ScrollBar {
        policy: notificationFlickable.contentHeight > notificationFlickable.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
      }

      Column {
        id: notificationColumn

        spacing: 8
        width: parent.width

        Repeater {
          model: root.notificationGroups

          NotificationCard {
            required property int index
            required property var modelData

            group: modelData.count > 1 ? modelData : null
            showTimestamp: true
            svc: NotificationService
            width: parent.width
            wrapper: modelData.count === 1 ? (modelData.notifications[0] || null) : null

            onInputFocusRequested: {}
          }
        }
      }
    }

    // Empty State
    Item {
      Layout.fillHeight: true
      Layout.fillWidth: true
      visible: !root.hasNotifications

      ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        width: parent.width * 0.8

        Text {
          Layout.alignment: Qt.AlignHCenter
          color: Theme.textInactiveColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize * 2
          opacity: 0.5
          text: "󰂚"
        }

        OText {
          Layout.alignment: Qt.AlignHCenter
          font.bold: true
          sizeMultiplier: 1.3
          text: qsTr("No Notifications")
        }

        OText {
          Layout.alignment: Qt.AlignHCenter
          horizontalAlignment: Text.AlignHCenter
          opacity: 0.7
          text: qsTr("You're all caught up!")
          useActiveColor: false
        }
      }
    }
  }
}
