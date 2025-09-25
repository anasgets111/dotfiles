pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Services.Core

WlrLayershell {
  id: root

  required property var modelData

  property string displayMode: (modelData && typeof modelData.mode === "string") ? modelData.mode : "fill"
  readonly property int fillMode: displayMode === "fit" ? Image.PreserveAspectFit : displayMode === "stretch" ? Image.Stretch : displayMode === "center" ? Image.Pad : displayMode === "tile" ? Image.Tile : Image.PreserveAspectCrop

  property real centerXRatio: (modelData && Number.isFinite(modelData.animCenterX)) ? Math.max(0, Math.min(1, modelData.animCenterX)) : 0.5
  property real centerYRatio: (modelData && Number.isFinite(modelData.animCenterY)) ? Math.max(0, Math.min(1, modelData.animCenterY)) : 0.5

  property url currentUrl: (modelData && typeof modelData.wallpaper === "string") ? modelData.wallpaper : ""
  property url pendingUrl: ""

  readonly property bool hasRealSize: width > 0 && height > 0
  readonly property real pixelRatio: screen ? screen.devicePixelRatio : 1
  readonly property real revealDiameter: {
    const cx = width * centerXRatio, cy = height * centerYRatio;
    return 2 * Math.hypot(Math.max(cx, width - cx), Math.max(cy, height - cy));
  }
  readonly property size pixelSize: hasRealSize ? Qt.size(Math.round(width * pixelRatio), Math.round(height * pixelRatio)) : Qt.size(0, 0)
  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }
  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  screen: (modelData && modelData.name) ? (Quickshell.screens.find(s => s && s.name === modelData.name) || null) : null

  Image {
    id: baseImage
    anchors.fill: parent
    fillMode: root.fillMode
    source: root.hasRealSize ? root.currentUrl : ""
    sourceSize: root.pixelSize
    asynchronous: true
    cache: false
    retainWhileLoading: true
  }

  ClippingRectangle {
    id: revealMask
    width: 0
    height: width
    radius: width / 2
    x: Math.round(root.width * root.centerXRatio - width / 2)
    y: Math.round(root.height * root.centerYRatio - height / 2)

    Image {
      id: overlayImage
      width: root.width
      height: root.height
      x: -Math.round(revealMask.x)
      y: -Math.round(revealMask.y)
      fillMode: root.fillMode
      sourceSize: root.pixelSize
      source: root.pendingUrl
      asynchronous: true
      cache: false

      onStatusChanged: {
        if (status === Image.Ready && revealMask.width === 0 && root.pendingUrl) {
          revealAnim.start();
        } else if (status === Image.Error) {
          root.pendingUrl = "";
          revealMask.width = 0;
        }
      }
    }
  }

  NumberAnimation {
    id: revealAnim
    target: revealMask
    property: "width"
    from: 0
    to: root.revealDiameter
    duration: 741
    easing.type: Easing.Bezier
    easing.bezierCurve: [0.54, 0.0, 0.20, 1.0]
    onFinished: {
      if (!root.pendingUrl)
        return;
      baseImage.source = root.pendingUrl;
      function finishSwap() {
        if (baseImage.status !== Image.Ready)
          return;
        baseImage.statusChanged.disconnect(finishSwap);
        root.currentUrl = root.pendingUrl;
        root.pendingUrl = "";
        revealMask.width = 0;
      }
      if (baseImage.status === Image.Ready)
        finishSwap();
      else
        baseImage.statusChanged.connect(finishSwap);
    }
  }

  function clampToUnit(v) {
    const n = Number(v);
    return Math.max(0, Math.min(1, Number.isFinite(n) ? n : 0));
  }

  function applyModel(md) {
    if (!md)
      return;
    if (typeof md.mode === "string")
      displayMode = md.mode;
    if (Number.isFinite(md.animCenterX))
      centerXRatio = clampToUnit(md.animCenterX);
    if (Number.isFinite(md.animCenterY))
      centerYRatio = clampToUnit(md.animCenterY);
    if (typeof md.wallpaper === "string")
      currentUrl = md.wallpaper;
  }

  function setPendingUrl(src) {
    const v = (typeof src === "string" && src) ? src : currentUrl;
    if (v === currentUrl || overlayImage.source === v) {
      pendingUrl = v;
      if (overlayImage.status === Image.Ready) {
        revealMask.width = 0;
        revealAnim.restart();
      }
      return;
    }
    pendingUrl = v;
  }

  Component.onCompleted: applyModel(modelData)
  onModelDataChanged: applyModel(modelData)

  Connections {
    target: WallpaperService
    function onWallpaperChanged(name, path, cx, cy) {
      if (!name || !root.modelData || name !== root.modelData.name)
        return;
      if (revealAnim.running)
        revealAnim.complete();
      if (Number.isFinite(cx))
        root.centerXRatio = root.clampToUnit(cx);
      if (Number.isFinite(cy))
        root.centerYRatio = root.clampToUnit(cy);
      const newSrc = (typeof path === "string" && path) ? path : root.currentUrl;
      if (newSrc === root.currentUrl)
        return;
      root.setPendingUrl(newSrc);
      revealMask.width = 0;
      if (overlayImage.status === Image.Ready)
        revealAnim.start();
    }
  }
}
