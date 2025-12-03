pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Core

WlrLayershell {
  id: root

  readonly property real deviceScale: monitor?.scale ?? 1.0
  property real discCenterX: 0.5
  property real discCenterY: 0.5
  property string displayMode: "fill"
  readonly property bool hasCurrent: currentWallpaper.status === Image.Ready && currentWallpaper.source !== ""
  readonly property int imageFillMode: WallpaperService.modeToFillMode(displayMode)
  property bool isDestroyed: false
  readonly property size maxSourceSize: Qt.size(Math.min(width * deviceScale, 3840), Math.min(height * deviceScale, 2160))
  required property var monitor
  property string pendingWallpaperUrl: ""
  readonly property string screenName: monitor?.name ?? ""
  readonly property var screenObject: screenName ? Quickshell.screens.find(s => s?.name === screenName) : null
  readonly property var shaderMap: ({
      wipe: Qt.resolvedUrl("../../Shaders/qsb/wp_wipe.frag.qsb"),
      disc: Qt.resolvedUrl("../../Shaders/qsb/wp_disc.frag.qsb"),
      stripes: Qt.resolvedUrl("../../Shaders/qsb/wp_stripes.frag.qsb"),
      portal: Qt.resolvedUrl("../../Shaders/qsb/wp_portal.frag.qsb"),
      fade: Qt.resolvedUrl("../../Shaders/qsb/wp_fade.frag.qsb")
    })
  readonly property url shaderUrl: shaderMap[transitionType] ?? shaderMap.fade
  property real stripesAngle: 0
  property real stripesCount: 16
  property real transitionProgress: 0.0
  property string transitionType: WallpaperService.wallpaperTransition
  readonly property bool transitioning: transitionAnim.running
  property real wipeDirection: 0

  function changeWallpaper(newPath: string): void {
    if (isDestroyed)
      return;
    const newUrl = normalizeUrl(newPath);
    if (!newUrl || newUrl === currentWallpaper.source.toString() || newUrl === nextWallpaper.source.toString())
      return;
    if (transitionAnim.running) {
      pendingWallpaperUrl = newUrl;
      return;
    }
    pendingWallpaperUrl = "";
    setupTransition(transitionType);
    nextWallpaper.source = newUrl;
  }

  function cleanupResources(): void {
    isDestroyed = true;
    transitionAnim.stop();
    wallpaperConnections.enabled = false;
  }

  function commitNextWallpaper(): void {
    if (isDestroyed || nextWallpaper.source === "")
      return;
    currentWallpaper.source = nextWallpaper.source;
  }

  function finalizeTransition(): void {
    nextWallpaper.source = "";
    transitionProgress = 0.0;
  }

  function normalizeUrl(path: string): string {
    if (!path)
      return "";
    const str = String(path);
    return str.startsWith("file://") || str.startsWith("http://") || str.startsWith("https://") ? str : `file://${str}`;
  }

  function processPendingWallpaper(): void {
    if (isDestroyed || !pendingWallpaperUrl)
      return;
    const pending = pendingWallpaperUrl;
    pendingWallpaperUrl = "";
    changeWallpaper(pending);
  }

  function setupTransition(type: string): void {
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
    if (!screenName)
      return;
    const prefs = WallpaperService.wallpaperFor(screenName);
    if (prefs) {
      displayMode = prefs.mode || "fill";
      transitionType = prefs.transition || WallpaperService.wallpaperTransition;
      if (prefs.wallpaper)
        currentWallpaper.source = normalizeUrl(prefs.wallpaper);
    }
  }
  Component.onDestruction: cleanupResources()
  onScreenObjectChanged: if (!screenObject && !isDestroyed)
    cleanupResources()

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
      if (root.isDestroyed || status === Image.Loading)
        return;
      if (status === Image.Ready) {
        if (nextWallpaper.source !== "" && currentWallpaper.source.toString() === nextWallpaper.source.toString())
          root.finalizeTransition();
        if (root.pendingWallpaperUrl && !root.transitioning)
          Qt.callLater(root.processPendingWallpaper);
      } else if (status === Image.Error) {
        console.warn("AnimatedWallpaper: Failed to load", currentWallpaper.source);
      }
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
      if (root.isDestroyed || status === Image.Loading)
        return;
      if (status === Image.Error) {
        nextWallpaper.source = "";
      } else if (status === Image.Ready) {
        if (currentWallpaper.source === "" || root.transitionType === "none")
          root.commitNextWallpaper();
        else if (!transitionAnim.running)
          transitionAnim.start();
      }
    }
  }

  ShaderEffect {
    id: transitionShader

    readonly property real angle: root.stripesAngle
    readonly property real aspectRatio: width / Math.max(1.0, height)
    readonly property real centerX: root.transitionType === "disc" || root.transitionType === "portal" ? root.discCenterX : 0.5
    readonly property real centerY: root.transitionType === "disc" || root.transitionType === "portal" ? root.discCenterY : 0.5
    readonly property real direction: root.wipeDirection
    readonly property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
    readonly property real fillMode: 1.0
    readonly property real imageHeight1: root.hasCurrent ? currentWallpaper.paintedHeight : height
    readonly property real imageHeight2: nextWallpaper.paintedHeight
    readonly property real imageWidth1: root.hasCurrent ? currentWallpaper.paintedWidth : width
    readonly property real imageWidth2: nextWallpaper.paintedWidth
    readonly property real progress: root.transitionProgress
    readonly property real screenHeight: height * root.deviceScale
    readonly property real screenWidth: width * root.deviceScale
    readonly property real smoothness: 0.1
    readonly property Image source1: currentWallpaper
    readonly property Image source2: nextWallpaper
    readonly property real stripeCount: root.stripesCount

    anchors.fill: parent
    fragmentShader: root.shaderUrl
    visible: (root.transitioning || root.transitionProgress > 0) && (root.hasCurrent || nextWallpaper.status === Image.Ready)
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
      if (!root.isDestroyed)
        root.commitNextWallpaper();
    }
  }

  Connections {
    id: wallpaperConnections

    function onModeChanged(name: string, mode: string): void {
      if (name === root.screenName)
        root.displayMode = mode;
    }

    function onTransitionChanged(transition: string): void {
      root.transitionType = transition;
    }

    function onWallpaperChanged(name: string, path: string): void {
      if (name === root.screenName)
        root.changeWallpaper(path);
    }

    target: WallpaperService
  }
}
