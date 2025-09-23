pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Services.Core

WlrLayershell {
  id: layerShell

  required property var modelData

  readonly property var fillModeMap: ({
      "fill": Image.PreserveAspectCrop,
      "fit": Image.PreserveAspectFit,
      "stretch": Image.Stretch,
      "center": Image.Pad,
      "tile": Image.Tile
    })
  property string mode: (modelData && modelData.mode) ? modelData.mode : "fill"
  readonly property int fillMode: fillModeMap[mode] ?? Image.PreserveAspectCrop
  readonly property bool hasRealSize: width > 0 && height > 0
  property real centerX: (modelData && Number.isFinite(modelData.animCenterX)) ? Math.max(0, Math.min(1, modelData.animCenterX)) : 0.5
  property real centerY: (modelData && Number.isFinite(modelData.animCenterY)) ? Math.max(0, Math.min(1, modelData.animCenterY)) : 0.5

  property string currentSrc: (modelData && typeof modelData.wallpaper === "string") ? modelData.wallpaper : ""
  property string pendingSrc: ""

  readonly property real centerPxX: width * centerX
  readonly property real centerPxY: height * centerY
  readonly property real finalDiameter: 2 * Math.hypot(Math.max(centerPxX, width - centerPxX), Math.max(centerPxY, height - centerPxY))
  readonly property int animMs: 741

  function _clamp01(v) {
    return Math.max(0, Math.min(1, Number(v) || 0));
  }

  function applyModelData(md) {
    if (!md)
      return;
    if (typeof md.mode === "string")
      mode = md.mode;
    if (Number.isFinite(md.animCenterX))
      centerX = _clamp01(md.animCenterX);
    if (Number.isFinite(md.animCenterY))
      centerY = _clamp01(md.animCenterY);
    if (typeof md.wallpaper === "string")
      currentSrc = md.wallpaper;
  }

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  screen: (modelData && modelData.name) ? (Quickshell.screens.find(function (s) {
      return s && s.name === modelData.name;
    }) || null) : null

  Image {
    id: baseImg
    anchors.fill: parent
    fillMode: layerShell.fillMode
    source: layerShell.hasRealSize ? layerShell.currentSrc : ""
    sourceSize: layerShell.hasRealSize ? Qt.size(layerShell.width, layerShell.height) : Qt.size(0, 0)
    cache: true
    asynchronous: true
    mipmap: false
    smooth: true
    layer.enabled: false
  }

  ClippingRectangle {
    id: clip
    color: "transparent"
    width: 0
    height: width
    radius: width / 2
    x: Math.round(layerShell.width * layerShell.centerX - width / 2)
    y: Math.round(layerShell.height * layerShell.centerY - height / 2)

    Image {
      id: overlay
      width: layerShell.width
      height: layerShell.height
      x: -Math.round(clip.x)
      y: -Math.round(clip.y)
      fillMode: layerShell.fillMode
      sourceSize: Qt.size(layerShell.width, layerShell.height)
      source: layerShell.pendingSrc
      asynchronous: true
      cache: true                  // + share decoded pixmap
      mipmap: false
      smooth: true
      layer.enabled: false

      onStatusChanged: {
        if (status === Image.Ready && clip.width === 0 && layerShell.pendingSrc) {
          revealAnim.start();
        } else if (status === Image.Error) {
          layerShell.pendingSrc = "";
          clip.width = 0;
        }
      }
    }
  }

  NumberAnimation {
    id: revealAnim
    target: clip
    property: "width"
    from: 0
    to: layerShell.finalDiameter
    duration: layerShell.animMs
    easing.type: Easing.Bezier
    easing.bezierCurve: [0.54, 0.00, 0.20, 1.00]
    onFinished: {
      if (layerShell.pendingSrc) {
        layerShell.currentSrc = layerShell.pendingSrc;
        layerShell.pendingSrc = "";
      }
      clip.width = 0;
    }
  }

  function _setPending(src) {
    const validated = (typeof src === "string" && src) ? src : currentSrc;
    if (validated === currentSrc || overlay.source === validated) {
      // Same image → no reload; just animate transition again
      layerShell.pendingSrc = validated;
      if (overlay.status === Image.Ready) {
        clip.width = 0;
        revealAnim.restart();
      }
      return;
    }
    layerShell.pendingSrc = validated;
  }

  Component.onCompleted: applyModelData(modelData)
  onModelDataChanged: applyModelData(modelData)

  Connections {
    target: WallpaperService

    function onWallpaperChanged(name, path, cx, cy) {
      if (!name || !layerShell.modelData || name !== layerShell.modelData.name)
        return;

      if (revealAnim.running)
        revealAnim.complete();

      if (Number.isFinite(cx))
        layerShell.centerX = layerShell._clamp01(cx);
      if (Number.isFinite(cy))
        layerShell.centerY = layerShell._clamp01(cy);

      const newSrc = (typeof path === "string" && path) ? path : layerShell.currentSrc;

      // Skip overlay if nothing actually changed (startup hydrate)
      if (newSrc === layerShell.currentSrc)
        return;

      layerShell._setPending(newSrc);
      clip.width = 0;
      if (overlay.status === Image.Ready)
        revealAnim.start();
    }
  }
}
