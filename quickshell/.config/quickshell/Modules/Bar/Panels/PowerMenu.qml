pragma ComponentBehavior: Bound

import QtQuick
import qs.Config
import qs.Components
import qs.Services.Core

Item {
  id: powerMenu

  readonly property var actions: [
    {
      callback: () => PowerManagementService.logout(),
      icon: "󰍃",
      tooltip: "Log Out"
    },
    {
      callback: () => PowerManagementService.reboot(),
      icon: "",
      tooltip: "Restart"
    },
    {
      callback: () => PowerManagementService.poweroff(),
      icon: "⏻",
      tooltip: "Power Off"
    }
  ]
  property int countdown: initialCountdown
  readonly property bool counting: selectedIndex >= 0
  readonly property int countdownIndex: counting ? (selectedIndex === actions.length - 1 ? actions.length - 2 : actions.length - 1) : -1
  readonly property int initialCountdown: 10
  property int selectedIndex: -1

  function cancelCountdown() {
    selectedIndex = -1;
    tickTimer.stop();
  }
  function commitSelected() {
    if (selectedIndex >= 0)
      actions[selectedIndex].callback();
    cancelCountdown();
  }
  function startCountdown(index) {
    selectedIndex = index;
    countdown = initialCountdown;
    tickTimer.start();
  }

  height: pill.height
  width: pill.width

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
        readonly property bool isActionSlot: !powerMenu.counting || powerMenu.selectedIndex === index
        readonly property bool isCancelSlot: powerMenu.counting && !isActionSlot && !isCountdownSlot
        readonly property bool isCountdownSlot: powerMenu.counting && powerMenu.countdownIndex === index
        required property int index

        anchors.fill: parent
        icon: isActionSlot ? action.icon : isCancelSlot ? "󰅖" : String(powerMenu.countdown)
        isEnabled: !isCountdownSlot
        opacity: 1
        selected: powerMenu.counting && isActionSlot
        tooltipText: isActionSlot ? (powerMenu.counting ? `${action.tooltip} pending\nLeft click to execute now • Right click to cancel` : action.tooltip) : isCancelSlot ? `Cancel pending ${powerMenu.actions[powerMenu.selectedIndex].tooltip}` : ""

        SequentialAnimation on opacity {
          loops: Animation.Infinite
          running: powerMenu.counting && btn.isActionSlot

          onRunningChanged: if (!running)
            btn.opacity = 1.0

          NumberAnimation {
            duration: Theme.animationSlow
            easing.type: Easing.InOutQuad
            from: 1.0
            to: 0.4
          }
          NumberAnimation {
            duration: Theme.animationSlow
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
            if (btn.isCancelSlot)
              powerMenu.cancelCountdown();
            else if (!powerMenu.counting)
              powerMenu.startCountdown(index);
            else if (btn.isActionSlot)
              powerMenu.commitSelected();
          }
        }

        FillBar {
          anchors.fill: parent
          fillColor: Theme.onHoverColor
          progress: btn.isCountdownSlot ? (powerMenu.initialCountdown - powerMenu.countdown) / powerMenu.initialCountdown : 0
          radius: Theme.itemHeight / 2
        }
      }
    }
  }
}
