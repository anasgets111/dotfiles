pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Config
import qs.Components
import qs.Services.SystemInfo
import qs.Modules.Notification
import qs.Modules.Bar.Indicators

OPanel {
  id: root

  readonly property real availableContentHeight: {
    const usedHeight = weatherWidget.implicitHeight + header.Layout.preferredHeight + root.padding * 2 + 16;
    return Math.max(0, root.maxHeight - usedHeight);
  }
  readonly property real cardHeight: Theme.itemHeight * 5.5
  readonly property bool hasNotifications: NotificationService.notifications.length > 0
  readonly property int maxVisibleCards: 3
  readonly property int padding: Theme.spacingLg

  needsKeyboardFocus: false
  panelNamespace: "obelisk-notification-panel"
  panelWidth: 420

  onPanelClosed: NotificationService.onOverlayClose()
  onPanelOpened: NotificationService.onOverlayOpen()

  ColumnLayout {
    width: parent.width

    WeatherWidget {
      id: weatherWidget

      Layout.bottomMargin: Theme.spacingSm
      Layout.fillWidth: true
      Layout.margins: root.padding
    }

    Rectangle {
      id: header

      Layout.fillWidth: true
      Layout.leftMargin: root.padding
      Layout.preferredHeight: Theme.itemHeight * 1.2
      Layout.rightMargin: root.padding
      color: Theme.bgElevatedAlt
      radius: Theme.itemRadius

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        spacing: Theme.spacingSm

        OText {
          bold: true
          size: "lg"
          text: root.hasNotifications ? qsTr("Notifications") + ` (${NotificationService.notifications.length})` : qsTr("Notifications")
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
          Layout.leftMargin: Theme.spacingXs
          Layout.preferredHeight: Theme.itemHeight * 0.6
          Layout.preferredWidth: 1
          Layout.rightMargin: Theme.spacingXs
          color: Theme.textInactiveColor
          opacity: 0.2
          visible: root.hasNotifications
        }

        OText {
          accent: NotificationService.doNotDisturb
          opacity: NotificationService.doNotDisturb ? 1.0 : 0.5
          size: "sm"
          text: qsTr("DND")
        }

        OToggle {
          Layout.preferredHeight: Theme.itemHeight * 0.55
          Layout.preferredWidth: Theme.itemHeight * 1.2
          checked: NotificationService.doNotDisturb

          onToggled: NotificationService.toggleDnd()
        }
      }
    }

    Flickable {
      id: notificationFlickable

      Layout.fillWidth: true
      Layout.margins: root.padding
      Layout.preferredHeight: Math.min(root.cardHeight * root.maxVisibleCards, notificationColumn.implicitHeight, root.availableContentHeight)
      Layout.topMargin: Theme.spacingSm
      clip: true
      contentHeight: notificationColumn.implicitHeight
      contentWidth: width
      visible: root.hasNotifications

      ScrollBar.vertical: ScrollBar {
        policy: notificationFlickable.contentHeight > notificationFlickable.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
      }

      Column {
        id: notificationColumn

        spacing: Theme.spacingSm
        width: parent.width

        Repeater {
          model: NotificationService.groupedNotifications

          NotificationCard {
            required property int index
            required property var modelData

            group: modelData
            showTimestamp: true
            svc: NotificationService
            width: parent.width

            onInputFocusReleased: root.needsKeyboardFocus = false
            onInputFocusRequested: root.needsKeyboardFocus = true
          }
        }
      }
    }

    ColumnLayout {
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      Layout.margins: root.padding
      Layout.preferredHeight: Math.min(root.cardHeight * 1.5, root.availableContentHeight)
      Layout.topMargin: Theme.spacingSm
      spacing: Theme.spacingLg
      visible: !root.hasNotifications

      Item {
        Layout.fillHeight: true
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.textInactiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontXl
        opacity: 0.5
        text: "󰂚"
      }

      OText {
        Layout.alignment: Qt.AlignHCenter
        bold: true
        size: "xl"
        text: qsTr("No Notifications")
      }

      OText {
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        muted: true
        opacity: 0.7
        text: qsTr("You're all caught up!")
      }

      Item {
        Layout.fillHeight: true
      }
    }
  }
}
