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
  property real edgeSmoothness: 0.1
  readonly property bool hasCurrent: currentWallpaper.status === Image.Ready && !!currentWallpaper.source
  readonly property int imageFillMode: WallpaperService.modeToFillMode(displayMode)
  property bool isDestroyed: false
  required property var modelData
  readonly property real nextPaintedHeightPx: Math.max(1, Math.round(nextWallpaper.paintedHeight * deviceScale))
  readonly property real nextPaintedWidthPx: Math.max(1, Math.round(nextWallpaper.paintedWidth * deviceScale))
  property bool pendingProgressReset: false
  property string pendingWallpaperUrl: ""
  readonly property var screenObject: modelData?.name ? Quickshell.screens.find(s => s?.name === modelData.name) ?? null : null
  readonly property real screenPixelHeight: height * deviceScale
  readonly property real screenPixelWidth: width * deviceScale
  readonly property bool screenValid: screenObject !== null
  property real stripesAngle: 0
  property real stripesCount: 16
  property real transitionProgress: 0.0
  property string transitionType: modelData?.transition ?? WallpaperService.wallpaperTransition
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
        Qt.callLater(() => {
          if (typeof gc === "function")
            gc();
        });
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
        if (typeof gc === "function")
          gc();
      }
      waitingForCurrentReady = false;
      Qt.callLater(() => {
        if (!isDestroyed)
          processPendingWallpaper();
      });
    } else if (status === Image.Error) {
      pendingProgressReset = false;
      waitingForCurrentReady = false;
      Qt.callLater(() => {
        if (!isDestroyed)
          processPendingWallpaper();
      });
    }
  }

  function normalizeUrl(p) {
    if (!p)
      return "";
    const s = String(p);
    if (s.startsWith("file://") || s.startsWith("http://") || s.startsWith("https://"))
      return s;
    return `file://${s}`;
  }

  function processPendingWallpaper() {
    if (isDestroyed || !pendingWallpaperUrl)
      return;
    const pending = pendingWallpaperUrl;
    pendingWallpaperUrl = "";
    changeWallpaper(pending);
  }

  function setupTransition(type) {
    if (type === "wipe") {
      wipeDirection = Math.random() * 4;
    } else if (type === "disc") {
      discCenterX = Math.random();
      discCenterY = Math.random();
    } else if (type === "stripes") {
      stripesCount = Math.round(Math.random() * 20 + 4);
      stripesAngle = Math.random() * 360;
    }
  }

  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  screen: screenObject

  Component.onCompleted: {
    if (modelData?.mode)
      displayMode = modelData.mode;
    if (modelData?.transition)
      transitionType = modelData.transition;
    if (modelData?.wallpaper)
      currentWallpaper.source = normalizeUrl(modelData.wallpaper);
  }
  Component.onDestruction: {
    isDestroyed = true;
    transitionAnim.stop();
    wallpaperConnections.enabled = false;
    transitionShader.visible = false;
    currentWallpaper.sourceSize = Qt.size(0, 0);
    nextWallpaper.sourceSize = Qt.size(0, 0);
    currentWallpaper.source = "";
    nextWallpaper.source = "";
    Qt.callLater(() => {
      if (typeof gc === "function")
        gc();
    });
  }
  onModelDataChanged: {
    if (modelData?.mode)
      displayMode = modelData.mode;
    if (modelData?.transition)
      transitionType = modelData.transition;
  }
  onScreenValidChanged: {
    if (!screenValid && !isDestroyed) {
      // Screen disconnected - immediately clear images to free memory
      transitionAnim.stop();
      currentWallpaper.source = "";
      nextWallpaper.source = "";
      pendingWallpaperUrl = "";
      if (typeof gc === "function")
        gc();
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
    opacity: 0
    smooth: true
    sourceSize: Qt.size(Math.min(root.screenPixelWidth, 3840), Math.min(root.screenPixelHeight, 2160))
    visible: true

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
    opacity: 0
    smooth: true
    sourceSize: Qt.size(Math.min(root.screenPixelWidth, 3840), Math.min(root.screenPixelHeight, 2160))
    visible: true

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
    property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
    property real fillMode: 1.0
    readonly property bool hasSources: root.hasCurrent || root.booting
    property real imageHeight1: root.hasCurrent ? root.currentPaintedHeightPx : root.screenPixelHeight
    property real imageHeight2: root.nextPaintedHeightPx
    property real imageWidth1: root.hasCurrent ? root.currentPaintedWidthPx : root.screenPixelWidth
    property real imageWidth2: root.nextPaintedWidthPx
    property real progress: root.transitionProgress
    property real screenHeight: root.screenPixelHeight
    property real screenWidth: root.screenPixelWidth
    readonly property url shaderUrl: Qt.resolvedUrl({
      wipe: "../Shaders/qsb/wp_wipe.frag.qsb",
      disc: "../Shaders/qsb/wp_disc.frag.qsb",
      stripes: "../Shaders/qsb/wp_stripes.frag.qsb",
      portal: "../Shaders/qsb/wp_portal.frag.qsb"
    }[root.transitionType] ?? "../Shaders/qsb/wp_fade.frag.qsb")
    property real smoothness: root.edgeSmoothness
    readonly property var source1: currentWallpaper
    readonly property var source2: nextWallpaper
    property real stripeCount: root.stripesCount

    anchors.fill: parent
    fragmentShader: shaderUrl
    visible: (root.hasCurrent || root.booting) && shaderUrl !== ""
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
      if (name && root.modelData?.name === name)
        root.displayMode = mode;
    }

    function onTransitionChanged(t) {
      root.transitionType = t;
    }

    function onWallpaperChanged(name, path) {
      if (name && root.modelData?.name === name)
        root.changeWallpaper(path);
    }

    target: WallpaperService
  }
}
