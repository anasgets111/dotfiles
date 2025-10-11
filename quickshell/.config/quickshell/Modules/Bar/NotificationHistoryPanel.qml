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
  panelNamespace: "obelisk-notification-panel"

  readonly property int maxVisibleGroups: 5
  readonly property int padding: 16
  readonly property var notificationGroups: NotificationService.groupedNotifications || []
  readonly property int notificationCount: NotificationService.notifications?.length || 0
  readonly property bool hasNotifications: root.notificationCount > 0

  panelWidth: 420
  needsKeyboardFocus: true

  onPanelOpened: NotificationService.onOverlayOpen()
  onPanelClosed: NotificationService.onOverlayClose()

  FocusScope {
    width: parent.width
    height: contentColumn.implicitHeight
    focus: root.isOpen

    ColumnLayout {
      id: contentColumn
      width: parent.width
      spacing: 0

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight * 1.2
        Layout.margins: root.padding
        color: Qt.lighter(Theme.bgColor, 1.2)
        radius: Theme.itemRadius

        RowLayout {
          anchors {
            fill: parent
            leftMargin: root.padding
            rightMargin: root.padding
          }
          spacing: 16

          RowLayout {
            spacing: 6

            OText {
              text: qsTr("Notifications")
              font.bold: true
              sizeMultiplier: 1.15
            }

            OText {
              text: root.hasNotifications ? `(${root.notificationCount})` : ""
              useActiveColor: true
              opacity: 0.8
              sizeMultiplier: 0.95
              font.bold: true
              visible: root.hasNotifications
            }
          }

          Item {
            Layout.fillWidth: true
          }

          IconButton {
            Layout.preferredWidth: Theme.itemHeight * 0.9
            Layout.preferredHeight: Theme.itemHeight * 0.9
            icon: "󰩹"
            tooltipText: qsTr("Clear All")
            visible: root.hasNotifications
            onClicked: {
              NotificationService.clearAllNotifications();
              root.close();
            }
          }

          Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: Theme.itemHeight * 0.6
            color: Theme.textInactiveColor
            opacity: 0.2
            visible: root.hasNotifications
          }

          RowLayout {
            spacing: 8

            OText {
              text: qsTr("DND")
              useActiveColor: NotificationService.doNotDisturb
              opacity: NotificationService.doNotDisturb ? 1.0 : 0.5
              sizeMultiplier: 0.9
            }

            OToggle {
              Layout.preferredWidth: Theme.itemHeight * 1.2
              Layout.preferredHeight: Theme.itemHeight * 0.55
              checked: NotificationService.doNotDisturb
              onToggled: checked => NotificationService.toggleDnd()
            }
          }
        }
      }

      ListView {
        id: notificationList
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: root.padding
        Layout.leftMargin: root.padding
        Layout.rightMargin: root.padding
        Layout.preferredHeight: Math.min(contentHeight, root.maxVisibleGroups * (Theme.itemHeight * 5))

        visible: root.hasNotifications
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        model: root.notificationGroups

        ScrollBar.vertical: ScrollBar {
          policy: notificationList.contentHeight > notificationList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
          width: 8
        }

        delegate: Loader {
          id: delegateLoader
          required property var modelData
          required property int index

          width: ListView.view.width
          active: !!delegateLoader.modelData
          sourceComponent: NotificationCard {
            svc: NotificationService
            wrapper: delegateLoader.modelData.count === 1 ? (delegateLoader.modelData.notifications[0] || null) : null
            group: delegateLoader.modelData.count > 1 ? delegateLoader.modelData : null
            onInputFocusRequested: {}
          }
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 300
        visible: !root.hasNotifications

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 16
          width: parent.width * 0.8

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰂚"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 4
            color: Theme.textInactiveColor
            opacity: 0.5
          }

          OText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("No Notifications")
            sizeMultiplier: 1.3
            font.bold: true
          }

          OText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("You're all caught up!")
            useActiveColor: false
            opacity: 0.7
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
