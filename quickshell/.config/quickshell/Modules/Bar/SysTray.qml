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
              showBorder: false
              // We still need a custom visual because IconButton only displays text.
              // Embed icon + fallback glyph as overlay children.
              icon: ""  // leave empty so internal Text stays hidden; we'll manage visuals below
              tooltipText: SystemTrayService.tooltipTitleFor(slot.trayItem)

              // Additional MouseArea just for wheel events (IconButton's own MouseArea consumes hover/click)
              MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: false
                onWheel: function (w) {
                  SystemTrayService.scrollItem(slot.trayItem, w.angleDelta.x, w.angleDelta.y);
                }
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

              // Visual layer
              Item {
                anchors.fill: parent
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
            }
            QsMenuAnchor {
              id: menuAnchor
              // Anchor to the button itself (IconButton no longer exposes 'area')
              anchor.item: btn
              anchor.rect.y: btn.height - 5
              menu: slot.trayItem ? slot.trayItem.menu : null
            }
            // Gate tooltip visibility after creation
            Component.onCompleted: if (!SystemTrayService.displayTitleFor(slot.trayItem))
              btn.tooltipText = ""
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
