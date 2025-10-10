pragma ComponentBehavior: Bound
import QtQuick
import qs.Config

Item {
  id: root

  property string icon: ""
  property string tooltipText: ""
  property bool enabled: true
  property bool allowClickWhenDisabled: false
  property bool showBorder: true
  property bool hovered: mouseArea.containsMouse && root.enabled
  property color colorBg: Theme.inactiveColor
  readonly property color colorBgHover: Theme.onHoverColor
  readonly property color colorFg: Theme.textContrast(colorBg)
  readonly property color colorFgHover: Theme.textContrast(colorBgHover)
  readonly property color colorBorder: Theme.onHoverColor
  readonly property color colorBorderHover: Theme.onHoverColor
  readonly property color effectiveBg: !enabled ? colorBg : (hovered ? colorBgHover : colorBg)
  readonly property color effectiveFg: !enabled ? Theme.textContrast(colorBg) : (hovered ? colorFgHover : colorFg)
  readonly property color effectiveBorderColor: showBorder ? (hovered ? colorBorderHover : colorBorder) : "transparent"

  implicitWidth: Theme.itemHeight
  implicitHeight: Theme.itemHeight

  signal clicked(var point)
  signal entered
  signal exited

  Rectangle {
    id: bgRect
    anchors.fill: parent
    radius: Math.min(width, height) / 2
    color: mouseArea.containsPress ? root.colorBgHover : root.effectiveBg
    border.color: root.effectiveBorderColor
    border.width: root.showBorder ? 1 : 0

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
      onClicked: function (mouse) {
        if (!root.enabled && !root.allowClickWhenDisabled)
          return;
        root.clicked(mouse);
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

  onTooltipTextChanged: if (mouseArea.containsMouse && root.tooltipText.length)
    tooltip.isVisible = true
}
