pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Config
import qs.Widgets

Item {
  id: powerMenu

  // Timings and sizing
  readonly property int animMs: Theme.animationDuration

  // Buttons model
  property var buttons: [
    {
      icon: "󰍃",
      tooltip: "Log Out",
      action: "loginctl terminate-user $USER"
    },
    {
      icon: "",
      tooltip: "Restart",
      action: "systemctl reboot"
    },
    {
      icon: "⏻",
      tooltip: "Power Off",
      action: "systemctl poweroff"
    }
  ]
  readonly property int collapsedWidth: slotW

  // Layout
  readonly property int count: buttons.length
  readonly property bool expanded: hovered
  readonly property int expandedWidth: count * slotW + Math.max(0, count - 1) * spacing

  // State
  property bool hovered: false
  readonly property int slotH: Theme.itemHeight
  readonly property int slotW: Theme.itemWidth
  readonly property int spacing: 8

  // Runner
  function runCommand(cmd) {
    actionProc.command = ["sh", "-c", cmd];
    actionProc.running = true;
  }

  clip: false
  height: slotH
  width: expanded ? expandedWidth : collapsedWidth

  Behavior on width {
    NumberAnimation {
      duration: powerMenu.animMs
      easing.type: Easing.InOutQuad
    }
  }

  Process {
    id: actionProc

  }

  // Hover with delayed collapse
  Timer {
    id: collapseTimer

    interval: powerMenu.animMs

    onTriggered: if (!hoverHandler.hovered)
      powerMenu.hovered = false
  }
  HoverHandler {
    id: hoverHandler

    onHoveredChanged: {
      if (hovered) {
        powerMenu.hovered = true;
        collapseTimer.stop();
      } else {
        collapseTimer.restart();
      }
    }
  }

  // Overlay for tooltips (unclipped)
  Item {
    id: overlay

    anchors.fill: parent
    clip: false
    // Passive container
    visible: true
    z: 1000
  }

  // Content row (clipped so hidden buttons don’t leak)
  Item {
    id: rowViewport

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    clip: true
    height: powerMenu.slotH
    width: powerMenu.width

    Item {
      id: row

      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: powerMenu.slotH
      width: powerMenu.expandedWidth

      Repeater {
        model: powerMenu.count

        delegate: Item {
          id: cell

          required property int index
          readonly property bool isLast: index === (powerMenu.count - 1)
          readonly property bool show: powerMenu.expanded || isLast

          height: powerMenu.slotH
          width: show ? powerMenu.slotW : 0
          // Fixed positions; row is right-anchored so last cell hits the right edge
          x: index * (powerMenu.slotW + powerMenu.spacing)

          Behavior on width {
            NumberAnimation {
              duration: powerMenu.animMs
              easing.type: Easing.InOutQuad
            }
          }

          IconButton {
            id: btn

            anchors.fill: parent
            bgColor: Theme.inactiveColor
            hoverBgColor: Theme.onHoverColor
            iconText: powerMenu.buttons[cell.index].icon
            opacity: cell.show ? 1 : 0

            Behavior on opacity {
              NumberAnimation {
                duration: powerMenu.animMs
                easing.type: Easing.InOutQuad
              }
            }

            onLeftClicked: powerMenu.runCommand(powerMenu.buttons[cell.index].action)
          }

          // Tooltip anchored to overlay; Tooltip handles positioning via mapToItem internally
          Tooltip {
            edge: Qt.BottomEdge
            hoverSource: btn.area
            parent: overlay
            target: btn
            text: powerMenu.buttons[cell.index].tooltip
            visibleWhenTargetHovered: true
          }
        }
      }
    }
  }
}
