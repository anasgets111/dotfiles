pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Services.Core

WlrLayershell {
  id: layerShell

  property int _animDuration: 3000

  // Normalized [0..1] center from service signal
  property real _centerRelX: 0.5
  property real _centerRelY: 0.5
  property string _currentSource: layerShell.modelData.wallpaper
  property real _finalDiameter: 2 * Math.max(Math.hypot(layerShell.width * layerShell._centerRelX, layerShell.height * layerShell._centerRelY), Math.hypot(layerShell.width * (1 - layerShell._centerRelX), layerShell.height * layerShell._centerRelY), Math.hypot(layerShell.width * layerShell._centerRelX, layerShell.height * (1 - layerShell._centerRelY)), Math.hypot(layerShell.width * (1 - layerShell._centerRelX), layerShell.height * (1 - layerShell._centerRelY)))
  property string _overlaySource: ""

  // Externally provided wallpaper record from WallpaperService.wallpapersArray
  required property var modelData

  function _fillModeFor(mode) {
    switch (mode) {
    case "fill":
      return Image.PreserveAspectCrop;
    case "fit":
      return Image.PreserveAspectFit;
    case "stretch":
      return Image.Stretch;
    case "center":
      return Image.Pad;
    case "tile":
      return Image.Tile;
    default:
      return Image.PreserveAspectCrop;
    }
  }

  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  anchors.top: true
  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  screen: Quickshell.screens.find(s => s && s.name === layerShell.modelData.name) || null

  Component.onCompleted: {
    layerShell._currentSource = layerShell.modelData.wallpaper;
    if (layerShell.modelData.animCenterX !== undefined)
      layerShell._centerRelX = layerShell.modelData.animCenterX;
    if (layerShell.modelData.animCenterY !== undefined)
      layerShell._centerRelY = layerShell.modelData.animCenterY;
  }

  // Base wallpaper (currently visible)
  Image {
    id: baseWal

    anchors.fill: parent
    fillMode: layerShell._fillModeFor(layerShell.modelData.mode)
    layer.enabled: false
    layer.mipmap: false
    layer.smooth: true
    cache: false
    mipmap: false
    smooth: true
    source: layerShell._currentSource
  }

  // Circular reveal clip for animated overlay
  ClippingRectangle {
    id: revealClip

    color: "transparent"
    height: width
    radius: width / 2
    width: 0
    x: Math.round(layerShell.width * layerShell._centerRelX - revealClip.width / 2)
    y: Math.round(layerShell.height * layerShell._centerRelY - revealClip.width / 2)

    // Overlay aligned with output via negative offset against the clip's position
    Image {
      id: overlayWal

      fillMode: layerShell._fillModeFor(layerShell.modelData.mode)
      height: layerShell.height
      layer.enabled: false
      layer.mipmap: false
      layer.smooth: true
      asynchronous: true
      cache: false
      mipmap: false
      smooth: true
      source: layerShell._overlaySource
      width: layerShell.width
      x: -Math.round(revealClip.x)
      y: -Math.round(revealClip.y)

      onStatusChanged: {
        if (status === Image.Ready && revealClip.width === 0)
          walAnimation.start();
      }
    }
  }
  NumberAnimation {
    id: walAnimation

    duration: layerShell._animDuration
    easing.bezierCurve: [0.54, 0.00, 0.20, 1.00]
    easing.type: Easing.Bezier
    from: 0
    property: "width"
    target: revealClip
    to: layerShell._finalDiameter

    onFinished: {
      if (layerShell._overlaySource && layerShell._overlaySource.length > 0) {
        layerShell._currentSource = layerShell._overlaySource;
        layerShell._overlaySource = "";
      }
      revealClip.width = 0;
    }
  }
  Connections {
    function onWallpaperChanged(name, path, cx, cy) {
      if (!name || name !== layerShell.modelData.name)
        return;

      if (walAnimation.running)
        walAnimation.complete();
      if (typeof cx === "number" && isFinite(cx))
        layerShell._centerRelX = Math.max(0, Math.min(1, cx));
      if (typeof cy === "number" && isFinite(cy))
        layerShell._centerRelY = Math.max(0, Math.min(1, cy));
      layerShell._overlaySource = path || layerShell._currentSource;
      revealClip.width = 0;
      if (overlayWal.status === Image.Ready)
        walAnimation.start();
    }

    target: WallpaperService
  }
}
