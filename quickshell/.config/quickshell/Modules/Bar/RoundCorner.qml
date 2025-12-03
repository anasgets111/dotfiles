import QtQuick
import qs.Config

Item {
  id: cornerShape

  property color color: "black"
  property bool invertH: false
  property bool invertV: false
  property int orientation: 0 // 0=TOP_LEFT, 1=TOP_RIGHT, 2=BOTTOM_LEFT, 3=BOTTOM_RIGHT
  property int radius: Theme.radiusLg

  height: Theme.panelHeight
  width: Theme.panelHeight

  Canvas {
    anchors.fill: parent

    Component.onCompleted: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      const ctx = getContext("2d");
      const w = width;
      const h = height;
      const r = Math.max(0, Math.min(cornerShape.radius, Math.min(w, h)));
      const k = 0.552285;
      ctx.reset();
      ctx.save();
      ctx.translate(cornerShape.invertH ? w : 0, cornerShape.invertV ? h : 0);
      ctx.scale(cornerShape.invertH ? -1 : 1, cornerShape.invertV ? -1 : 1);
      // draw full rect
      ctx.beginPath();
      ctx.rect(0, 0, w, h);
      ctx.closePath();
      // draw quarter-circle as negative cutout
      ctx.beginPath();
      switch (cornerShape.orientation) {
      case 0:
        ctx.moveTo(0, r);
        ctx.lineTo(0, 0);
        ctx.lineTo(r, 0);
        ctx.bezierCurveTo(r * (1 - k), 0, 0, r * (1 - k), 0, r);
        break;
      case 1:
        ctx.moveTo(w - r, 0);
        ctx.lineTo(w, 0);
        ctx.lineTo(w, r);
        ctx.bezierCurveTo(w, r * (1 - k), w - r * (1 - k), 0, w - r, 0);
        break;
      case 2:
        ctx.moveTo(0, h - r);
        ctx.lineTo(0, h);
        ctx.lineTo(r, h);
        ctx.bezierCurveTo(r * (1 - k), h, 0, h - r * (1 - k), 0, h - r);
        break;
      case 3:
        ctx.moveTo(w - r, h);
        ctx.lineTo(w, h);
        ctx.lineTo(w, h - r);
        ctx.bezierCurveTo(w, h - r * (1 - k), w - r * (1 - k), h, w - r, h);
        break;
      }
      ctx.closePath();
      ctx.clip("evenodd"); // <-- subtracts the corner curve from the rectangle
      // fill remaining shape
      ctx.fillStyle = cornerShape.color;
      ctx.fillRect(0, 0, w, h);
      ctx.restore();
    }
    onWidthChanged: requestPaint()
  }
}
