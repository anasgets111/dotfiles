pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Config

Item {
  id: cornerShape

  property color color: "black"
  readonly property real effectiveRadius: Math.max(0, Math.min(cornerShape.radius, Math.min(cornerShape.width, cornerShape.height)))
  property int orientation: 0 // 0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right
  property int radius: Theme.radiusLg
  readonly property Region region: Region {
    item: cornerShape

    regions: Region {
      readonly property int cutoutSize: cornerShape.effectiveRadius * 2 + 4

      height: cutoutSize
      intersection: Intersection.Subtract
      shape: RegionShape.Ellipse
      width: cutoutSize
      x: cornerShape.orientation === 0 || cornerShape.orientation === 2 ? -2 : cornerShape.width - cutoutSize + 2
      y: cornerShape.orientation < 2 ? -2 : cornerShape.height - cutoutSize + 2
    }
  }

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
      const r = cornerShape.effectiveRadius;
      const k = 0.552285;
      ctx.reset();
      ctx.beginPath();
      ctx.rect(0, 0, w, h);
      ctx.closePath();
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
      // Even-odd clipping subtracts the corner curve from the full rectangle.
      ctx.clip("evenodd");
      ctx.fillStyle = cornerShape.color;
      ctx.fillRect(0, 0, w, h);
    }
    onWidthChanged: requestPaint()
  }
}
