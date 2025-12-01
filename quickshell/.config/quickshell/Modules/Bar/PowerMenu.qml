pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Config
import qs.Components

Item {
  id: powerMenu

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
  property int countdown: initialCountdown
  readonly property bool counting: selectedIndex >= 0

  // Countdown state - counting is derived from selectedIndex
  readonly property int initialCountdown: 10
  property int selectedIndex: -1

  function cancelCountdown() {
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

  function startCountdown(index) {
    selectedIndex = index;
    countdown = initialCountdown;
    tickTimer.start();
  }

  height: pill.height
  width: pill.width

  Process {
    id: proc

  }

  // Click-away handler while counting
  MouseArea {
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    anchors.fill: parent
    visible: powerMenu.counting

    onPressed: mouse => {
      const p = pill.mapFromItem(this, mouse.x, mouse.y);
      if (p.x < 0 || p.y < 0 || p.x > pill.width || p.y > pill.height) {
        powerMenu.cancelCountdown();
        mouse.accepted = true;
      } else {
        mouse.accepted = false;
      }
    }
  }

  Timer {
    id: tickTimer

    interval: 1000
    repeat: true

    onTriggered: {
      powerMenu.countdown--;
      if (powerMenu.countdown <= 0) {
        stop();
        powerMenu.commitSelected();
      }
    }
  }

  ExpandingPill {
    id: pill

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    collapsedIndex: Math.max(0, count - 1)
    count: powerMenu.actions.length
    holdOpen: powerMenu.counting

    delegate: Component {
      IconButton {
        id: btn

        readonly property var action: powerMenu.actions[index]
        required property int index
        readonly property bool isSelected: powerMenu.counting && powerMenu.selectedIndex === index

        anchors.fill: parent
        opacity: 1.0
        tooltipText: powerMenu.counting ? (isSelected ? `${action.tooltip} — ${powerMenu.countdown}s\nLeft click to execute now • Right click to cancel` : `${action.tooltip}\nRight click to cancel`) : action.tooltip

        SequentialAnimation on opacity {
          loops: Animation.Infinite
          running: btn.isSelected

          onRunningChanged: if (!running)
            btn.opacity = 1.0

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

        onClicked: point => {
          if (point.button === Qt.RightButton) {
            if (powerMenu.counting)
              powerMenu.cancelCountdown();
          } else if (point.button === Qt.LeftButton) {
            if (!powerMenu.counting || powerMenu.selectedIndex !== index)
              powerMenu.startCountdown(index);
            else
              powerMenu.commitSelected();
          }
        }

        FillBar {
          anchors.fill: parent
          fillColor: Theme.onHoverColor
          progress: btn.isSelected ? (powerMenu.initialCountdown - powerMenu.countdown) / powerMenu.initialCountdown : 0
          radius: Theme.itemHeight / 2
        }

        Text {
          anchors.centerIn: parent
          color: btn.effectiveFg ?? Theme.textContrast(Theme.inactiveColor)
          font.bold: true
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          horizontalAlignment: Text.AlignHCenter
          text: btn.isSelected ? String(powerMenu.countdown) : btn.action.icon
          verticalAlignment: Text.AlignVCenter
        }
      }
    }
  }
}
