pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Config

Item {
  id: slider

  // Public API
  property real value: 0.0     // 0..1
  property int steps: 0        // 0 => continuous; >0 => stepped
  property bool interactive: true
  property real wheelStep: 0.05
  property int animMs: Theme.animationDuration
  // Visual customization
  property color fillColor: Theme.activeColor        // base fill color (0..splitAt)
  property color headroomColor: Theme.onHoverColor   // color for segment beyond splitAt
  property real splitAt: 1.0                         // normalized split (0..1). 1.0 => single color
  property real radius: Theme.itemRadius

  signal changing(real v)      // while dragging
  signal committed(real v)     // on release or wheel

  anchors.fill: parent

  // Internal
  property bool dragging: false
  property real pending: value
  property real __wheelAccum: 0

  function clamp01(v) {
    return Math.max(0, Math.min(1, v));
  }
  function step(v) {
    if (steps <= 0)
      return v;
    const s = Math.max(1, steps);
    return Math.round(v * s) / s;
  }
  function updateFromX(x) {
    const raw = clamp01(x / width);
    pending = step(raw);
    slider.changing(pending);
  }
  function commit(v) {
    const vv = step(clamp01(v));
    slider.value = vv;
    slider.committed(vv);
  }

  // Visual track: two-tone fill (0..splitAt) and (splitAt..1)
  Item {
    id: track
    anchors.fill: parent

    readonly property real eff: Math.max(0, Math.min(1, slider.dragging ? slider.pending : slider.value))
    readonly property real s: Math.max(0, Math.min(1, slider.splitAt))
    readonly property real basePart: Math.min(eff, s)

    // Base segment (0 .. eff). We overlay headroom on top to avoid a seam.
    FillBar {
      anchors.fill: parent
      progress: track.eff
      fillColor: slider.fillColor
      radius: slider.radius
      animMs: slider.animMs
    }

    // Excess segment (s .. eff) drawn as an overlay within a full-width clipping rect
    // to avoid rounding at the internal split boundary
    ClippingRectangle {
      anchors.fill: parent
      color: "transparent"
      radius: slider.radius

      Rectangle {
        anchors {
          top: parent.top
          bottom: parent.bottom
        }
        x: parent.width * track.s
        width: parent.width * Math.max(0, track.eff - track.s)
        color: slider.headroomColor

        Behavior on width {
          NumberAnimation {
            duration: slider.animMs
            easing.type: Easing.InOutQuad
          }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: slider.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: slider.interactive
    hoverEnabled: true

    onPressed: e => {
      slider.dragging = true;
      slider.updateFromX(e.x);
    }
    onPositionChanged: e => {
      if (slider.dragging)
        slider.updateFromX(e.x);
    }
    onReleased: () => {
      if (!slider.dragging)
        return;
      slider.dragging = false;
      slider.commit(slider.pending);
    }
    onWheel: e => {
      // Pixel if available, else angle (120 per notch)
      const hasPixel = !!(e.pixelDelta && e.pixelDelta.y);
      const eff = hasPixel ? e.pixelDelta.y : e.angleDelta.y;
      if (!eff || Math.abs(eff) < 1) {
        e.accepted = true;
        return;
      }
      const unit = hasPixel ? 50.0 : 120.0;
      slider.__wheelAccum += eff;
      const whole = Math.trunc(slider.__wheelAccum / unit);
      if (whole !== 0) {
        slider.__wheelAccum -= whole * unit;
        slider.commit(slider.value + whole * slider.wheelStep);
      }
      e.accepted = true;
    }
  }
}
