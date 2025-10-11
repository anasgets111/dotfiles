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
        showBorder: false
        icon: ""
        tooltipText: SystemTrayService.displayTitleFor(modelData) ? SystemTrayService.tooltipTitleFor(modelData) : ""

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.NoButton
          hoverEnabled: false
          onWheel: function (w) {
            SystemTrayService.scrollItem(btn.modelData, w.angleDelta.x, w.angleDelta.y);
          }
        }

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

        Item {
          anchors.fill: parent
          IconImage {
            id: iconImage
            anchors.centerIn: parent
            implicitSize: Theme.iconSize
            backer.fillMode: Image.PreserveAspectFit
            backer.smooth: true
            backer.sourceSize: Qt.size(Theme.iconSize, Theme.iconSize)
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
    panelNamespace: "obelisk-systray-panel"
    panelWidth: 300
    panelHeight: menuContent.implicitHeight + 16
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
            required property var modelData
            readonly property bool isSeparator: modelData?.isSeparator ?? false

            Layout.fillWidth: true
            Layout.preferredHeight: menuItem.isSeparator ? 8 : Theme.itemHeight

            Rectangle {
              visible: menuItem.isSeparator
              anchors.centerIn: parent
              width: parent.width - 8
              height: 1
              color: Theme.borderColor
            }

            Rectangle {
              visible: !menuItem.isSeparator
              anchors.fill: parent
              color: mouseArea.containsMouse ? Theme.onHoverColor : "transparent"
              radius: Theme.itemRadius

              Text {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                text: menuItem.modelData?.text || ""
                color: Theme.textContrast(parent.color)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                opacity: (menuItem.modelData?.enabled ?? true) ? 1.0 : 0.5
              }

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: menuItem.modelData?.enabled ?? true
                cursorShape: Qt.PointingHandCursor

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
        visible: menuOpener.children?.values?.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight
        text: "No menu items"
        color: Theme.textActiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
