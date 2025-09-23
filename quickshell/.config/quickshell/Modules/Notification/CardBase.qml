pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import qs.Config

Control {
  id: base
  // Public API
  property color accentColor: Theme.activeColor
  padding: 10
  property real radius: Theme.panelRadius
  // slide visibility driver
  property bool shown: true
  // optional progress child height if needed by consumer
  default property alias cardChildren: content.data

  // Use childrenRect of content container for sizing so background covers all children
  implicitWidth: Math.max(200, content.childrenRect.width + padding * 2)
  implicitHeight: content.childrenRect.height + padding * 2
  // Delayed activation ensures we start off-screen then animate in
  property bool _animReady: false
  x: !_animReady ? width + Theme.popupOffset : (shown ? 0 : width + Theme.popupOffset)

  Behavior on x {
    NumberAnimation {
      duration: Theme.animationDuration * 1.4
      easing.type: Easing.OutCubic
    }
  }

  Component.onCompleted: Qt.callLater(function () {
    _animReady = true;
  })

  // Background + shadow container
  Rectangle {
    id: bg
    anchors.fill: parent
    radius: base.radius
    color: Theme.bgColor
    border.width: 2
    // Fallback flat border color (right / bottom edges) – left edge emphasized by gradient stroke below
    border.color: Theme.borderColor
    layer.enabled: true
    layer.smooth: true
    layer.effect: DropShadow {
      horizontalOffset: 0
      verticalOffset: 3
      radius: 24
      samples: 32
      color: Qt.rgba(0, 0, 0, 0.55)
      transparentBorder: true
    }
  }

  // Gradient border overlay (accent on left fading to normal border color)
  Canvas {
    id: gradientBorder
    anchors.fill: parent
    antialiasing: true
    opacity: 1
    onPaint: {
      const ctx = getContext("2d");
      const w = width;
      const h = height;
      ctx.clearRect(0, 0, w, h);
      const r = Math.max(0, base.radius - 0.5);

      function roundRect(x, y, w, h, r) {
        const rr = Math.min(r, Math.min(w, h) / 2);
        ctx.beginPath();
        ctx.moveTo(x + rr, y);
        ctx.lineTo(x + w - rr, y);
        ctx.quadraticCurveTo(x + w, y, x + w, y + rr);
        ctx.lineTo(x + w, y + h - rr);
        ctx.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
        ctx.lineTo(x + rr, y + h);
        ctx.quadraticCurveTo(x, y + h, x, y + h - rr);
        ctx.lineTo(x, y + rr);
        ctx.quadraticCurveTo(x, y, x + rr, y);
        ctx.closePath();
      }

      // Stroke gradient: strong accent on extreme left -> fade into normal border color
      const grad = ctx.createLinearGradient(0, 0, w, 0);
      grad.addColorStop(0.0, base.accentColor);
      grad.addColorStop(0.12, base.accentColor);
      grad.addColorStop(0.28, Theme.borderColor);
      grad.addColorStop(1.0, Theme.borderColor);

      ctx.lineWidth = 2;
      ctx.strokeStyle = grad;
      // Inset by 1px to keep 2px stroke fully inside bounds
      roundRect(1, 1, w - 2, h - 2, r);
      ctx.stroke();
    }
    Connections {
      target: base
      function onAccentColorChanged() {
        gradientBorder.requestPaint();
      }
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
  }

  Item {
    id: inset
    anchors.fill: parent
    anchors.margins: base.padding
  }
  Item {
    id: content
    anchors.fill: inset
  }
}
