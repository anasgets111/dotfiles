pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Core

WlrLayershell {
  id: root

  readonly property bool booting: !hasCurrent && nextWallpaper.status === Image.Ready
  readonly property real currentPaintedHeightPx: Math.max(1, Math.round(currentWallpaper.paintedHeight * deviceScale))
  readonly property real currentPaintedWidthPx: Math.max(1, Math.round(currentWallpaper.paintedWidth * deviceScale))
  readonly property real deviceScale: modelData?.scale ?? 1.0
  property real discCenterX: 0.5
  property real discCenterY: 0.5
  property string displayMode: modelData?.mode ?? "fill"
  readonly property real edgeSmoothness: 0.1
  readonly property bool hasCurrent: currentWallpaper.status === Image.Ready && !!currentWallpaper.source
  readonly property int imageFillMode: WallpaperService.modeToFillMode(displayMode)
  property bool isDestroyed: false
  readonly property size maxSourceSize: Qt.size(Math.min(screenPixelWidth, 3840), Math.min(screenPixelHeight, 2160))
  required property var modelData
  readonly property real nextPaintedHeightPx: Math.max(1, Math.round(nextWallpaper.paintedHeight * deviceScale))
  readonly property real nextPaintedWidthPx: Math.max(1, Math.round(nextWallpaper.paintedWidth * deviceScale))
  property bool pendingProgressReset: false
  property string pendingWallpaperUrl: ""
  readonly property string screenName: modelData?.name ?? ""
  readonly property var screenObject: screenName ? Quickshell.screens.find(s => s?.name === screenName) ?? null : null
  readonly property real screenPixelHeight: height * deviceScale
  readonly property real screenPixelWidth: width * deviceScale
  readonly property bool screenValid: screenObject !== null
  property real stripesAngle: 0
  property real stripesCount: 16
  property real transitionProgress: 0.0
  property string transitionType: modelData?.transition ?? WallpaperService.wallpaperTransition
  readonly property bool transitioning: transitionAnim.running
  property bool waitingForCurrentReady: false
  property real wipeDirection: 0

  function changeWallpaper(newPath) {
    if (isDestroyed)
      return;
    const newUrl = normalizeUrl(newPath);
    if (!newUrl || newUrl === String(currentWallpaper.source) || newUrl === String(nextWallpaper.source))
      return;
    if (transitionAnim.running || waitingForCurrentReady) {
      pendingWallpaperUrl = newUrl;
      return;
    }
    if (pendingWallpaperUrl === newUrl)
      pendingWallpaperUrl = "";
    setupTransition(transitionType);
    if (nextWallpaper.source && nextWallpaper.source !== newUrl) {
      nextWallpaper.source = "";
      Qt.callLater(() => {
        if (!isDestroyed)
          nextWallpaper.source = newUrl;
      });
      return;
    }
    nextWallpaper.source = newUrl;
    if (nextWallpaper.status === Image.Ready) {
      if (currentWallpaper.source && transitionType !== "none")
        transitionAnim.start();
      else {
        transitionProgress = 1.0;
        commitNextWallpaper(true);
      }
    }
  }

  function cleanupResources() {
    isDestroyed = true;
    transitionAnim.stop();
    wallpaperConnections.enabled = false;
    currentWallpaper.source = "";
    nextWallpaper.source = "";
    currentWallpaper.sourceSize = Qt.size(0, 0);
    nextWallpaper.sourceSize = Qt.size(0, 0);
    pendingWallpaperUrl = "";
    waitingForCurrentReady = false;
    pendingProgressReset = false;
    Qt.callLater(tryGarbageCollect);
  }

  function commitNextWallpaper(resetProgress) {
    if (isDestroyed)
      return;
    if (!nextWallpaper.source) {
      pendingProgressReset = false;
      waitingForCurrentReady = false;
      return;
    }
    if (currentWallpaper.source !== nextWallpaper.source) {
      if (currentWallpaper.source) {
        const tempSource = nextWallpaper.source;
        currentWallpaper.source = tempSource;
        Qt.callLater(tryGarbageCollect);
      } else {
        currentWallpaper.source = nextWallpaper.source;
      }
    }
    pendingProgressReset = resetProgress;
    waitingForCurrentReady = true;
    if (currentWallpaper.status === Image.Ready)
      handleCurrentStatus(Image.Ready);
  }

  function handleCurrentStatus(status) {
    if (isDestroyed || !waitingForCurrentReady)
      return;
    if (status === Image.Ready) {
      if (pendingProgressReset)
        transitionProgress = 0.0;
      pendingProgressReset = false;
      if (String(nextWallpaper.source) === String(currentWallpaper.source)) {
        nextWallpaper.source = "";
        tryGarbageCollect();
      }
      waitingForCurrentReady = false;
      Qt.callLater(processPendingWallpaper);
    } else if (status === Image.Error) {
      pendingProgressReset = false;
      waitingForCurrentReady = false;
      Qt.callLater(processPendingWallpaper);
    }
  }

  // Core functions
  function normalizeUrl(path) {
    if (!path)
      return "";
    const str = String(path);
    return str.startsWith("file://") || str.startsWith("http://") || str.startsWith("https://") ? str : `file://${str}`;
  }

  function processPendingWallpaper() {
    if (isDestroyed || !pendingWallpaperUrl)
      return;
    const pending = pendingWallpaperUrl;
    pendingWallpaperUrl = "";
    changeWallpaper(pending);
  }

  function setupTransition(type) {
    switch (type) {
    case "wipe":
      wipeDirection = Math.random() * 4;
      break;
    case "disc":
      discCenterX = Math.random();
      discCenterY = Math.random();
      break;
    case "stripes":
      stripesCount = Math.round(Math.random() * 20 + 4);
      stripesAngle = Math.random() * 360;
      break;
    }
  }

  function tryGarbageCollect() {
    if (typeof gc === "function")
      gc();
  }

  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  screen: screenObject

  Component.onCompleted: {
    if (modelData?.wallpaper)
      currentWallpaper.source = normalizeUrl(modelData.wallpaper);
  }
  Component.onDestruction: cleanupResources()
  onModelDataChanged: {
    if (modelData?.mode)
      displayMode = modelData.mode;
    if (modelData?.transition)
      transitionType = modelData.transition;
  }
  onScreenValidChanged: {
    if (!screenValid && !isDestroyed) {
      cleanupResources();
    }
  }

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }

  Image {
    id: currentWallpaper

    anchors.fill: parent
    asynchronous: true
    cache: false
    fillMode: root.imageFillMode
    smooth: true
    sourceSize: root.maxSourceSize
    visible: !root.transitioning && root.transitionProgress === 0

    onStatusChanged: {
      if (root.isDestroyed)
        return;
      if (status === Image.Ready || status === Image.Error)
        root.handleCurrentStatus(status);
    }
  }

  Image {
    id: nextWallpaper

    anchors.fill: parent
    asynchronous: true
    cache: false
    fillMode: root.imageFillMode
    smooth: true
    sourceSize: root.maxSourceSize
    visible: false

    onStatusChanged: {
      if (root.isDestroyed)
        return;
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

  ShaderEffect {
    id: transitionShader

    property real angle: root.stripesAngle
    property real aspectRatio: root.screenPixelWidth / Math.max(1.0, root.screenPixelHeight)
    property real centerX: root.transitionType === "disc" ? root.discCenterX : 0.5
    property real centerY: root.transitionType === "disc" ? root.discCenterY : 0.5
    property real direction: root.wipeDirection
    readonly property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
    readonly property real fillMode: 1.0
    property real imageHeight1: root.hasCurrent ? root.currentPaintedHeightPx : root.screenPixelHeight
    property real imageHeight2: root.nextPaintedHeightPx
    property real imageWidth1: root.hasCurrent ? root.currentPaintedWidthPx : root.screenPixelWidth
    property real imageWidth2: root.nextPaintedWidthPx
    property real progress: root.transitionProgress
    property real screenHeight: root.screenPixelHeight
    property real screenWidth: root.screenPixelWidth
    readonly property url shaderUrl: {
      switch (root.transitionType) {
      case "wipe":
        return Qt.resolvedUrl("../Shaders/qsb/wp_wipe.frag.qsb");
      case "disc":
        return Qt.resolvedUrl("../Shaders/qsb/wp_disc.frag.qsb");
      case "stripes":
        return Qt.resolvedUrl("../Shaders/qsb/wp_stripes.frag.qsb");
      case "portal":
        return Qt.resolvedUrl("../Shaders/qsb/wp_portal.frag.qsb");
      default:
        return Qt.resolvedUrl("../Shaders/qsb/wp_fade.frag.qsb");
      }
    }
    property real smoothness: root.edgeSmoothness
    readonly property var source1: currentWallpaper
    readonly property var source2: nextWallpaper
    property real stripeCount: root.stripesCount

    anchors.fill: parent
    fragmentShader: shaderUrl
    visible: (root.transitioning || root.transitionProgress > 0) && (root.hasCurrent || root.booting)
  }

  NumberAnimation {
    id: transitionAnim

    duration: 900
    easing.type: Easing.InOutCubic
    from: 0.0
    property: "transitionProgress"
    target: root
    to: 1.0

    onFinished: {
      Qt.callLater(() => {
        if (!root.isDestroyed && nextWallpaper.source && nextWallpaper.status === Image.Ready)
          root.commitNextWallpaper(true);
      });
    }
  }

  Connections {
    id: wallpaperConnections

    function onModeChanged(name, mode) {
      if (name && root.screenName === name)
        root.displayMode = mode;
    }

    function onTransitionChanged(t) {
      root.transitionType = t;
    }

    function onWallpaperChanged(name, path) {
      if (name && root.screenName === name)
        root.changeWallpaper(path);
    }

    target: WallpaperService
  }
}
