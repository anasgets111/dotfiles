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
  width: Math.max(trayRow.implicitWidth + systemTrayWidget.horizontalPadding * 2, Theme.itemHeight)

  Rectangle {
    id: backgroundRect

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
      property var trayItem: trayMouseArea.modelData

      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      height: Theme.iconSize
      hoverEnabled: true
      width: Theme.iconSize

      onClicked: function (mouseEvent) {
        if (mouseEvent.button === Qt.RightButton && SystemTrayService.hasMenuForItem(trayMouseArea.trayItem)) {
          menuAnchor.open();
          return;
        }
        SystemTrayService.handleItemClick(trayMouseArea.trayItem, mouseEvent.button);
      }
      onWheel: function (wheelEvent) {
        SystemTrayService.scrollItem(trayMouseArea.trayItem, wheelEvent.angleDelta.x, wheelEvent.angleDelta.y);
      }

      QsMenuAnchor {
        id: menuAnchor

        anchor.item: trayMouseArea
        anchor.rect.y: trayMouseArea.height - 5
        menu: trayMouseArea.trayItem ? trayMouseArea.trayItem.menu : null
      }
      Rectangle {
        id: hoverHalo

        anchors.centerIn: parent
        color: Theme.onHoverColor
        height: hoverHalo.width
        opacity: trayMouseArea.containsMouse ? 1 : 0
        radius: hoverHalo.width / 2
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
        backer.sourceSize.height: iconImage.height
        backer.sourceSize.width: iconImage.width
        height: iconImage.implicitSize
        implicitSize: Theme.iconSize - systemTrayWidget.contentInset * 2
        source: SystemTrayService.normalizedIconFor(trayMouseArea.trayItem)
        visible: iconImage.status !== Image.Error && iconImage.status !== Image.Null
        width: iconImage.implicitSize
      }
      Text {
        id: glyphFallback

        anchors.centerIn: parent
        color: trayMouseArea.containsMouse ? Theme.textOnHoverColor : Theme.textActiveColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: SystemTrayService.fallbackGlyphFor(trayMouseArea.trayItem)
        visible: iconImage.status === Image.Error || iconImage.status === Image.Null
      }
      Rectangle {
        id: tooltip

        anchors.horizontalCenter: trayMouseArea.horizontalCenter
        anchors.top: trayMouseArea.bottom
        anchors.topMargin: 8
        color: Theme.onHoverColor
        height: tooltipText.height + 8
        opacity: trayMouseArea.containsMouse ? 1 : 0
        radius: Theme.itemRadius
        visible: (tooltip.opacity > 0) && !!SystemTrayService.displayTitleFor(trayMouseArea.trayItem)
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
          text: SystemTrayService.tooltipTitleFor(trayMouseArea.trayItem)
        }
      }
    }
  }
  Text {
    id: emptyHint

    anchors.centerIn: parent
    color: Theme.panelColor
    font.family: Theme.fontFamily
    font.pixelSize: 10
    opacity: 0.7
    text: "No tray items"
    visible: trayRepeater.count === 0
  }
}
