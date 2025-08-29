// SystemTrayWidget.qml
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Config
import qs.Services.Core
import qs.Widgets

Item {
  id: tray

  required property var bar
  readonly property int contentInset: 2
  readonly property int horizontalPadding: 8

  height: Theme.itemHeight
  width: Math.max(trayRow.implicitWidth + horizontalPadding * 2, Theme.itemHeight)

  Rectangle {
    id: backgroundRect

    anchors.fill: parent
    color: Theme.inactiveColor
    radius: Theme.itemRadius
  }
  Row {
    id: trayRow

    anchors.centerIn: parent

    Repeater {
      id: trayRepeater

      delegate: trayItemDelegate
      model: SystemTrayService.items
    }
  }
  Component {
    id: trayItemDelegate

    Item {
      id: slot

      required property var modelData
      property var trayItem: slot.modelData

      implicitHeight: Theme.itemHeight
      implicitWidth: Theme.itemWidth

      IconButton {
        id: btn

        anchors.fill: parent

        contentItem: Item {
          height: Theme.itemHeight
          width: Theme.itemWidth

          IconImage {
            id: iconImage

            anchors.centerIn: parent
            backer.fillMode: Image.PreserveAspectFit
            backer.smooth: true
            backer.sourceSize.height: implicitSize
            backer.sourceSize.width: implicitSize
            height: implicitSize
            implicitSize: Theme.iconSize - tray.contentInset * 2
            source: SystemTrayService.normalizedIconFor(slot.trayItem)
            visible: status !== Image.Error && status !== Image.Null
            width: implicitSize
          }
          Text {
            anchors.centerIn: parent
            color: Theme.textContrast(btn.effectiveBg)
            font.bold: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: SystemTrayService.fallbackGlyphFor(slot.trayItem)
            visible: !iconImage.visible
          }
        }

        area.onWheel: function (wheelEvent) {
          SystemTrayService.scrollItem(slot.trayItem, wheelEvent.angleDelta.x, wheelEvent.angleDelta.y);
        }
        onClicked: function (mouse) {
          if (!mouse)
            return;
          if (mouse.button === Qt.RightButton && SystemTrayService.hasMenuForItem(slot.trayItem)) {
            menuAnchor.open();
            return;
          }
          SystemTrayService.handleItemClick(slot.trayItem, mouse.button);
        }
      }
      QsMenuAnchor {
        id: menuAnchor

        anchor.item: btn.area
        anchor.rect.y: btn.height - 5
        menu: slot.trayItem ? slot.trayItem.menu : null
      }
      Tooltip {
        edge: Qt.BottomEdge
        hoverSource: btn.area
        target: btn
        text: SystemTrayService.tooltipTitleFor(slot.trayItem)
        visibleWhenTargetHovered: !!SystemTrayService.displayTitleFor(slot.trayItem)
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
