pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import qs.Config

Item {
  id: root

  // Public API ------------------------------------------------------
  property string icon: ""
  property string tooltipText: ""
  property bool enabled: true
  property bool allowClickWhenDisabled: false
  property bool hovered: mouseArea.containsMouse && root.enabled

  signal leftClicked

  // Theming
  property color colorBg: Theme.inactiveColor
  property color colorBgHover: Theme.onHoverColor
  property color colorFg: Theme.textContrast(colorBg)
  property color colorFgHover: Theme.textContrast(colorBgHover)
  property color colorBorder: Theme.inactiveColor
  property color colorBorderHover: Theme.onHoverColor

  // Derived
  readonly property color effectiveBg: !enabled ? colorBg : (hovered ? colorBgHover : colorBg)
  readonly property color effectiveFg: !enabled ? Theme.textContrast(colorBg) : (hovered ? colorFgHover : colorFg)

  // Geometry
  implicitWidth: Theme.itemHeight
  implicitHeight: Theme.itemHeight

  // Signals
  signal clicked(var mouse)
  signal rightClicked
  signal middleClicked
  signal entered
  signal exited
  signal pressed(var mouse)
  signal released(var mouse)

  Rectangle {
    id: bgRect
    anchors.fill: parent
    radius: Math.min(width, height) / 2
    color: mouseArea.containsPress ? root.colorBgHover : root.effectiveBg
    border.color: root.hovered ? root.colorBorderHover : root.colorBorder
    border.width: 1

    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.InOutQuad
      }
    }
    Behavior on border.color {
      ColorAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.InOutQuad
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      enabled: root.allowClickWhenDisabled || root.enabled
      cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

      onEntered: function () {
        root.entered();
        if (root.tooltipText.length)
          tooltip.isVisible = true;
      }
      onExited: function () {
        root.exited();
        if (root.tooltipText.length)
          tooltip.isVisible = false;
      }
      onPressed: mouse => root.pressed(mouse)

      onReleased: mouse => root.released(mouse)

      onClicked: function (mouse) {
        if (root.tooltipText.length)
          tooltip.isVisible = false;
        if (!root.enabled && !root.allowClickWhenDisabled)
          return;
        root.clicked(mouse);
        if (mouse.button === Qt.LeftButton)
          root.leftClicked();
        else if (mouse.button === Qt.RightButton)
          root.rightClicked();
        else if (mouse.button === Qt.MiddleButton)
          root.middleClicked();
      }
    }

    Text {
      id: iconLabel
      anchors.centerIn: parent
      text: root.icon
      visible: root.icon.length > 0
      color: root.effectiveFg
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.bold: true
      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }
    }
  }

  Tooltip {
    id: tooltip
    text: root.tooltipText
    target: root
  }
}
