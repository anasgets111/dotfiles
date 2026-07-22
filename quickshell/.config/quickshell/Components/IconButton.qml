pragma ComponentBehavior: Bound
import QtQuick
import qs.Config

Item {
  id: iconButton

  readonly property bool _canShowTooltip: iconButton.isEnabled && !iconButton.suppressTooltip && iconButton.tooltipText.length > 0
  readonly property int _iconSize: Theme.iconSizeFor(size)
  readonly property int _radius: {
    if (shape === "circle")
      return Math.min(width, height) / 2;
    return size === "xs" || size === "sm" ? Theme.radiusSm : size === "xl" ? Theme.radiusLg : Theme.radiusMd;
  }
  readonly property int _size: Theme.controlHeightFor(size)
  property color colorBg: Theme.glassControlColor
  property color colorBgHover: Theme.glassControlHoverColor
  property color colorBorder: Theme.glassBorderColor
  property color colorBorderHover: Theme.glassBorderHoverColor
  property color colorFg: Theme.textContrast(colorBg)
  property color colorFgHover: Theme.textContrast(colorBgHover)
  readonly property color effectiveBg: !isEnabled ? colorBg : (hovered ? colorBgHover : colorBg)
  readonly property color effectiveBorderColor: showBorder ? (hovered ? colorBorderHover : colorBorder) : "transparent"
  readonly property color effectiveFg: !isEnabled ? Theme.textContrast(colorBg) : (hovered ? colorFgHover : colorFg)
  readonly property bool hovered: mouseArea.containsMouse && iconButton.isEnabled
  property string icon: ""
  property real iconRotation: 0
  property bool isEnabled: true
  property string shape: "circle"
  property bool showBorder: true
  property string size: "md"
  property bool suppressTooltip: false
  property string tooltipText: ""

  signal clicked(var point)
  signal entered
  signal exited

  implicitHeight: _size
  implicitWidth: _size
  opacity: enabled && isEnabled ? 1 : Theme.opacityDisabled

  onIsEnabledChanged: if (!isEnabled && (tooltipLoader.item as Tooltip)?.isVisible)
    (tooltipLoader.item as Tooltip).isVisible = false
  onSuppressTooltipChanged: {
    if (iconButton.suppressTooltip && (tooltipLoader.item as Tooltip)?.isVisible)
      (tooltipLoader.item as Tooltip).isVisible = false;
  }
  onTooltipTextChanged: {
    if ((tooltipLoader.item as Tooltip)?.isVisible && !iconButton._canShowTooltip)
      (tooltipLoader.item as Tooltip).isVisible = false;
  }

  Rectangle {
    id: bgRect

    anchors.fill: parent
    border.color: iconButton.effectiveBorderColor
    border.width: Theme.borderWidthThin
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
      enabled: iconButton.isEnabled
      hoverEnabled: true

      onClicked: function (mouse) {
        if ((tooltipLoader.item as Tooltip)?.isVisible)
          (tooltipLoader.item as Tooltip).isVisible = false;
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
      rotation: iconButton.iconRotation
      text: iconButton.icon
      transformOrigin: Item.Center
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

    onLoaded: (item as Tooltip).isVisible = true
  }
}
