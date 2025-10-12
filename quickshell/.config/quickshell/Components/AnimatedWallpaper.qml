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
  required property var modelData
  readonly property real nextPaintedHeightPx: Math.max(1, Math.round(nextWallpaper.paintedHeight * deviceScale))
  readonly property real nextPaintedWidthPx: Math.max(1, Math.round(nextWallpaper.paintedWidth * deviceScale))
  property bool pendingProgressReset: false
  property string pendingWallpaperUrl: ""
  readonly property real screenPixelHeight: height * deviceScale
  readonly property real screenPixelWidth: width * deviceScale
  property real stripesAngle: 0
  property real stripesCount: 16
  property real transitionProgress: 0.0
  property string transitionType: modelData?.transition ?? WallpaperService.wallpaperTransition
  property bool waitingForCurrentReady: false
  property real wipeDirection: 0

  function applyModel(md) {
    if (!md)
      return;
    if (md.mode)
      displayMode = md.mode;
    if (md.transition)
      transitionType = md.transition;
    if (md.wallpaper)
      currentWallpaper.source = root.normalizeUrl(md.wallpaper);
  }

  function changeWallpaper(newPath) {
    const newUrl = root.normalizeUrl(newPath);
    if (!newUrl || newUrl === String(currentWallpaper.source) || newUrl === String(nextWallpaper.source))
      return;
    if (transitionAnim.running || root.waitingForCurrentReady) {
      root.pendingWallpaperUrl = newUrl;
      return;
    }
    if (root.pendingWallpaperUrl === newUrl)
      root.pendingWallpaperUrl = "";

    if (root.transitionType === "wipe")
      root.wipeDirection = Math.random() * 4;
    else if (root.transitionType === "disc") {
      root.discCenterX = Math.random();
      root.discCenterY = Math.random();
    } else if (root.transitionType === "stripes") {
      root.stripesCount = Math.round(Math.random() * 20 + 4);
      root.stripesAngle = Math.random() * 360;
    }

    if (nextWallpaper.source && nextWallpaper.source !== newUrl) {
      nextWallpaper.source = "";
      Qt.callLater(() => nextWallpaper.source = newUrl);
      return;
    }

    nextWallpaper.source = newUrl;
    if (nextWallpaper.status === Image.Ready) {
      if (currentWallpaper.source && root.transitionType !== "none") {
        transitionAnim.start();
      } else {
        root.transitionProgress = 1.0;
        root.commitNextWallpaper(true);
      }
    }
  }

  function commitNextWallpaper(resetProgress) {
    if (!nextWallpaper.source) {
      root.pendingProgressReset = false;
      root.waitingForCurrentReady = false;
      return;
    }
    if (currentWallpaper.source !== nextWallpaper.source) {
      if (currentWallpaper.source) {
        // Has old wallpaper - clear first to release GPU texture, then load new
        const tempSource = nextWallpaper.source;
        currentWallpaper.source = "";
        Qt.callLater(() => currentWallpaper.source = tempSource);
      } else {
        // No old wallpaper (first boot) - direct load
        currentWallpaper.source = nextWallpaper.source;
      }
    }

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
      if (String(nextWallpaper.source) === String(currentWallpaper.source)) {
        nextWallpaper.source = "";
      }
      root.waitingForCurrentReady = false;
      Qt.callLater(root.processPendingWallpaper);
    } else if (status === Image.Error) {
      root.pendingProgressReset = false;
      root.waitingForCurrentReady = false;
      Qt.callLater(root.processPendingWallpaper);
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
    if (!root.pendingWallpaperUrl)
      return;
    const pending = root.pendingWallpaperUrl;
    root.pendingWallpaperUrl = "";
    root.changeWallpaper(pending);
  }

  function shaderUrlForTransition(t) {
    const shaders = {
      wipe: "../Shaders/qsb/wp_wipe.frag.qsb",
      disc: "../Shaders/qsb/wp_disc.frag.qsb",
      stripes: "../Shaders/qsb/wp_stripes.frag.qsb",
      portal: "../Shaders/qsb/wp_portal.frag.qsb"
    };
    return Qt.resolvedUrl(shaders[t] ?? "../Shaders/qsb/wp_fade.frag.qsb");
  }

  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  screen: modelData?.name ? Quickshell.screens.find(s => s?.name === modelData.name) ?? null : null

  Component.onCompleted: root.applyModel(modelData)
  Component.onDestruction: {
    if (transitionAnim.running)
      transitionAnim.stop();
    transitionShader.source1 = null;
    transitionShader.source2 = null;
    transparentSource.sourceItem = null;
    currentWallpaper.source = "";
    nextWallpaper.source = "";
    transitionShader.visible = false;
  }
  onModelDataChanged: root.applyModel(modelData)

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }

  Rectangle {
    id: transparentRect

    anchors.fill: parent
    color: "transparent"
    visible: false
  }

  ShaderEffectSource {
    id: transparentSource

    hideSource: true
    live: false
    sourceItem: transparentRect
  }

  Image {
    id: currentWallpaper

    anchors.fill: parent
    asynchronous: true
    cache: false
    fillMode: root.imageFillMode
    layer.enabled: false
    opacity: 0
    smooth: true
    visible: true

    onStatusChanged: {
      if (status === Image.Ready || status === Image.Error) {
        root.handleCurrentStatus(status);
      }
    }
  }

  Image {
    id: nextWallpaper

    anchors.fill: parent
    asynchronous: true
    cache: false
    fillMode: root.imageFillMode
    layer.enabled: false
    opacity: 0
    smooth: true
    visible: true

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
    readonly property url shaderUrl: root.shaderUrlForTransition(root.transitionType)
    property real smoothness: root.edgeSmoothness
    property var source1: visible ? (root.hasCurrent ? currentWallpaper : transparentSource) : null
    property var source2: visible ? nextWallpaper : null
    property real stripeCount: root.stripesCount

    anchors.fill: parent
    fragmentShader: shaderUrl
    visible: hasSources && shaderUrl !== ""
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
        if (nextWallpaper.source && nextWallpaper.status === Image.Ready) {
          root.commitNextWallpaper(true);
        }
      });
    }
  }

  Connections {
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
