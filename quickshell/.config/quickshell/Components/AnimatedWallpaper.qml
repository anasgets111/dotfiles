pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Services.Core

WlrLayershell {
  id: layerShell

  // Model input (provided by Variants delegate)
  required property var modelData

  // Enum mapping local to delegate
  readonly property var _fillModeMap: ({
      "fill": Image.PreserveAspectCrop,
      "fit": Image.PreserveAspectFit,
      "stretch": Image.Stretch,
      "center": Image.Pad,
      "tile": Image.Tile
    })
  // Track current mode locally so it can be updated reactively
  // Guard for early init when modelData might be undefined
  property string _mode: (modelData && modelData.mode) ? modelData.mode : "fill"
  readonly property int _fillMode: _fillModeMap[_mode] ?? Image.PreserveAspectCrop

  // Animation center normalized [0..1]
  property real _centerRelX: (modelData && Number.isFinite(modelData.animCenterX)) ? modelData.animCenterX : 0.5
  property real _centerRelY: (modelData && Number.isFinite(modelData.animCenterY)) ? modelData.animCenterY : 0.5

  // Active and pending sources for cross-fade/reveal
  property string _currentSource: (modelData && typeof modelData.wallpaper === "string") ? modelData.wallpaper : ""
  property string _pendingSource: ""

  // Geometry-derived reveal metrics
  readonly property real _centerPxX: width * _centerRelX
  readonly property real _centerPxY: height * _centerRelY
  readonly property real _maxDx: Math.max(_centerPxX, width - _centerPxX)
  readonly property real _maxDy: Math.max(_centerPxY, height - _centerPxY)
  readonly property real _finalDiameterPx: 2 * Math.hypot(_maxDx, _maxDy)

  // Timing
  readonly property int _animDurationMs: 3000

  function _clamp01(v) {
    return Math.max(0, Math.min(1, v));
  }

  // Window placement
  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }
  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  screen: (modelData && modelData.name) ? (Quickshell.screens.find(s => s && s.name === modelData.name) || null) : null

  // Base wallpaper (visible after animation completes)
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

    // Overlay aligned with output via negative offset
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
      if (!name || !layerShell.modelData || name !== layerShell.modelData.name)
        return;

      if (revealAnim.running)
        revealAnim.complete();

      if (Number.isFinite(cx))
        layerShell._centerRelX = layerShell._clamp01(cx);
      if (Number.isFinite(cy))
        layerShell._centerRelY = layerShell._clamp01(cy);

      const newSrc = (typeof path === "string" && path !== "") ? path : layerShell._currentSource;

      // Force reload if cache would reuse same URL instance
      if (overlayWal.source === newSrc) {
        layerShell._pendingSource = "";
        // micro-jitter the URL to ensure reload without enabling cache
        layerShell._pendingSource = newSrc + ((newSrc.indexOf("?") >= 0) ? "&" : "?") + "ts=" + Date.now();
      } else {
        layerShell._pendingSource = newSrc;
      }

      reveal.width = 0;

      if (overlayWal.status === Image.Ready) {
        revealAnim.start();
      }
    // else: will start from overlayWal.onStatusChanged
    }

    function onModeChanged(name, mode) {
      if (!name || !layerShell.modelData || name !== layerShell.modelData.name)
        return;
      if (typeof mode === "string" && mode !== "")
        layerShell._mode = mode;
    }
  }
}
