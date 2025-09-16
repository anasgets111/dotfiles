pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Config                  // Theme.qml singleton
import qs.Services.SystemInfo     // NotificationService singleton
import qs.Services.WM

PanelWindow {
  id: notificationsPanelWindow

  anchors {
    top: true
    right: true
  }
  // Wider, responsive width
  implicitWidth: Math.max(420, Math.min(640, Theme.volumeExpandedWidth + Theme.panelMargin * 4))
  // Height follows content plus top offset under the bar and bottom margin
  implicitHeight: scrollView.implicitHeight + Theme.panelHeight + Theme.panelMargin * 2
  visible: NotificationService.visibleModel && NotificationService.visibleModel.count > 0
  screen: MonitorService.effectiveMainScreen

  // Wayland layer settings
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.exclusiveZone: -1
  color: "transparent"

  mask: Region {
    item: popupStackColumn
  }

  // Margin container and top offset under the bar
  Item {
    anchors.fill: parent
    anchors.topMargin: Theme.panelHeight + Theme.panelMargin
    anchors.leftMargin: Theme.panelMargin
    anchors.rightMargin: Theme.panelMargin
    anchors.bottomMargin: Theme.panelMargin

    ScrollView {
      id: scrollView
      anchors.fill: parent
      contentWidth: availableWidth
      clip: true
      ScrollBar.vertical.policy: ScrollBar.AsNeeded

      Column {
        id: popupStackColumn
        width: scrollView.availableWidth
        spacing: Math.max(6, Math.round(Theme.panelMargin * 0.5))

        Repeater {
          id: popupRepeater
          model: NotificationService.visibleModel
          delegate: NotifPopup {
            id: notificationDelegate
            // The 'notification' role from the model is assigned automatically
            width: parent.width
            clip: true  // ensure slide animations don't draw outside during transitions
          }
        }

        // bottom spacer so last card is not clipped by rounded corners
        Item {
          width: 1
          height: Theme.panelMargin
        }
      }
    }
  }
}
