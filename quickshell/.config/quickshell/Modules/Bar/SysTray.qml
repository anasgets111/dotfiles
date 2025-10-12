pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Config
import qs.Services.Core
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

      model: SystemTrayService.items

      delegate: IconButton {
        id: btn

        required property var modelData

        Layout.alignment: Qt.AlignVCenter
        Layout.preferredHeight: Theme.itemHeight
        Layout.preferredWidth: Theme.itemWidth
        icon: ""
        showBorder: false
        tooltipText: SystemTrayService.displayTitleFor(modelData) ? SystemTrayService.tooltipTitleFor(modelData) : ""

        onClicked: function (mouse) {
          if (!mouse)
            return;
          if (mouse.button === Qt.RightButton && SystemTrayService.hasMenuForItem(modelData)) {
            tray.currentMenuItem = modelData;
            trayMenuPanel.openAtItem(btn, 0, 0);
            return;
          }
          SystemTrayService.handleItemClick(modelData, mouse.button);
        }

        MouseArea {
          acceptedButtons: Qt.NoButton
          anchors.fill: parent
          hoverEnabled: false

          onWheel: function (w) {
            SystemTrayService.scrollItem(btn.modelData, w.angleDelta.x, w.angleDelta.y);
          }
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
            source: SystemTrayService.normalizedIconFor(btn.modelData)
            visible: status !== Image.Error && status !== Image.Null
          }

          Text {
            anchors.centerIn: parent
            color: Theme.textContrast(btn.effectiveBg)
            font.bold: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: SystemTrayService.fallbackGlyphFor(btn.modelData)
            visible: !iconImage.visible
          }
        }
      }
    }
  }

  Text {
    anchors.centerIn: parent
    color: Theme.bgColor
    font.family: Theme.fontFamily
    font.pixelSize: 10
    opacity: 0.7
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

      menu: tray.currentMenuItem ? SystemTrayService.menuModelForItem(tray.currentMenuItem) : null
    }

    ColumnLayout {
      id: menuContent

      anchors.fill: parent
      anchors.margins: 8
      spacing: 2

      Repeater {
        model: menuOpener.children ? [...menuOpener.children.values] : []

        delegate: Component {
          Item {
            id: menuItem

            readonly property bool isSeparator: modelData?.isSeparator ?? false
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredHeight: menuItem.isSeparator ? 8 : Theme.itemHeight

            Rectangle {
              anchors.centerIn: parent
              color: Theme.borderColor
              height: 1
              visible: menuItem.isSeparator
              width: parent.width - 8
            }

            Rectangle {
              anchors.fill: parent
              color: mouseArea.containsMouse ? Theme.onHoverColor : "transparent"
              radius: Theme.itemRadius
              visible: !menuItem.isSeparator

              Text {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                color: Theme.textContrast(parent.color)
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                opacity: (menuItem.modelData?.enabled ?? true) ? 1.0 : 0.5
                text: menuItem.modelData?.text || ""
                verticalAlignment: Text.AlignVCenter
              }

              MouseArea {
                id: mouseArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: menuItem.modelData?.enabled ?? true
                hoverEnabled: true

                onClicked: {
                  if (menuItem.modelData && !menuItem.isSeparator && (menuItem.modelData?.enabled ?? true)) {
                    menuItem.modelData.triggered();
                    trayMenuPanel.close();
                  }
                }
              }
            }
          }
        }
      }

      Text {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight
        color: Theme.textActiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        text: "No menu items"
        verticalAlignment: Text.AlignVCenter
        visible: menuOpener.children.values.length === 0
      }
    }
  }
}
