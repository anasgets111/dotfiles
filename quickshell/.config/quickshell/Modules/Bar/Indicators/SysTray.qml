pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.Config
import qs.Components

Item {
  id: tray

  property var currentMenuItem: null

  height: Theme.itemHeight
  width: trayRow.implicitWidth

  Rectangle {
    anchors.fill: parent
    color: Theme.inactiveColor
    radius: Theme.itemRadius
  }

  RowLayout {
    id: trayRow

    anchors.centerIn: parent
    spacing: 0

    Repeater {
      id: trayRepeater

      model: SystemTray.items

      delegate: IconButton {
        id: btn

        required property SystemTrayItem modelData

        Layout.alignment: Qt.AlignVCenter
        icon: ""
        showBorder: false
        tooltipText: modelData.tooltipTitle || modelData.title || ""

        onClicked: function (mouse) {
          if (!mouse)
            return;
          if (mouse.button === Qt.RightButton && modelData.hasMenu) {
            tray.currentMenuItem = modelData;
            trayMenuPanel.openAtItem(btn, 0, 0);
          } else if (mouse.button === Qt.LeftButton) {
            modelData.activate();
          } else {
            modelData.secondaryActivate();
          }
        }

        MouseArea {
          acceptedButtons: Qt.NoButton
          anchors.fill: parent
          hoverEnabled: false

          onWheel: w => btn.modelData.scroll(Math.abs(w.angleDelta.y) > Math.abs(w.angleDelta.x) ? w.angleDelta.y : w.angleDelta.x, Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y))
        }

        Item {
          anchors.fill: parent

          IconImage {
            id: iconImage

            anchors.centerIn: parent
            backer.cache: false
            backer.fillMode: Image.PreserveAspectFit
            backer.smooth: true
            backer.sourceSize: Qt.size(Theme.iconSize, Theme.iconSize)
            implicitSize: Theme.iconSize
            source: btn.modelData.icon
            visible: status !== Image.Error && status !== Image.Null
          }

          OText {
            anchors.centerIn: parent
            bold: true
            color: Theme.textContrast(btn.effectiveBg)
            text: (btn.modelData.tooltipTitle || btn.modelData.title || btn.modelData.id || "?").charAt(0).toUpperCase()
            visible: !iconImage.visible
          }
        }
      }
    }
  }

  OText {
    anchors.centerIn: parent
    color: Theme.bgColor
    opacity: 0.7
    size: "xs"
    text: "No tray items"
    visible: trayRepeater.count === 0
  }

  OPanel {
    id: trayMenuPanel

    panelHeight: menuContent.implicitHeight + 16
    panelNamespace: "obelisk-systray-panel"
    panelWidth: 300

    onPanelClosed: tray.currentMenuItem = null

    QsMenuOpener {
      id: menuOpener

      menu: tray.currentMenuItem?.menu ?? null
    }

    ColumnLayout {
      id: menuContent

      anchors.fill: parent
      anchors.margins: Theme.spacingSm
      spacing: Theme.spacingXs / 2

      Repeater {
        model: menuOpener.children?.values ?? []

        delegate: Item {
          id: menuItem

          readonly property bool isSeparator: modelData?.isSeparator ?? false
          readonly property bool itemEnabled: modelData?.enabled ?? true
          required property var modelData

          Layout.fillWidth: true
          Layout.preferredHeight: isSeparator ? 8 : Theme.itemHeight

          Rectangle {
            anchors.centerIn: parent
            color: Theme.borderColor
            height: 1
            visible: menuItem.isSeparator
            width: parent.width - Theme.spacingSm
          }

          Rectangle {
            anchors.fill: parent
            color: itemMouse.containsMouse ? Theme.onHoverColor : "transparent"
            radius: Theme.itemRadius
            visible: !menuItem.isSeparator

            OText {
              anchors.fill: parent
              anchors.leftMargin: Theme.spacingMd
              anchors.rightMargin: Theme.spacingMd
              color: Theme.textContrast(parent.color)
              elide: Text.ElideRight
              opacity: menuItem.itemEnabled ? 1.0 : 0.5
              text: menuItem.modelData?.text ?? ""
              verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
              id: itemMouse

              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              enabled: menuItem.itemEnabled
              hoverEnabled: true

              onClicked: {
                menuItem.modelData?.triggered();
                trayMenuPanel.close();
              }
            }
          }
        }
      }

      OText {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight
        color: Theme.textActiveColor
        horizontalAlignment: Text.AlignHCenter
        text: "No menu items"
        verticalAlignment: Text.AlignVCenter
        visible: (menuOpener.children?.values.length ?? 0) === 0
      }
    }
  }
}
