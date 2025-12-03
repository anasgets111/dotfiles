pragma ComponentBehavior: Bound
import QtQuick
import qs.Config

/**
 * IconButton - Circular icon button with hover states and tooltip
 *
 * Size presets: "xs", "sm", "md" (default), "lg", "xl"
 * Shape: "circle" (default), "rounded"
 *
 * Examples:
 *   IconButton { icon: "󰅖" }
 *   IconButton { icon: "󰅖"; size: "sm" }
 *   IconButton { icon: "󰐊"; colorBg: Theme.activeColor }
 *   IconButton { icon: "󰐊"; shape: "rounded"; tooltipText: "Play" }
 */
Item {
  id: root

  // Computed dimensions from size using Theme helper functions
  readonly property int _iconSize: Theme.iconSizeFor(size)
  readonly property int _radius: {
    if (shape === "circle")
      return Math.min(width, height) / 2;
    return Theme.radiusFor(size === "xs" || size === "sm" ? "sm" : size === "xl" ? "lg" : "md");
  }
  readonly property int _size: Theme.controlHeightFor(size)
  property bool allowClickWhenDisabled: false

  // Color customization
  property color colorBg: Theme.inactiveColor
  readonly property color colorBgHover: Theme.onHoverColor
  readonly property color colorBorder: Theme.onHoverColor
  readonly property color colorBorderHover: Theme.onHoverColor
  readonly property color colorFg: Theme.textContrast(colorBg)
  readonly property color colorFgHover: Theme.textContrast(colorBgHover)

  // Computed colors
  readonly property color effectiveBg: !enabled ? colorBg : (hovered ? colorBgHover : colorBg)
  readonly property color effectiveBorderColor: showBorder ? (hovered ? colorBorderHover : colorBorder) : "transparent"
  readonly property color effectiveFg: !enabled ? Theme.textContrast(colorBg) : (hovered ? colorFgHover : colorFg)

  // Behavior
  property bool enabled: true
  readonly property bool hovered: mouseArea.containsMouse && root.enabled

  // Content
  property string icon: ""

  // Shape: "circle", "rounded"
  property string shape: "circle"
  property bool showBorder: true

  // Size preset: "xs", "sm", "md", "lg", "xl"
  property string size: "md"
  property string tooltipText: ""

  signal clicked(var point)
  signal entered
  signal exited

  implicitHeight: _size
  implicitWidth: _size

  onTooltipTextChanged: if (mouseArea.containsMouse && root.tooltipText.length)
    tooltip.isVisible = true

  Rectangle {
    id: bgRect

    anchors.fill: parent
    border.color: root.effectiveBorderColor
    border.width: root.showBorder ? Theme.borderWidthThin : 0
    color: mouseArea.containsPress ? root.colorBgHover : root.effectiveBg
    radius: root._radius

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
      font.family: Theme.fontFamily
      font.pixelSize: root._iconSize
      font.weight: Font.Medium
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
