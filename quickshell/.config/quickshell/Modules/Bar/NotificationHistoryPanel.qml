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

  readonly property bool hasNotifications: root.notificationCount > 0
  readonly property int maxVisibleGroups: 5
  readonly property int notificationCount: NotificationService.notifications?.length || 0
  readonly property var notificationGroups: NotificationService.groupedNotifications || []
  readonly property int padding: 16

  needsKeyboardFocus: false
  panelNamespace: "obelisk-notification-panel"
  panelWidth: 420

  onPanelClosed: NotificationService.onOverlayClose()
  onPanelOpened: NotificationService.onOverlayOpen()

  FocusScope {
    focus: root.isOpen
    height: contentColumn.implicitHeight
    width: parent.width

    ColumnLayout {
      id: contentColumn

      spacing: 0
      width: parent.width

      Rectangle {
        Layout.fillWidth: true
        Layout.margins: root.padding
        Layout.preferredHeight: Theme.itemHeight * 1.2
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

      ListView {
        id: notificationList

        Layout.bottomMargin: root.padding
        Layout.fillWidth: true
        Layout.leftMargin: root.padding
        Layout.preferredHeight: Math.min(contentHeight, root.maxVisibleGroups * (Theme.itemHeight * 5))
        Layout.rightMargin: root.padding
        Layout.topMargin: 8
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        interactive: contentHeight > height
        model: root.notificationGroups
        spacing: 8
        visible: root.hasNotifications

        ScrollBar.vertical: ScrollBar {
          policy: notificationList.contentHeight > notificationList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
          width: 8
        }
        delegate: Loader {
          id: delegateLoader

          required property int index
          required property var modelData

          active: !!delegateLoader.modelData
          width: ListView.view.width

          sourceComponent: NotificationCard {
            group: delegateLoader.modelData.count > 1 ? delegateLoader.modelData : null
            showTimestamp: true
            svc: NotificationService
            wrapper: delegateLoader.modelData.count === 1 ? (delegateLoader.modelData.notifications[0] || null) : null

            onInputFocusRequested: {}
          }
        }
      }

      Item {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.minimumHeight: 300
        visible: !root.hasNotifications

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 16
          width: parent.width * 0.8

          Text {
            Layout.alignment: Qt.AlignHCenter
            color: Theme.textInactiveColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 4
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
}
