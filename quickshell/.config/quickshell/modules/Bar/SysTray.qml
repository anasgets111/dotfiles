pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

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
    id: trayBg

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
      model: SystemTray.items
    }
  }

  Component {
    id: trayItemDelegate

    MouseArea {
      id: trayMouseArea

      // Heuristic lookup once per item
      property var heuristic: (trayMouseArea.trayItem && trayMouseArea.trayItem.lastIpcObject) ? DesktopEntries.heuristicLookup(trayMouseArea.trayItem.lastIpcObject.class) : null
      required property var modelData
      property var trayItem: trayMouseArea.modelData

      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      height: Theme.iconSize
      hoverEnabled: true
      trayItem: trayMouseArea.modelData
      width: Theme.iconSize

      onClicked: function (mouse) {
        if (mouse.button === Qt.LeftButton) {
          trayMouseArea.trayItem.activate();
        } else if (mouse.button === Qt.RightButton && trayMouseArea.trayItem.hasMenu) {
          menuAnchor.open();
        } else if (mouse.button === Qt.MiddleButton) {
          trayMouseArea.trayItem.secondaryActivate();
        }
      }
      onWheel: function (wheel) {
        trayMouseArea.trayItem.scroll(wheel.angleDelta.x, wheel.angleDelta.y);
      }

      QsMenuAnchor {
        id: menuAnchor

        anchor.item: trayMouseArea
        anchor.rect.y: trayMouseArea.height - 5
        menu: trayMouseArea.trayItem.menu
      }

      // Hover halo
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

      // Icon path: prefer image:// from tray, else heuristic icon
      IconImage {
        id: iconImage

        anchors.centerIn: parent
        backer.fillMode: Image.PreserveAspectFit
        backer.smooth: true
        backer.sourceSize.height: iconImage.height
        backer.sourceSize.width: iconImage.width
        height: iconImage.implicitSize
        implicitSize: Theme.iconSize - systemTrayWidget.contentInset * 2
        source: (trayMouseArea.trayItem.icon && trayMouseArea.trayItem.icon.startsWith("image://")) ? trayMouseArea.trayItem.icon : ((trayMouseArea.heuristic && trayMouseArea.heuristic.icon) ? Quickshell.iconPath(trayMouseArea.heuristic.icon) : "")
        visible: iconImage.status !== Image.Error && iconImage.status !== Image.Null
        width: iconImage.implicitSize
      }

      // Fallback letter/mark when icon missing
      Text {
        id: fallbackGlyph

        anchors.centerIn: parent
        color: trayMouseArea.containsMouse ? Theme.textOnHoverColor : Theme.textActiveColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: trayMouseArea.trayItem.tooltipTitle ? trayMouseArea.trayItem.tooltipTitle : (trayMouseArea.trayItem.title ? trayMouseArea.trayItem.title.charAt(0).toUpperCase() : "?")
        visible: iconImage.status === Image.Error || iconImage.status === Image.Null
      }

      // Tooltip
      Rectangle {
        id: tooltip

        anchors.horizontalCenter: trayMouseArea.horizontalCenter
        anchors.top: trayMouseArea.bottom
        anchors.topMargin: 8
        color: Theme.onHoverColor
        height: tooltipText.height + 8
        opacity: trayMouseArea.containsMouse ? 1 : 0
        radius: Theme.itemRadius
        // Show when hovered and there is text, or while fading out
        visible: (tooltip.opacity > 0) && (trayMouseArea.trayItem.tooltipTitle || trayMouseArea.trayItem.title)
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

  // Empty state
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
