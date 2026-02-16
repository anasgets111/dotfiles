pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Core

WlrLayershell {
  id: root

  readonly property string currentMode: screenName ? WallpaperService.wallpaperMode(screenName) : "fill"
  readonly property string currentPath: screenName ? WallpaperService.wallpaperPath(screenName) : ""
  readonly property string currentTransition: WallpaperService.wallpaperTransitionType()
  property string displayMode: currentMode
  readonly property int imageFillMode: WallpaperService.modeToFillMode(displayMode)
  readonly property size maxSourceSize: {
    const s = monitor?.scale ?? 1;
    return Qt.size(width * s, height * s);
  }
  required property var monitor
  property string pendingUrl: ""
  readonly property string safeTransitionType: {
    const valid = ["wipe", "disc", "stripes", "portal"];
    return valid.includes(transitionType) ? transitionType : "fade";
  }
  readonly property string screenName: monitor?.name ?? ""
  readonly property var screenObject: screenName ? Quickshell.screens.find(s => s?.name === screenName) : null
  property real transitionProgress: 0.0
  property string transitionType: currentTransition

  function changeWallpaper(newPath: string): void {
    if (!screenObject)
      return;
    const url = normalizeUrl(newPath);
    if (!url)
      return;
    if (!currentImg.source || currentImg.source === "" || currentImg.status === Image.Loading) {
      currentImg.source = url;
      return;
    }
    const currentStr = currentImg.source.toString();
    const nextStr = nextImg.source.toString();
    if (url === currentStr || url === nextStr)
      return;
    if (transitionAnim.running) {
      pendingUrl = url;
      return;
    }
    pendingUrl = "";
    tp.randomize(transitionType);
    nextImg.source = url;
  }

  function normalizeUrl(path: string): string {
    return !path ? "" : /^(file|https?):\/\//.test(path) ? path : `file://${path}`;
  }

  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  screen: screenObject

  Component.onCompleted: if (currentPath)
    currentImg.source = normalizeUrl(currentPath)
  Component.onDestruction: {
    transitionAnim.stop();
    shaderLoader.active = false;
  }
  onCurrentModeChanged: displayMode = currentMode
  onCurrentPathChanged: if (currentPath)
    changeWallpaper(currentPath)
  onCurrentTransitionChanged: transitionType = currentTransition
  onScreenObjectChanged: if (!screenObject) {
    transitionAnim.stop();
    shaderLoader.active = false;
  }

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }

  // Typed transition parameters
  QtObject {
    id: tp

    property real angle: 0
    property int count: 16
    property real cx: 0.5
    property real cy: 0.5
    property real dir: 0

    function randomize(type: string): void {
      if (type === "wipe") {
        dir = Math.random() * 4;
      } else if (type === "disc" || type === "portal") {
        cx = Math.random();
        cy = Math.random();
      } else if (type === "stripes") {
        count = Math.round(Math.random() * 20 + 4);
        angle = Math.random() * 360;
      }
    }
  }

  Image {
    id: currentImg

    // Hidden during transition — shader composites both images
    anchors.fill: parent
    asynchronous: true
    fillMode: root.imageFillMode
    sourceSize: root.maxSourceSize
    visible: !transitionAnim.running && root.transitionProgress === 0

    onStatusChanged: {
      if (!root.screenObject || status === Image.Loading)
        return;
      if (status === Image.Error)
        console.warn("AnimatedWallpaper: Failed to load", source);
    }
  }

  Image {
    id: nextImg

    anchors.fill: parent
    asynchronous: true
    fillMode: root.imageFillMode
    sourceSize: root.maxSourceSize
    visible: false

    onStatusChanged: {
      if (!root.screenObject || status === Image.Loading)
        return;
      if (status === Image.Error) {
        source = "";
      } else if (status === Image.Ready) {
        if (currentImg.source === "" || root.transitionType === "none")
          currentImg.source = source;
        else if (!transitionAnim.running && currentImg.status === Image.Ready)
          transitionAnim.start();
      }
    }
  }

  Loader {
    id: shaderLoader

    active: root.visible && root.screenObject && (transitionAnim.running || root.transitionProgress > 0) && ((currentImg.status === Image.Ready && currentImg.source !== "") || nextImg.status === Image.Ready)
    anchors.fill: parent

    sourceComponent: ShaderEffect {
      readonly property real angle: tp.angle
      readonly property real aspectRatio: width / Math.max(1, height)
      readonly property real centerX: tp.cx
      readonly property real centerY: tp.cy
      readonly property real direction: tp.dir
      readonly property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
      readonly property real fillMode: 1.0
      readonly property real imageHeight1: currentImg.status === Image.Ready ? currentImg.paintedHeight : height
      readonly property real imageHeight2: nextImg.paintedHeight
      readonly property real imageWidth1: currentImg.status === Image.Ready ? currentImg.paintedWidth : width
      readonly property real imageWidth2: nextImg.paintedWidth
      readonly property real progress: root.transitionProgress
      readonly property real screenHeight: height * (root.monitor?.scale ?? 1)
      readonly property real screenWidth: width * (root.monitor?.scale ?? 1)
      readonly property real smoothness: 0.1
      readonly property Image source1: currentImg
      readonly property Image source2: nextImg
      readonly property real stripeCount: tp.count

      anchors.fill: parent
      fragmentShader: Qt.resolvedUrl(`../../Shaders/qsb/wp_${root.safeTransitionType}.frag.qsb`)
    }
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
      if (nextImg.source !== "") {
        currentImg.source = nextImg.source;
        nextImg.source = "";
      }
      root.transitionProgress = 0.0;
      if (root.pendingUrl)
        Qt.callLater(() => root.changeWallpaper(root.pendingUrl));
    }
  }
}
