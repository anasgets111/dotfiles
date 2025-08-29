pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Config
import qs.Services.Core

Item {
  id: systemTrayWidget

  required property var bar
  readonly property int contentInset: 2
  readonly property int horizontalPadding: 10
  readonly property int hoverPadding: 3
  readonly property int iconSpacing: 8

  height: Theme.itemHeight
  width: Math.max(trayRow.implicitWidth + horizontalPadding * 2, Theme.itemHeight)

  Rectangle {
    anchors.fill: parent
    color: Theme.inactiveColor
    radius: Theme.itemRadius
  }
  Row {
    id: trayRow

    anchors.centerIn: parent
    spacing: systemTrayWidget.iconSpacing

    Repeater {
      id: trayRepeater

      delegate: trayItemDelegate
      model: SystemTrayService.items
    }
  }
  Component {
    id: trayItemDelegate

    MouseArea {
      id: trayMouseArea

      required property var modelData
      property var trayItem: modelData

      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      height: Theme.iconSize
      hoverEnabled: true
      width: Theme.iconSize

      onClicked: function (mouse) {
        if (mouse.button === Qt.RightButton && trayMouseArea.trayItem && trayMouseArea.trayItem.hasMenu)
          menuAnchor.open();
        else
          SystemTrayService.handleItemClick(trayMouseArea.trayItem, mouse.button);
      }

      // Scrolling can be handled by service or ignored; keep widget logic minimal.

      QsMenuAnchor {
        id: menuAnchor

        anchor.item: trayMouseArea
        anchor.rect.y: trayMouseArea.height - 5
        menu: trayMouseArea.trayItem ? trayMouseArea.trayItem.menu : null
      }
      Rectangle {
        anchors.centerIn: parent
        color: Theme.onHoverColor
        height: width
        opacity: trayMouseArea.containsMouse ? 1 : 0
        radius: width / 2
        width: Theme.iconSize + systemTrayWidget.hoverPadding * 2

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutCubic
          }
        }
      }
      IconImage {
        id: iconImage

        anchors.centerIn: parent
        backer.fillMode: Image.PreserveAspectFit
        backer.smooth: true
        backer.sourceSize.height: height
        backer.sourceSize.width: width
        height: implicitSize
        implicitSize: Theme.iconSize - systemTrayWidget.contentInset * 2
        source: SystemTrayService.normalizedIconFor(trayMouseArea.trayItem)
        visible: status !== Image.Error && status !== Image.Null
        width: implicitSize
      }
      Text {
        anchors.centerIn: parent
        color: trayMouseArea.containsMouse ? Theme.textOnHoverColor : Theme.textActiveColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: trayMouseArea.trayItem.tooltipTitle ? trayMouseArea.trayItem.tooltipTitle : (trayMouseArea.trayItem.title ? trayMouseArea.trayItem.title.charAt(0).toUpperCase() : "?")
        visible: iconImage.status === Image.Error || iconImage.status === Image.Null
      }
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 8
        color: Theme.onHoverColor
        height: tooltipText.height + 8
        opacity: trayMouseArea.containsMouse ? 1 : 0
        radius: Theme.itemRadius
        // Tooltip: keep fade animation by driving visibility from opacity
        // Show when hovered and there is text, or while animating out
        visible: (opacity > 0) && (trayMouseArea.trayItem.tooltipTitle || trayMouseArea.trayItem.title)
        width: tooltipText.width + 16

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutCubic
          }
        }

        Text {
          id: tooltipText

          anchors.centerIn: parent
          color: Theme.textContrast(Theme.onHoverColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: trayMouseArea.trayItem.tooltipTitle ? trayMouseArea.trayItem.tooltipTitle : trayMouseArea.trayItem.title
        }
      }
    }
  }
  Text {
    anchors.centerIn: parent
    color: Theme.panelColor
    font.family: Theme.fontFamily
    font.pixelSize: 10
    opacity: 0.7
    text: "No tray items"
    visible: trayRepeater.count === 0
  }
}
