pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Core

WlrLayershell {
  id: root

  required property var modelData

  // Display and sizing
  property string displayMode: (modelData && typeof modelData.mode === "string") ? modelData.mode : "fill"
  readonly property int imageFillMode: displayMode === "fit" ? Image.PreserveAspectFit : displayMode === "stretch" ? Image.Stretch : displayMode === "center" ? Image.Pad : displayMode === "tile" ? Image.Tile : Image.PreserveAspectCrop

  // Transition state
  property string transitionType: (modelData && typeof modelData.transition === "string") ? modelData.transition : WallpaperService.wallpaperTransition
  property real transitionProgress: 0.0
  property real edgeSmoothness: 0.1
  // Per-transition params
  property real wipeDirection: 0
  property real discCenterX: 0.5
  property real discCenterY: 0.5
  property real stripesCount: 16
  property real stripesAngle: 0
  property bool waitingForCurrentReady: false
  property bool pendingProgressReset: false
  property string pendingWallpaperUrl: ""

  // Sources
  readonly property bool hasCurrent: currentWallpaper.status === Image.Ready && !!currentWallpaper.source
  readonly property bool booting: !hasCurrent && nextWallpaper.status === Image.Ready

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }
  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  screen: (modelData && modelData.name) ? (Quickshell.screens.find(s => s && s.name === modelData.name) || null) : null

  // Transparent source for fade-in when no current wallpaper
  Rectangle {
    id: transparentRect
    anchors.fill: parent
    color: "transparent"
    visible: false
  }
  ShaderEffectSource {
    id: transparentSource
    sourceItem: transparentRect
    hideSource: true
    live: false
  }

  // Portrait/HiDPI helpers (physical pixels)
  readonly property real deviceScale: (modelData && modelData.scale) ? modelData.scale : 1.0
  readonly property real screenPixelWidth: width * deviceScale
  readonly property real screenPixelHeight: height * deviceScale
  readonly property real currentPaintedWidthPx: Math.max(1, Math.round(currentWallpaper.paintedWidth * deviceScale))
  readonly property real currentPaintedHeightPx: Math.max(1, Math.round(currentWallpaper.paintedHeight * deviceScale))
  readonly property real nextPaintedWidthPx: Math.max(1, Math.round(nextWallpaper.paintedWidth * deviceScale))
  readonly property real nextPaintedHeightPx: Math.max(1, Math.round(nextWallpaper.paintedHeight * deviceScale))

  // Actual image layers
  Image {
    id: currentWallpaper
    anchors.fill: parent
    visible: true
    opacity: 0
    layer.enabled: true
    asynchronous: true
    smooth: true
    cache: false
    fillMode: root.imageFillMode

    onStatusChanged: {
      if (status === Image.Ready || status === Image.Error)
        root.handleCurrentStatus(status);
    }
  }

  Image {
    id: nextWallpaper
    anchors.fill: parent
    visible: true
    opacity: 0
    layer.enabled: true
    asynchronous: true
    smooth: true
    cache: false
    fillMode: root.imageFillMode

    onStatusChanged: {
      if (status === Image.Error) {
        nextWallpaper.source = "";
        return;
      }
      if (status !== Image.Ready)
        return;
      if (!currentWallpaper.source || root.transitionType === "none") {
        root.transitionProgress = 1.0;
        root.commitNextWallpaper(true);
        return;
      }
      if (!transitionAnim.running)
        transitionAnim.start();
    }
  }

  // Unified transition shader
  ShaderEffect {
    id: transitionShader
    anchors.fill: parent
    readonly property url shaderUrl: root.shaderUrlForTransition(root.transitionType)
    readonly property bool hasSources: root.hasCurrent || root.booting
    visible: hasSources && shaderUrl !== ""

    property var source1: visible ? (root.hasCurrent ? currentWallpaper : transparentSource) : null
    property var source2: visible ? nextWallpaper : null
    property real progress: root.transitionProgress
    property real smoothness: root.edgeSmoothness
    property real aspectRatio: root.screenPixelWidth / Math.max(1.0, root.screenPixelHeight)
    property real direction: root.wipeDirection
    property real stripeCount: root.stripesCount
    property real angle: root.stripesAngle
    property real centerX: root.transitionType === "disc" ? root.discCenterX : 0.5
    property real centerY: root.transitionType === "disc" ? root.discCenterY : 0.5
    property real fillMode: 1.0
    property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
    property real imageWidth1: root.hasCurrent ? root.currentPaintedWidthPx : root.screenPixelWidth
    property real imageHeight1: root.hasCurrent ? root.currentPaintedHeightPx : root.screenPixelHeight
    property real imageWidth2: root.nextPaintedWidthPx
    property real imageHeight2: root.nextPaintedHeightPx
    property real screenWidth: root.screenPixelWidth
    property real screenHeight: root.screenPixelHeight

    fragmentShader: shaderUrl
  }

  NumberAnimation {
    id: transitionAnim
    target: root
    property: "transitionProgress"
    from: 0.0
    to: 1.0
    duration: 900
    easing.type: Easing.InOutCubic
    onFinished: {
      Qt.callLater(() => {
        if (!nextWallpaper.source || nextWallpaper.status !== Image.Ready)
          return;
        root.commitNextWallpaper(true);
      });
    }
  }
  function sourceToString(src) {
    return src && src.toString ? src.toString() : src;
  }

  function commitNextWallpaper(resetProgress) {
    if (!nextWallpaper.source) {
      root.pendingProgressReset = false;
      root.waitingForCurrentReady = false;
      return;
    }
    if (currentWallpaper.source !== nextWallpaper.source)
      currentWallpaper.source = nextWallpaper.source;
    root.pendingProgressReset = resetProgress;
    root.waitingForCurrentReady = true;
    if (currentWallpaper.status === Image.Ready)
      root.handleCurrentStatus(Image.Ready);
  }

  function handleCurrentStatus(status) {
    if (!root.waitingForCurrentReady)
      return;
    if (status === Image.Ready) {
      if (root.pendingProgressReset)
        root.transitionProgress = 0.0;
      root.pendingProgressReset = false;
      if (sourceToString(nextWallpaper.source) === sourceToString(currentWallpaper.source))
        nextWallpaper.source = "";
      root.waitingForCurrentReady = false;
      Qt.callLater(root.processPendingWallpaper);
    } else if (status === Image.Error) {
      root.pendingProgressReset = false;
      root.waitingForCurrentReady = false;
      Qt.callLater(root.processPendingWallpaper);
    }
  }

  function processPendingWallpaper() {
    if (!root.pendingWallpaperUrl)
      return;
    const pending = root.pendingWallpaperUrl;
    root.pendingWallpaperUrl = "";
    root.changeWallpaper(pending);
  }

  function shaderUrlForTransition(t) {
    switch (t) {
    case "wipe":
      return Qt.resolvedUrl("../Shaders/qsb/wp_wipe.frag.qsb");
    case "disc":
      return Qt.resolvedUrl("../Shaders/qsb/wp_disc.frag.qsb");
    case "stripes":
      return Qt.resolvedUrl("../Shaders/qsb/wp_stripes.frag.qsb");
    case "portal":
      return Qt.resolvedUrl("../Shaders/qsb/wp_portal.frag.qsb");
    case "fade":
    case "none":
    default:
      return Qt.resolvedUrl("../Shaders/qsb/wp_fade.frag.qsb");
    }
  }

  function normalizeUrl(p) {
    if (!p)
      return "";
    const s = p.toString();
    if (s.startsWith("file://") || s.startsWith("http://") || s.startsWith("https://"))
      return s;
    return "file://" + s;
  }

  function changeWallpaper(newPath) {
    const newUrl = normalizeUrl(newPath);
    const currentSource = sourceToString(currentWallpaper.source);
    const nextSource = sourceToString(nextWallpaper.source);
    if (!newUrl || newUrl === currentSource || newUrl === nextSource)
      return;

    if (transitionAnim.running || root.waitingForCurrentReady) {
      root.pendingWallpaperUrl = newUrl;
      return;
    }

    // Clear any stale pending request we're about to fulfill immediately
    if (root.pendingWallpaperUrl === newUrl)
      root.pendingWallpaperUrl = "";

    // Randomize per-transition parameters
    if (root.transitionType === "wipe") {
      root.wipeDirection = Math.random() * 4; // 0..4 (right, down, left, up)
    } else if (root.transitionType === "disc") {
      root.discCenterX = Math.random();
      root.discCenterY = Math.random();
    } else if (root.transitionType === "stripes") {
      root.stripesCount = Math.round(Math.random() * 20 + 4);
      root.stripesAngle = Math.random() * 360;
    }

    nextWallpaper.source = newUrl;
    if (nextWallpaper.status === Image.Ready) {
      if (currentWallpaper.source && root.transitionType !== "none")
        transitionAnim.start();
      else {
        root.transitionProgress = 1.0;
        root.commitNextWallpaper(true);
      }
    }
  }

  function applyModel(md) {
    if (!md)
      return;
    if (typeof md.mode === "string")
      displayMode = md.mode;
    if (typeof md.transition === "string")
      transitionType = md.transition;
    if (typeof md.wallpaper === "string")
      currentWallpaper.source = normalizeUrl(md.wallpaper);
  }

  Component.onCompleted: applyModel(modelData)
  onModelDataChanged: applyModel(modelData)

  Connections {
    target: WallpaperService
    function onWallpaperChanged(name, path) {
      if (!name || !root.modelData || name !== root.modelData.name)
        return;
      root.changeWallpaper(path);
    }
    function onModeChanged(name, mode) {
      if (!name || !root.modelData || name !== root.modelData.name)
        return;
      root.displayMode = mode;
    }
    function onTransitionChanged(t) {
      root.transitionType = t;
    }
  }
}
