pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Config
import qs.Widgets
import QtQuick.Layouts

Item {
  id: powerMenu

  property var actionsArr: [
    {
      icon: "󰍃",
      tooltip: "Log Out",
      cmd: "loginctl terminate-user $USER"
    },
    {
      icon: "",
      tooltip: "Restart",
      cmd: "systemctl reboot"
    },
    {
      icon: "⏻",
      tooltip: "Power Off",
      cmd: "systemctl poweroff"
    }
  ]
  readonly property int animMs: Theme.animationDuration
  property var btns: []
  readonly property int count: actions.count
  property int countdown: 10
  property bool counting: false
  readonly property bool expanded: hoverHandler.hovered || counting
  readonly property int expandedWidth: count * slotW + Math.max(0, count - 1) * spacing
  property int selectedIndex: -1
  readonly property int slotH: Theme.itemHeight
  readonly property int slotW: Theme.itemWidth
  readonly property int spacing: 8

  function cancelCountdown() {
    counting = false;
    selectedIndex = -1;
    tickTimer.stop();
  }
  function commitSelected() {
    if (selectedIndex >= 0) {
      runCommand(actions.get(selectedIndex).cmd);
    }
    cancelCountdown();
  }
  function runCommand(cmd) {
    proc.command = ["sh", "-c", cmd];
    proc.running = true;
  }
  function startCountdown(index) {
    selectedIndex = index;
    countdown = 10;
    counting = true;
    tickTimer.start();
  }

  clip: false
  height: slotH
  width: expanded ? expandedWidth : slotW

  Behavior on width {
    NumberAnimation {
      duration: powerMenu.animMs
      easing.type: Easing.InOutQuad
    }
  }

  ListModel {
    id: actions

    ListElement {
      cmd: "loginctl terminate-user $USER"
      icon: "󰍃"
      tooltip: "Log Out"
    }
    ListElement {
      cmd: "systemctl reboot"
      icon: ""
      tooltip: "Restart"
    }
    ListElement {
      cmd: "systemctl poweroff"
      icon: "⏻"
      tooltip: "Power Off"
    }
  }
  Process {
    id: proc

  }
  Timer {
    id: collapseTimer

    interval: powerMenu.animMs

    onTriggered: {}
  }
  HoverHandler {
    id: hoverHandler

    onHoveredChanged: {
      if (powerMenu.counting) {
        collapseTimer.stop();
      } else {
        hovered ? collapseTimer.stop() : collapseTimer.restart();
      }
    }
  }
  MouseArea {
    id: clickAwayCatcher

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    anchors.fill: parent
    hoverEnabled: true
    propagateComposedEvents: true

    onPressed: mouse => {
      if (powerMenu.counting) {
        // Check if click hits any tracked button
        let hit = false;
        for (let i = 0; i < powerMenu.count; i++) {
          const b = powerMenu.btns && powerMenu.btns[i];
          if (!b)
            continue;
          const p = b.mapFromItem(clickAwayCatcher, mouse.x, mouse.y);
          if (p.x >= 0 && p.y >= 0 && p.x <= b.width && p.y <= b.height) {
            hit = true;
            break;
          }
        }
        if (!hit)
          powerMenu.cancelCountdown();
      }
      mouse.accepted = false;
    }
  }
  Timer {
    id: tickTimer

    interval: 1000
    repeat: true
    running: false

    onTriggered: {
      if (!powerMenu.counting) {
        stop();
        return;
      }
      powerMenu.countdown = powerMenu.countdown - 1;
      if (powerMenu.countdown <= 0) {
        stop();
        powerMenu.commitSelected();
      }
    }
  }
  Item {
    id: overlay

    anchors.fill: parent
    clip: false
  }
  Item {
    id: viewport

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    clip: true
    height: powerMenu.slotH
    width: powerMenu.width

    RowLayout {
      id: row

      // The total width is managed by the layout; no explicit width binding here.
      // Height is fixed to slotH to match your viewport
      Layout.fillHeight: false

      // Same anchoring as before
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter

      // Let the layout compute its width; viewport clips it
      // spacing matches your powerMenu.spacing
      spacing: powerMenu.spacing

      Repeater {
        model: powerMenu.count

        delegate: Item {
          id: cell

          required property int index
          readonly property bool isLast: index === (powerMenu.count - 1)
          readonly property var rec: powerMenu.actionsArr[index]
          readonly property bool show: powerMenu.expanded || isLast

          Layout.maximumHeight: powerMenu.slotH
          Layout.minimumHeight: powerMenu.slotH
          Layout.preferredHeight: powerMenu.slotH

          // Let the layout size/position this cell
          Layout.preferredWidth: show ? powerMenu.slotW : 0
          height: powerMenu.slotH

          // Internally animate content width for smoothness
          width: Layout.preferredWidth

          // Wrapper whose width we animate to avoid hard jumps during layout changes
          Item {
            id: content

            anchors.fill: parent
            height: parent.height
            width: parent.width

            // Animate width changes when show toggles
            Behavior on width {
              NumberAnimation {
                duration: powerMenu.animMs
                easing.type: Easing.InOutQuad
              }
            }

            IconButton {
              id: btn

              property bool isSelectedCounting: powerMenu.counting && powerMenu.selectedIndex === cell.index

              anchors.fill: parent
              bgColor: Theme.inactiveColor
              hoverBgColor: Theme.onHoverColor
              iconText: btn.isSelectedCounting ? powerMenu.countdown.toString() : cell.rec.icon
              opacity: cell.show ? 1 : 0

              // Flash while counting on selected
              SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: btn.isSelectedCounting

                NumberAnimation {
                  duration: 300
                  easing.type: Easing.InOutQuad
                  from: 1.0
                  to: 0.4
                }
                NumberAnimation {
                  duration: 300
                  easing.type: Easing.InOutQuad
                  from: 0.4
                  to: 1.0
                }
              }

              // Smooth in/out when show toggles
              Behavior on opacity {
                NumberAnimation {
                  duration: powerMenu.animMs
                  easing.type: Easing.InOutQuad
                }
              }

              Component.onCompleted: {
                // expose this button for outside-click hit testing
                // ensure list exists and store by index
                const arr = powerMenu.btns || [];
                arr[cell.index] = btn;
                powerMenu.btns = arr;

                // Ensure IconButton’s MouseArea accepts right button too
                if (btn.area) {
                  btn.area.acceptedButtons = Qt.LeftButton | Qt.RightButton;
                }
              }
              Component.onDestruction: {
                if (powerMenu.btns && powerMenu.btns[cell.index] === btn) {
                  powerMenu.btns[cell.index] = null;
                }
              }

              // Click behavior unchanged
              onLeftClicked: {
                if (!powerMenu.counting) {
                  powerMenu.startCountdown(cell.index);
                } else if (powerMenu.selectedIndex === cell.index) {
                  powerMenu.commitSelected();
                } else {
                  powerMenu.startCountdown(cell.index);
                }
              }

              // Right-click cancels countdown
              onRightClicked: {
                if (powerMenu.counting) {
                  powerMenu.cancelCountdown();
                }
              }
            }
            Tooltip {
              edge: Qt.BottomEdge
              hoverSource: btn.area
              parent: overlay
              target: btn
              text: (powerMenu.counting ? (btn.isSelectedCounting ? `${cell.rec.tooltip} — ${powerMenu.countdown}s\nLeft click to execute now • Right click to cancel` : `${cell.rec.tooltip}\nRight click to cancel`) : cell.rec.tooltip)
              visibleWhenTargetHovered: true
            }
          }
        }
      }
    }
  }
}
