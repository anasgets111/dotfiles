pragma ComponentBehavior: Bound
import QtQuick
import qs.Config

Item {
  id: root

  property bool allowClickWhenDisabled: false
  property color colorBg: Theme.inactiveColor
  readonly property color colorBgHover: Theme.onHoverColor
  readonly property color colorBorder: Theme.onHoverColor
  readonly property color colorBorderHover: Theme.onHoverColor
  readonly property color colorFg: Theme.textContrast(colorBg)
  readonly property color colorFgHover: Theme.textContrast(colorBgHover)
  readonly property color effectiveBg: !enabled ? colorBg : (hovered ? colorBgHover : colorBg)
  readonly property color effectiveBorderColor: showBorder ? (hovered ? colorBorderHover : colorBorder) : "transparent"
  readonly property color effectiveFg: !enabled ? Theme.textContrast(colorBg) : (hovered ? colorFgHover : colorFg)
  property bool enabled: true
  property bool hovered: mouseArea.containsMouse && root.enabled
  property string icon: ""
  property bool showBorder: true
  property string tooltipText: ""

  signal clicked(var point)
  signal entered
  signal exited

  implicitHeight: Theme.itemHeight
  implicitWidth: Theme.itemHeight

  onTooltipTextChanged: if (mouseArea.containsMouse && root.tooltipText.length)
    tooltip.isVisible = true

  Rectangle {
    id: bgRect

    anchors.fill: parent
    border.color: root.effectiveBorderColor
    border.width: root.showBorder ? 1 : 0
    color: mouseArea.containsPress ? root.colorBgHover : root.effectiveBg
    radius: Math.min(width, height) / 2

    Behavior on border.color {
      ColorAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.InOutQuad
      }
    }
    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.InOutQuad
      }
    }

    MouseArea {
      id: mouseArea

      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      anchors.fill: parent
      cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: root.allowClickWhenDisabled || root.enabled
      hoverEnabled: true

      onClicked: function (mouse) {
        if (!root.enabled && !root.allowClickWhenDisabled)
          return;
        root.clicked(mouse);
      }
      onEntered: {
        root.entered();
        if (root.tooltipText.length)
          tooltip.isVisible = true;
      }
      onExited: {
        root.exited();
        if (tooltip.isVisible)
          tooltip.isVisible = false;
      }
    }

    Text {
      id: iconLabel

      anchors.centerIn: parent
      color: root.effectiveFg
      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      horizontalAlignment: Text.AlignHCenter
      text: root.icon
      verticalAlignment: Text.AlignVCenter
      visible: root.icon.length > 0

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

    target: root
    text: root.tooltipText
  }
}
