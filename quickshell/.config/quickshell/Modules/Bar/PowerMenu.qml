pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Config

Rectangle {
  id: powerMenu

  // Helpers
  readonly property int animMs: Theme.animationDuration
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
  property int collapsedWidth: Theme.itemWidth
  property bool expanded: hovered
  readonly property int expandedWidth: Theme.itemWidth * buttons.length + spacing * (buttons.length - 1)

  // State
  property bool hovered: false

  // Config
  property int spacing: 8

  function runCommand(cmd) {
    actionProc.command = ["sh", "-c", cmd];
    actionProc.running = true;
  }

  color: "transparent"
  height: Theme.itemHeight
  radius: Theme.itemRadius
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

  // Hover handling with delayed collapse
  Timer {
    id: collapseTimer

    interval: powerMenu.animMs
    repeat: false

    onTriggered: {
      if (!hoverHandler.hovered)
        powerMenu.hovered = false;
    }
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
  Row {
    id: buttonRow

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: powerMenu.spacing

    Repeater {
      model: powerMenu.buttons.length

      delegate: Rectangle {
        id: btn

        readonly property string action: powerMenu.buttons[index].action

        // Cache model fields
        readonly property string icon: powerMenu.buttons[index].icon
        required property int index
        property bool isHovered: false
        readonly property bool isLast: index === (powerMenu.buttons.length - 1)
        readonly property bool show: powerMenu.expanded || isLast
        readonly property string tooltipText: powerMenu.buttons[index].tooltip

        color: isHovered ? Theme.activeColor : Theme.inactiveColor
        focus: false
        height: Theme.itemHeight
        opacity: show ? 1 : 0
        radius: Theme.itemRadius
        visible: opacity > 0 || width > 0
        width: show ? Theme.itemWidth : 0

        Behavior on color {
          ColorAnimation {
            duration: powerMenu.animMs
            easing.type: Easing.InOutQuad
          }
        }
        Behavior on opacity {
          NumberAnimation {
            duration: powerMenu.animMs
            easing.type: Easing.InOutQuad
          }
        }
        Behavior on width {
          NumberAnimation {
            duration: powerMenu.animMs
            easing.type: Easing.InOutQuad
          }
        }

        Keys.onPressed: event => {
          if (!btn.show)
            return;
          const k = event.key;
          if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            powerMenu.runCommand(btn.action);
            event.accepted = true;
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          enabled: btn.show
          hoverEnabled: true

          onClicked: powerMenu.runCommand(btn.action)
          onEntered: btn.isHovered = true
          onExited: btn.isHovered = false
        }
        Rectangle {
          id: tooltip

          anchors.left: parent.left
          anchors.top: parent.bottom
          anchors.topMargin: 8
          color: Theme.onHoverColor
          height: tipText.implicitHeight + 8
          opacity: btn.isHovered ? 1 : 0
          radius: Theme.itemRadius
          visible: btn.isHovered
          width: tipText.implicitWidth + 16

          Behavior on opacity {
            NumberAnimation {
              duration: powerMenu.animMs
              easing.type: Easing.OutCubic
            }
          }

          Text {
            id: tipText

            anchors.centerIn: parent
            color: Theme.textContrast(tooltip.color)
            font.bold: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: btn.tooltipText
          }
        }
        Text {
          anchors.centerIn: parent
          color: Theme.textContrast(parent.color)
          font.bold: true
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: btn.icon
        }
      }
    }
  }
}
