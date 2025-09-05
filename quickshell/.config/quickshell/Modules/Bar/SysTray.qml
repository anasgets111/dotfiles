pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Config
import qs.Services.Core
import qs.Widgets

Item {
  id: tray

  readonly property int contentInset: 0
  readonly property int horizontalPadding: 0

  height: Theme.itemHeight
  width: Math.max(layoutWrapper.implicitWidth, 0)

  Rectangle {
    id: backgroundRect

    anchors.fill: parent
    color: Theme.inactiveColor
    radius: Theme.itemRadius
  }

  // Wrapper item so RowLayout can define implicit size cleanly
  Item {
    id: layoutWrapper

    anchors.centerIn: parent
    implicitHeight: Theme.itemHeight
    implicitWidth: trayRow.implicitWidth

    RowLayout {
      id: trayRow

      anchors.fill: parent
      spacing: 0

      Repeater {
        id: trayRepeater

        model: SystemTrayService.items

        delegate: Component {
          Item {
            id: slot

            required property var modelData
            property var trayItem: slot.modelData

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: implicitHeight
            Layout.preferredWidth: implicitWidth
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
      }
    }
  }
  Text {
    id: emptyHint

    anchors.centerIn: parent
    color: Theme.bgColor
    font.family: Theme.fontFamily
    font.pixelSize: 10
    opacity: 0.7
    text: "No tray items"
    visible: trayRepeater.count === 0
  }
}
