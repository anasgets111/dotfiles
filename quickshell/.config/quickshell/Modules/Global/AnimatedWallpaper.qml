pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Services.Core

WlrLayershell {
  id: root

  readonly property string currentPath: screenName ? WallpaperService.wallpaperPath(screenName) : ""
  readonly property int imageFillMode: WallpaperService.modeToFillMode(WallpaperService.wallpaperMode(screenName))
  readonly property size maxSourceSize: {
    const scale = monitor?.scale ?? 1;
    return Qt.size(width * scale, height * scale);
  }
  required property var monitor
  property string pendingUrl: ""
  readonly property string screenName: monitor?.name ?? ""
  readonly property var screenObject: screenName ? Quickshell.screens.find(screen => screen?.name === screenName) : null
  property real transitionProgress: 0.0

  function changeWallpaper(newPath: string): void {
    if (!screenObject || !newPath)
      return;
    if (newPath === currentImg.source.toString() || newPath === nextImgLoader.pendingSource)
      return;
    if (transitionAnim.running || transitionProgress > 0) {
      pendingUrl = newPath;
      return;
    }
    if (currentImg.status !== Image.Ready) {
      currentImg.source = newPath;
      return;
    }
    pendingUrl = "";
    transitionParams.randomize(WallpaperService.wallpaperTransition);
    nextImgLoader.pendingSource = newPath;
  }
  function resetTransition(): void {
    transitionAnim.stop();
    nextImgLoader.pendingSource = "";
    pendingUrl = "";
    transitionProgress = 0.0;
  }

  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  screen: screenObject

  Component.onCompleted: if (currentPath)
    currentImg.source = currentPath
  Component.onDestruction: resetTransition()
  onCurrentPathChanged: if (currentPath)
    changeWallpaper(currentPath)
  onScreenObjectChanged: if (!screenObject)
    resetTransition()

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }
  QtObject {
    id: transitionParams

    property real angle: 0
    property real centerX: 0.5
    property real centerY: 0.5
    property int count: 16
    property real direction: 0

    function randomize(type: string): void {
      if (type === "wipe") {
        direction = Math.random() * 4;
      } else if (type === "disc" || type === "portal") {
        centerX = Math.random();
        centerY = Math.random();
      } else if (type === "stripes") {
        count = Math.round(Math.random() * 20 + 4);
        angle = Math.random() * 360;
      }
    }
  }
  Image {
    id: currentImg

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
      else if (status === Image.Ready && !transitionAnim.running && root.transitionProgress > 0) {
        root.transitionProgress = 0.0;
        nextImgLoader.pendingSource = "";
        if (root.pendingUrl)
          Qt.callLater(() => root.changeWallpaper(root.pendingUrl));
      }
    }
  }

  // Exists only during transitions so its GPU texture is released afterward.
  Loader {
    id: nextImgLoader

    property string pendingSource: ""

    active: pendingSource !== ""
    anchors.fill: parent

    sourceComponent: Image {
      anchors.fill: parent
      asynchronous: true
      cache: false
      fillMode: root.imageFillMode
      source: nextImgLoader.pendingSource
      sourceSize: root.maxSourceSize
      visible: false

      onStatusChanged: {
        if (!root.screenObject || status === Image.Loading)
          return;
        if (status === Image.Error)
          nextImgLoader.pendingSource = "";
        else if (status === Image.Ready && !transitionAnim.running)
          transitionAnim.start();
      }
    }
  }
  Loader {
    id: shaderLoader

    active: root.visible && root.screenObject && (transitionAnim.running || root.transitionProgress > 0)
    anchors.fill: parent

    sourceComponent: ShaderEffect {
      readonly property real angle: transitionParams.angle
      readonly property real aspectRatio: width / Math.max(1, height)
      readonly property real centerX: transitionParams.centerX
      readonly property real centerY: transitionParams.centerY
      readonly property real direction: transitionParams.direction
      readonly property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
      readonly property real fillMode: 1.0
      readonly property real imageHeight1: currentImg.status === Image.Ready ? currentImg.paintedHeight : height
      readonly property real imageHeight2: source2?.paintedHeight ?? 0
      readonly property real imageWidth1: currentImg.status === Image.Ready ? currentImg.paintedWidth : width
      readonly property real imageWidth2: source2?.paintedWidth ?? 0
      readonly property real progress: root.transitionProgress
      readonly property real screenHeight: root.maxSourceSize.height
      readonly property real screenWidth: root.maxSourceSize.width
      readonly property real smoothness: 0.1
      readonly property Image source1: currentImg
      readonly property Image source2: nextImgLoader.item as Image
      readonly property real stripeCount: transitionParams.count

      anchors.fill: parent
      fragmentShader: Qt.resolvedUrl(`../../Shaders/qsb/wp_${WallpaperService.wallpaperTransition}.frag.qsb`)
    }
  }
  NumberAnimation {
    id: transitionAnim

    duration: Theme.wallpaperAnimationDuration
    easing.type: Easing.InOutCubic
    from: 0.0
    property: "transitionProgress"
    target: root
    to: 1.0

    onFinished: if (nextImgLoader.pendingSource !== "")
      currentImg.source = nextImgLoader.pendingSource
  }
}
