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
    source: layerShell._currentSource
  }

  // Circular reveal clip for animated overlay
  ClippingRectangle {
    id: revealClip

    color: "transparent"
    height: width
    radius: width
    width: 0
    x: layerShell.width * layerShell._centerRelX - revealClip.width / 2
    y: layerShell.height * layerShell._centerRelY - revealClip.width / 2

    // Overlay aligned with output via negative offset against the clip's position
    Image {
      id: overlayWal

      fillMode: layerShell._fillModeFor(layerShell.modelData.mode)
      height: layerShell.height
      source: layerShell._overlaySource
      width: layerShell.width
      x: -revealClip.x
      y: -revealClip.y
    }
    NumberAnimation {
      id: walAnimation

      duration: 650
      easing.type: Easing.InOutQuad
      from: 0
      property: "width"
      target: revealClip
      to: Math.hypot(layerShell.width, layerShell.height)

      onFinished: {
        if (layerShell._overlaySource && layerShell._overlaySource.length > 0) {
          layerShell._currentSource = layerShell._overlaySource;
          layerShell._overlaySource = "";
        }
        revealClip.width = 0;
      }
    }
  }

  // React to wallpaper changes from the service and animate from a random start point
  Connections {
    function onWallpaperChanged(name, path, cx, cy) {
      if (!name || name !== layerShell.modelData.name)
        return;

      layerShell._centerRelX = Math.max(0, Math.min(1, cx));
      layerShell._centerRelY = Math.max(0, Math.min(1, cy));
      layerShell._overlaySource = path || layerShell._currentSource;

      if (walAnimation.running)
        walAnimation.complete();
      revealClip.width = 0;
      walAnimation.start();
    }

    target: WallpaperService
  }
}
