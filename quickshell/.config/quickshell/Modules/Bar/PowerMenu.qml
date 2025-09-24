pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Config
import qs.Components

Item {
  id: powerMenu

  // Actions (unchanged API)
  readonly property var actions: [
    {
      cmd: "loginctl terminate-user $USER",
      icon: "󰍃",
      tooltip: "Log Out"
    },
    {
      cmd: "systemctl reboot",
      icon: "",
      tooltip: "Restart"
    },
    {
      cmd: "systemctl poweroff",
      icon: "⏻",
      tooltip: "Power Off"
    }
  ]

  // Countdown state
  readonly property int initialCountdown: 10
  property int countdown: initialCountdown
  property bool counting: false
  property int selectedIndex: -1

  // API-equivalent functions
  function startCountdown(index) {
    selectedIndex = index;
    countdown = initialCountdown;
    counting = true;
    tickTimer.start();
  }
  function cancelCountdown() {
    counting = false;
    selectedIndex = -1;
    tickTimer.stop();
  }
  function commitSelected() {
    if (selectedIndex >= 0) {
      proc.command = ["sh", "-c", actions[selectedIndex].cmd];
      proc.running = true;
    }
    cancelCountdown();
  }

  // Size follows the pill
  height: pill.height
  width: pill.width

  Process {
    id: proc
  }

  // Global click-away catcher while counting
  MouseArea {
    anchors.fill: parent
    visible: powerMenu.counting
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: mouse => {
      // If click occurs outside the pill, cancel; else let it pass through
      const p = pill.mapFromItem(this, mouse.x, mouse.y);
      const inside = p.x >= 0 && p.y >= 0 && p.x <= pill.width && p.y <= pill.height;
      if (!inside) {
        powerMenu.cancelCountdown();
        mouse.accepted = true;
      } else {
        mouse.accepted = false;
      }
    }
  }
  // Countdown timer
  Timer {
    id: tickTimer
    interval: 1000
    repeat: true
    onTriggered: {
      if (!powerMenu.counting) {
        stop();
        return;
      }
      powerMenu.countdown -= 1;
      if (powerMenu.countdown <= 0) {
        stop();
        powerMenu.commitSelected();
      }
    }
  }

  // The expanding/collapsing right-aligned pill container (your ExpandingPill)
  ExpandingPill {
    id: pill

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter

    count: powerMenu.actions.length
    collapsedIndex: Math.max(0, count - 1)
    holdOpen: powerMenu.counting

    // Per-cell content
    delegate: Component {
      IconButton {
        id: btn

        required property int index
        readonly property var rec: powerMenu.actions[index]
        readonly property bool isSelectedCounting: powerMenu.counting && powerMenu.selectedIndex === index

        anchors.fill: parent
        tooltipText: powerMenu.counting ? (isSelectedCounting ? `${rec.tooltip} — ${powerMenu.countdown}s\nLeft click to execute now • Right click to cancel` : `${rec.tooltip}\nRight click to cancel`) : rec.tooltip
        icon: ""

        // Progress sweep when counting selected (uses shared FillBar component)
        FillBar {
          anchors.fill: parent
          progress: btn.isSelectedCounting ? (powerMenu.initialCountdown - powerMenu.countdown) / powerMenu.initialCountdown : 0
          fillColor: Theme.onHoverColor
          radius: Theme.itemHeight / 2
        }
        // Centered glyph or countdown number
        Text {
          anchors.centerIn: parent
          color: btn.effectiveFg !== undefined ? btn.effectiveFg : Theme.textContrast(Theme.inactiveColor)
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          font.bold: true
          text: btn.isSelectedCounting ? ("" + powerMenu.countdown) : btn.rec.icon
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        // Flash while counting (selected only)
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
        onIsSelectedCountingChanged: if (!btn.isSelectedCounting)
          btn.opacity = 1.0

        onClicked: point => {
          switch (point.button) {
          case Qt.RightButton:
            if (powerMenu.counting)
              powerMenu.cancelCountdown();
            return;
          case Qt.LeftButton:
            {
              const isSelected = powerMenu.selectedIndex === index;
              if (!powerMenu.counting || !isSelected)
                powerMenu.startCountdown(index);
              else
                powerMenu.commitSelected();
              return;
            }
          default:
            return; // ignore middle/other buttons for now
          }
        }
      }
    }
  }
}
