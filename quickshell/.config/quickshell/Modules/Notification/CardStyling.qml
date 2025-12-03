pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.Config

Item {
  id: base

  property color accentColor: Theme.activeColor
  property real radius: Theme.panelRadius

  // Shadow (fast rectangular shadow)
  RectangularShadow {
    anchors.fill: parent
    antialiasing: true
    blur: Theme.shadowBlurLg
    color: Theme.shadowColorStrong
    offset: Qt.vector2d(0, 3)
    radius: base.radius
    spread: 0
  }

  // Background
  Rectangle {
    anchors.fill: parent
    border.color: Theme.borderColor
    border.width: 2
    color: Theme.bgColor
    radius: base.radius
  }

  // Gradient border stroke
  Canvas {
    id: borderCanvas

    anchors.fill: parent

    onHeightChanged: requestPaint()
    onPaint: {
      const ctx = getContext("2d");
      const w = width, h = height, r = base.radius;
      ctx.clearRect(0, 0, w, h);

      ctx.beginPath();
      ctx.moveTo(r, 0);
      ctx.lineTo(w - r, 0);
      ctx.quadraticCurveTo(w, 0, w, r);
      ctx.lineTo(w, h - r);
      ctx.quadraticCurveTo(w, h, w - r, h);
      ctx.lineTo(r, h);
      ctx.quadraticCurveTo(0, h, 0, h - r);
      ctx.lineTo(0, r);
      ctx.quadraticCurveTo(0, 0, r, 0);
      ctx.closePath();

      const grad = ctx.createLinearGradient(0, 0, w, 0);
      grad.addColorStop(0.0, base.accentColor);
      grad.addColorStop(0.15, base.accentColor);
      grad.addColorStop(0.4, Theme.borderColor);
      grad.addColorStop(1.0, Theme.borderColor);

      ctx.lineWidth = 2;
      ctx.strokeStyle = grad;
      ctx.stroke();
    }
    onWidthChanged: requestPaint()

    Connections {
      function onAccentColorChanged() {
        borderCanvas.requestPaint();
      }

      target: base
    }
  }
}
