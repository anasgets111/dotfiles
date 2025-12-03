import QtQuick
import qs.Config

/**
 * OToggle - Obelisk themed toggle switch component
 *
 * Implements a Material Design 3 inspired switch using Theme tokens.
 * Exposes a simple boolean API with hover/press feedback and keyboard support.
 *
 * Size presets: "sm", "md" (default), "lg"
 *
 * Examples:
 *   OToggle { checked: true }
 *   OToggle { size: "sm"; checked: settings.enabled; onToggled: settings.enabled = checked }
 *   OToggle { size: "lg"; disabled: true }
 */
Rectangle {
  id: root

  readonly property int _thumbPadding: Math.max(3, Math.round(_trackHeight * 0.12))
  readonly property real _thumbSize: {
    const baseSize = Math.max(_trackHeight - _thumbPadding * 2, 10);
    const widthRatio = root.width / (_trackHeight * 2.3);
    const sizeBoost = widthRatio > 1.2 ? Math.min(1.15, 0.9 + (widthRatio - 1.2) * 0.35) : 1;
    return Math.min(baseSize * sizeBoost, root.height - _thumbPadding * 2);
  }

  // Track colors
  readonly property color _trackDisabled: Theme.withOpacity(Theme.disabledColor, 0.75)

  // Computed dimensions from size
  readonly property int _trackHeight: {
    switch (size) {
    case "sm":
      return Math.round(Theme.controlHeightSm * 0.65);
    case "md":
      return Math.round(Theme.controlHeightMd * 0.65);
    case "lg":
      return Math.round(Theme.controlHeightLg * 0.65);
    default:
      return Math.round(Theme.controlHeightMd * 0.65);
    }
  }
  readonly property color _trackHover: Theme.withOpacity(Theme.onHoverColor, 0.65)
  readonly property color _trackOff: Theme.withOpacity(Theme.textInactiveColor, 0.38)
  readonly property color _trackOn: Theme.activeFull
  readonly property int _trackWidth: Math.round(_trackHeight * 2.3)

  // State
  property bool checked: false
  property bool disabled: false
  property bool hovered: false
  property bool pressed: false

  // Size preset: "sm", "md", "lg"
  property string size: "md"

  signal toggled(bool checked)

  function toggle() {
    if (disabled)
      return;
    root.checked = !root.checked;
    root.toggled(root.checked);
  }

  border.color: disabled ? Theme.borderSubtle : Theme.borderLight
  border.width: Theme.borderWidthThin
  color: root.disabled ? _trackDisabled : (root.checked ? _trackOn : root.hovered ? _trackHover : _trackOff)
  focus: !root.disabled
  implicitHeight: _trackHeight
  implicitWidth: _trackWidth
  opacity: root.disabled ? Theme.opacitySolid : 1
  radius: height / 2

  Behavior on color {
    ColorAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.OutCubic
    }
  }

  Keys.onPressed: event => {
    if (root.disabled)
      return;
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.toggle();
      event.accepted = true;
    }
  }

  Rectangle {
    id: thumb

    border.color: root.disabled ? Theme.textDisabled : Theme.borderMedium
    border.width: Theme.borderWidthThin
    color: root.disabled ? Theme.withOpacity(Theme.textInactiveColor, 0.75) : Theme.withOpacity(Theme.textActiveColor, root.pressed ? 0.92 : 1)
    height: root._thumbSize
    radius: height / 2
    scale: root.hovered && !root.disabled ? 1.05 : 1
    width: root._thumbSize
    x: root.checked ? parent.width - width - root._thumbPadding : root._thumbPadding
    y: (parent.height - height) / 2

    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.OutQuad
      }
    }
    Behavior on x {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.OutQuad
      }
    }
  }

  MouseArea {
    id: toggleArea

    anchors.fill: parent
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: !root.disabled
    hoverEnabled: true

    onCanceled: root.pressed = false
    onClicked: root.toggle()
    onEntered: root.hovered = true
    onExited: {
      root.hovered = false;
      root.pressed = false;
    }
    onPressed: root.pressed = true
    onReleased: root.pressed = false
  }
}
