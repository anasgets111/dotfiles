import QtQuick
import qs.Config

/**
 * OToggle - Obelisk themed toggle switch component
 *
 * Implements a Material Design 3 inspired switch using Theme tokens.
 * Exposes a simple boolean API with hover/press feedback and keyboard support.
 */
Rectangle {
  id: root

  readonly property color _trackDisabled: Qt.rgba(Theme.disabledColor.r, Theme.disabledColor.g, Theme.disabledColor.b, 0.75)
  readonly property color _trackHover: Qt.rgba(Theme.onHoverColor.r, Theme.onHoverColor.g, Theme.onHoverColor.b, 0.65)
  readonly property color _trackOff: Qt.rgba(Theme.textInactiveColor.r, Theme.textInactiveColor.g, Theme.textInactiveColor.b, 0.38)
  readonly property color _trackOn: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.95)
  property bool checked: false
  property bool disabled: false
  property bool hovered: false
  property bool pressed: false
  readonly property real thumbPadding: Math.max(3, Math.round(trackHeight * 0.12))
  readonly property real thumbSize: {
    const baseSize = Math.max(trackHeight - thumbPadding * 2, 10);
    const widthRatio = root.width / (trackHeight * 2.3);
    const sizeBoost = widthRatio > 1.2 ? Math.min(1.15, 0.9 + (widthRatio - 1.2) * 0.35) : 1;
    return Math.min(baseSize * sizeBoost, root.height - thumbPadding * 2);
  }
  readonly property real trackHeight: Math.round(Theme.itemHeight * 0.7)

  signal toggled(bool checked)

  function toggle() {
    if (disabled)
      return;

    root.checked = !root.checked;
    root.toggled(root.checked);
  }

  border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, disabled ? 0.22 : 0.35)
  border.width: 1
  color: root.disabled ? _trackDisabled : (root.checked ? _trackOn : root.hovered ? _trackHover : _trackOff)
  focus: !root.disabled
  implicitHeight: trackHeight
  implicitWidth: Math.round(trackHeight * 2.3)
  opacity: root.disabled ? 0.6 : 1
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

    border.color: root.disabled ? Qt.rgba(Theme.textInactiveColor.r, Theme.textInactiveColor.g, Theme.textInactiveColor.b, 0.35) : Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.4)
    border.width: 1
    color: root.disabled ? Qt.rgba(Theme.textInactiveColor.r, Theme.textInactiveColor.g, Theme.textInactiveColor.b, 0.75) : Qt.rgba(Theme.textActiveColor.r, Theme.textActiveColor.g, Theme.textActiveColor.b, root.pressed ? 0.92 : 1)
    height: root.thumbSize
    radius: height / 2
    scale: root.hovered && !root.disabled ? 1.05 : 1
    width: root.thumbSize
    x: root.checked ? parent.width - width - root.thumbPadding : root.thumbPadding
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
