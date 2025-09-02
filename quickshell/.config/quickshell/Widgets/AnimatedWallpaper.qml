pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Services.Core

WlrLayershell {
  id: layerShell

  // Normalized [0..1] center from service signal
  property real _centerRelX: 0.5
  property real _centerRelY: 0.5

  // Local state to manage animated transitions
  property string _currentSource: layerShell.modelData.wallpaper
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
  screen: Quickshell.screens.find(s => {
    return s && s.name === layerShell.modelData.name;
  }) || null

  Component.onCompleted: {
    layerShell._currentSource = layerShell.modelData.wallpaper;
    // Seed center if provided by service
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
    layer.enabled: true
    layer.mipmap: true
    layer.smooth: true
    mipmap: true
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
      layer.enabled: true
      layer.mipmap: true
      layer.smooth: true
      mipmap: true
      smooth: true
      source: layerShell._overlaySource
      width: layerShell.width
      x: -Math.round(revealClip.x)
      y: -Math.round(revealClip.y)
    }
    // Two-phase animation with a brief pause in the middle for a pronounced hold
    // and a strong acceleration to the end.
    SequentialAnimation {
      id: walAnimation

      // Total duration budget
      property int totalDuration: 2000

      // Helper: compute full target diameter at start time
      function targetDiameter() {
        return 2 * Math.max(Math.hypot(layerShell.width * layerShell._centerRelX, layerShell.height * layerShell._centerRelY), Math.hypot(layerShell.width * (1 - layerShell._centerRelX), layerShell.height * layerShell._centerRelY), Math.hypot(layerShell.width * layerShell._centerRelX, layerShell.height * (1 - layerShell._centerRelY)), Math.hypot(layerShell.width * (1 - layerShell._centerRelX), layerShell.height * (1 - layerShell._centerRelY)));
      }

      onFinished: {
        if (layerShell._overlaySource && layerShell._overlaySource.length > 0) {
          layerShell._currentSource = layerShell._overlaySource;
          layerShell._overlaySource = "";
        }
        revealClip.width = 0;
      }

      // Phase 1: decelerate into the midpoint (longer)
      NumberAnimation {
        duration: Math.round(walAnimation.totalDuration * 0.65)
        easing.type: Easing.OutCubic
        from: 0
        property: "width"
        target: revealClip
        to: walAnimation.targetDiameter() * 0.5
      }

      // Mid pause (cut in half)
      PauseAnimation {
        duration: Math.round(walAnimation.totalDuration * 0.05)
      }

      // Phase 2: aggressive acceleration to completion (1.5x faster -> shorter duration)
      NumberAnimation {
        duration: Math.round(walAnimation.totalDuration * 0.30)
        easing.type: Easing.InQuint
        from: walAnimation.targetDiameter() * 0.5
        property: "width"
        target: revealClip
        to: walAnimation.targetDiameter()
      }
    }
  }

  // React to wallpaper changes from the service and animate from a random start point
  Connections {
    function onWallpaperChanged(name, path, cx, cy) {
      if (!name || name !== layerShell.modelData.name)
        return;

      // Finalize any running animation FIRST so its onFinished applies to the previous state
      // and does not consume the new overlay/center intended for this change.
      if (walAnimation.running)
        walAnimation.complete();

      // Safely update center: if cx/cy are undefined or not numbers, keep previous values.
      if (typeof cx === "number" && isFinite(cx))
        layerShell._centerRelX = Math.max(0, Math.min(1, cx));
      if (typeof cy === "number" && isFinite(cy))
        layerShell._centerRelY = Math.max(0, Math.min(1, cy));

      layerShell._overlaySource = path || layerShell._currentSource;

      revealClip.width = 0;
      walAnimation.start();
    }

    target: WallpaperService
  }
}
