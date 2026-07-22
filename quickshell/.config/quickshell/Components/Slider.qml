pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Config

Item {
  id: slider

  property real __wheelAccum: 0
  property int animMs: Theme.animationDuration
  property bool dragging: false
  property color fillColor: Theme.activeColor
  property color headroomColor: Theme.onHoverColor
  property bool interactive: true
  property real pending: value
  property real radius: Theme.itemRadius
  property real splitAt: 1.0 // normalized; 1 disables the headroom segment
  property int steps: 0 // 0 is continuous

  property real value: 0.0 // 0..1
  property real wheelStep: 0.05

  signal changing(real v)
  signal committed(real v)

  function clamp01(v) {
    return Math.max(0, Math.min(1, v));
  }
  function commit(v) {
    const vv = step(clamp01(v));
    slider.value = vv;
    slider.committed(vv);
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

  Item {
    id: track

    readonly property real eff: Math.max(0, Math.min(1, slider.dragging ? slider.pending : slider.value))
    readonly property real s: Math.max(0, Math.min(1, slider.splitAt))

    anchors.fill: parent

    FillBar {
      anchors.fill: parent
      animMs: slider.animMs
      fillColor: slider.fillColor
      progress: track.eff
      radius: slider.radius
    }
    ClippingRectangle {
      anchors.fill: parent
      color: "transparent"
      radius: slider.radius

      Rectangle {
        color: slider.headroomColor
        width: parent.width * Math.max(0, track.eff - track.s)
        x: parent.width * track.s

        Behavior on width {
          NumberAnimation {
            duration: slider.animMs
            easing.type: Easing.InOutQuad
          }
        }

        anchors {
          bottom: parent.bottom
          top: parent.top
        }
      }
    }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: slider.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: slider.interactive
    hoverEnabled: true

    onPositionChanged: e => {
      if (slider.dragging)
        slider.updateFromX(e.x);
    }
    onPressed: e => {
      slider.dragging = true;
      slider.updateFromX(e.x);
    }
    onReleased: () => {
      if (!slider.dragging)
        return;
      slider.dragging = false;
      slider.commit(slider.pending);
    }
    onWheel: e => {
      // angleDelta uses 120 units per wheel notch.
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
