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
  id: iconButton

  readonly property bool _canShowTooltip: iconButton.isEnabled && !iconButton.suppressTooltip && iconButton.tooltipText.length > 0

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
  readonly property color effectiveBg: !isEnabled ? colorBg : (hovered ? colorBgHover : colorBg)
  readonly property color effectiveBorderColor: showBorder ? (hovered ? colorBorderHover : colorBorder) : "transparent"
  readonly property color effectiveFg: !isEnabled ? Theme.textContrast(colorBg) : (hovered ? colorFgHover : colorFg)
  readonly property bool hovered: mouseArea.containsMouse && iconButton.isEnabled

  // Content
  property string icon: ""

  // Behavior
  property bool isEnabled: true

  // Shape: "circle", "rounded"
  property string shape: "circle"
  property bool showBorder: true

  // Size preset: "xs", "sm", "md", "lg", "xl"
  property string size: "md"
  property bool suppressTooltip: false
  property string tooltipText: ""

  signal clicked(var point)
  signal entered
  signal exited

  implicitHeight: _size
  implicitWidth: _size

  onIsEnabledChanged: if (!isEnabled && tooltipLoader.item?.isVisible)
    tooltipLoader.item.isVisible = false
  onSuppressTooltipChanged: {
    if (iconButton.suppressTooltip && tooltipLoader.item?.isVisible)
      tooltipLoader.item.isVisible = false;
  }
  onTooltipTextChanged: {
    if (tooltipLoader.item?.isVisible && !iconButton._canShowTooltip)
      tooltipLoader.item.isVisible = false;
  }

  Rectangle {
    id: bgRect

    anchors.fill: parent
    border.color: iconButton.effectiveBorderColor
    border.width: iconButton.showBorder ? Theme.borderWidthThin : 0
    color: mouseArea.containsPress ? iconButton.colorBgHover : iconButton.effectiveBg
    radius: iconButton._radius

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
      cursorShape: iconButton.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: iconButton.allowClickWhenDisabled || iconButton.isEnabled
      hoverEnabled: true

      onClicked: function (mouse) {
        if (!iconButton.isEnabled && !iconButton.allowClickWhenDisabled)
          return;
        if (tooltipLoader.item?.isVisible)
          tooltipLoader.item.isVisible = false;
        iconButton.clicked(mouse);
      }
      onEntered: {
        iconButton.entered();
      }
      onExited: {
        iconButton.exited();
      }
    }

    Text {
      id: iconLabel

      anchors.centerIn: parent
      color: iconButton.effectiveFg
      font.family: Theme.fontFamily
      font.pixelSize: iconButton._iconSize
      font.weight: Font.Medium
      horizontalAlignment: Text.AlignHCenter
      text: iconButton.icon
      verticalAlignment: Text.AlignVCenter
      visible: iconButton.icon.length > 0

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }
    }
  }

  Loader {
    id: tooltipLoader

    active: iconButton.hovered && iconButton._canShowTooltip

    sourceComponent: Tooltip {
      target: iconButton
      text: iconButton.tooltipText
    }

    onLoaded: item.isVisible = true
  }
}
