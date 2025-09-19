pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Services.Core

WlrLayershell {
  id: layerShell

  // --- readonly computed values and helpers ---
  readonly property var _fillModeMap: ({
      "fill": Image.PreserveAspectCrop,
      "fit": Image.PreserveAspectFit,
      "stretch": Image.Stretch,
      "center": Image.Pad,
      "tile": Image.Tile
    })
  readonly property int _fillMode: _fillModeMap[modelData.mode] ?? Image.PreserveAspectCrop

  readonly property real _centerPxX: width * _centerRelX
  readonly property real _centerPxY: height * _centerRelY
  readonly property real _maxDx: Math.max(_centerPxX, width - _centerPxX)
  readonly property real _maxDy: Math.max(_centerPxY, height - _centerPxY)
  readonly property real _finalDiameterPx: 2 * Math.hypot(_maxDx, _maxDy)

  function _clamp01(v) {
    return Math.max(0, Math.min(1, v));
  }

  // --- state ---
  // Normalized [0..1] animation center, hydrated from modelData
  property real _centerRelX: modelData.animCenterX ?? 0.5
  property real _centerRelY: modelData.animCenterY ?? 0.5

  // active wallpaper and pending overlay during animation
  property string _currentSource: modelData.wallpaper
  property string _pendingSource: ""

  readonly property int _animDurationMs: 3000

  // Externally provided wallpaper record from WallpaperService.wallpapersArray
  required property var modelData

  // window placement
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  anchors.top: true
  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  screen: Quickshell.screens.find(s => s && s.name === modelData.name) || null

  // Base wallpaper (currently visible)
  Image {
    id: baseWal
    anchors.fill: parent
    fillMode: layerShell._fillMode
    sourceSize: Qt.size(layerShell.width, layerShell.height)
    source: layerShell._currentSource
    cache: false
    mipmap: false
    smooth: true
    layer.enabled: false
  }

  // Circular reveal clip for animated overlay
  ClippingRectangle {
    id: reveal
    color: "transparent"
    width: 0
    height: width
    radius: width / 2
    x: Math.round(layerShell.width * layerShell._centerRelX - width / 2)
    y: Math.round(layerShell.height * layerShell._centerRelY - height / 2)

    // Overlay aligned with output via negative offset against the clip's position
    Image {
      id: overlayWal
      width: layerShell.width
      height: layerShell.height
      x: -Math.round(reveal.x)
      y: -Math.round(reveal.y)

      fillMode: layerShell._fillMode
      sourceSize: Qt.size(layerShell.width, layerShell.height)
      source: layerShell._pendingSource
      asynchronous: true
      cache: false
      mipmap: false
      smooth: true
      layer.enabled: false

      onStatusChanged: {
        if (status === Image.Ready && reveal.width === 0 && layerShell._pendingSource && layerShell._pendingSource.length > 0)
          revealAnim.start();
      }
    }
  }

  NumberAnimation {
    id: revealAnim
    target: reveal
    property: "width"
    from: 0
    to: layerShell._finalDiameterPx
    duration: layerShell._animDurationMs
    easing.type: Easing.Bezier
    easing.bezierCurve: [0.54, 0.00, 0.20, 1.00]
    onFinished: {
      if (layerShell._pendingSource && layerShell._pendingSource.length > 0) {
        layerShell._currentSource = layerShell._pendingSource;
        layerShell._pendingSource = "";
      }
      reveal.width = 0;
    }
  }

  Connections {
    target: WallpaperService
    function onWallpaperChanged(name, path, cx, cy) {
      if (!name || name !== layerShell.modelData.name)
        return;

      if (revealAnim.running)
        revealAnim.complete();

      if (Number.isFinite(cx))
        layerShell._centerRelX = layerShell._clamp01(cx);
      if (Number.isFinite(cy))
        layerShell._centerRelY = layerShell._clamp01(cy);

      const newSrc = path || layerShell._currentSource;
      layerShell._pendingSource = newSrc;
      reveal.width = 0;

      if (overlayWal.status === Image.Ready) {
        // Rebind to force reload if the same URL instance is reused by the image cache
        if (overlayWal.source === newSrc) {
          layerShell._pendingSource = "";
          layerShell._pendingSource = newSrc;
        }
        revealAnim.start();
      }
    }
  }
}
