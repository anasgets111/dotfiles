// NormalizedSlider.qml
pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Item {
  id: slider

  // Public API
  property real value: 0.0     // 0..1
  property int steps: 0        // 0 => continuous; >0 => stepped
  property bool interactive: true
  property real wheelStep: 0.05
  property int animMs: Theme.animationDuration

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

  // Optional visual: show the same FillBar as a track
  FillBar {
    progress: slider.dragging ? slider.pending : slider.value
    fillColor: Theme.activeColor
    radius: Theme.itemRadius
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
