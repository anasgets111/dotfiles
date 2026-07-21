pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Config
import qs.Components
import qs.Services.SystemInfo
import qs.Modules.Notification
import qs.Modules.Bar.Indicators

PanelContentBase {
  id: root

  readonly property real availableContentHeight: {
    const footerHeight = clearButton.visible ? clearButton.implicitHeight + clearButton.Layout.bottomMargin + Theme.spacingSm : 0;
    const usedHeight = weatherWidget.implicitHeight + systemInfoWidget.implicitHeight + header.Layout.preferredHeight + footerHeight + root.padding * 2 + Theme.spacingSm * 3;
    return Math.max(0, root.maxHeight - usedHeight);
  }
  readonly property real cardHeight: Theme.itemHeight * 5.5
  readonly property bool hasNotifications: NotificationService.notifications.length > 0
  property int maxHeight: 600
  readonly property int maxVisibleCards: 3
  readonly property int padding: Theme.spacingLg

  preferredHeight: contentLayout.implicitHeight
  preferredWidth: Theme.notificationPanelWidth

  Component.onDestruction: NotificationService.onOverlayClose()
  onIsOpenChanged: {
    if (isOpen)
      NotificationService.onOverlayOpen();
    else
      NotificationService.onOverlayClose();
  }

  ColumnLayout {
    id: contentLayout

    width: parent.width

    WeatherWidget {
      id: weatherWidget

      Layout.bottomMargin: Theme.spacingSm
      Layout.fillWidth: true
      Layout.margins: root.padding
    }
    SystemInfoWidget {
      id: systemInfoWidget

      Layout.bottomMargin: Theme.spacingSm
      Layout.fillWidth: true
      Layout.leftMargin: root.padding
      Layout.rightMargin: root.padding
      active: root.isOpen
    }
    PanelCard {
      id: header

      Layout.fillWidth: true
      Layout.leftMargin: root.padding
      Layout.preferredHeight: Theme.itemHeight * 1.2
      Layout.rightMargin: root.padding
      padding: 0

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

          onToggled: NotificationService.toggleDoNotDisturb()
        }
      }
    }
    ListView {
      id: notificationList

      Layout.fillWidth: true
      Layout.margins: root.padding
      Layout.preferredHeight: Math.min(contentHeight, root.cardHeight * root.maxVisibleCards, root.availableContentHeight)
      Layout.topMargin: Theme.spacingSm
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      model: NotificationService.groupedNotifications
      reuseItems: true
      spacing: Theme.spacingSm
      visible: root.hasNotifications

      ScrollBar.vertical: ScrollBar {
        policy: notificationList.contentHeight > notificationList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
      }

      delegate: NotificationCard {
        required property int index
        required property var modelData

        group: modelData
        groupScope: "history"
        showTimestamp: true
        svc: NotificationService
        width: ListView.view.width

        ListView.onPooled: root.needsKeyboardFocus = false
        ListView.onReused: resetReuseState()
        onInputFocusReleased: root.needsKeyboardFocus = false
        onInputFocusRequested: root.needsKeyboardFocus = true
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
        opacity: Theme.opacityDisabled
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
        opacity: Theme.opacityMuted
        text: qsTr("You're all caught up!")
      }
      Item {
        Layout.fillHeight: true
      }
    }
    OButton {
      id: clearButton

      Layout.alignment: Qt.AlignRight
      Layout.bottomMargin: root.padding
      Layout.rightMargin: root.padding
      bgColor: Theme.critical
      text: qsTr("Clear all")
      variant: "secondary"
      visible: root.hasNotifications

      onClicked: NotificationService.clearAllNotifications()
    }
  }
}
