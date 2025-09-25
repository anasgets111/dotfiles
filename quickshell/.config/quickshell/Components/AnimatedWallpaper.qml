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

  // Actual image layers
  Image {
    id: currentWallpaper
    anchors.fill: parent
    visible: true
    opacity: 0
    layer.enabled: true
    asynchronous: true
    smooth: true
    cache: true
    fillMode: root.imageFillMode
  }

  Image {
    id: nextWallpaper
    anchors.fill: parent
    visible: true
    opacity: 0
    layer.enabled: true
    asynchronous: true
    smooth: true
    cache: true
    fillMode: root.imageFillMode

    onStatusChanged: {
      if (status !== Image.Ready)
        return;
      if (!currentWallpaper.source || root.transitionType === "none") {
        currentWallpaper.source = source;
        nextWallpaper.source = "";
        root.transitionProgress = 0.0;
        return;
      }
      if (!transitionAnim.running)
        transitionAnim.start();
    }
  }

  // Fade
  ShaderEffect {
    id: fadeShader
    anchors.fill: parent
    visible: (root.transitionType === "fade" || root.transitionType === "none") && (root.hasCurrent || root.booting)

    property var source1: root.hasCurrent ? currentWallpaper : transparentSource
    property var source2: nextWallpaper
    property real progress: root.transitionProgress
    // Optional tuning params compatible with shader snippets
    property real fillMode: 1.0
    property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : width)
    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : height)
    property real imageWidth2: Math.max(1, source2.sourceSize.width)
    property real imageHeight2: Math.max(1, source2.sourceSize.height)
    property real screenWidth: width
    property real screenHeight: height

    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_fade.frag.qsb")
  }

  // Wipe
  ShaderEffect {
    id: wipeShader
    anchors.fill: parent
    visible: root.transitionType === "wipe" && (root.hasCurrent || root.booting)

    property var source1: root.hasCurrent ? currentWallpaper : transparentSource
    property var source2: nextWallpaper
    property real progress: root.transitionProgress
    property real smoothness: root.edgeSmoothness
    property real direction: root.wipeDirection
    property real fillMode: 1.0
    property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : width)
    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : height)
    property real imageWidth2: Math.max(1, source2.sourceSize.width)
    property real imageHeight2: Math.max(1, source2.sourceSize.height)
    property real screenWidth: width
    property real screenHeight: height

    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_wipe.frag.qsb")
  }

  // Disc
  ShaderEffect {
    id: discShader
    anchors.fill: parent
    visible: root.transitionType === "disc" && (root.hasCurrent || root.booting)

    property var source1: root.hasCurrent ? currentWallpaper : transparentSource
    property var source2: nextWallpaper
    property real progress: root.transitionProgress
    property real smoothness: root.edgeSmoothness
    property real aspectRatio: root.width / Math.max(1.0, root.height)
    property real centerX: root.discCenterX
    property real centerY: root.discCenterY
    property real fillMode: 1.0
    property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : width)
    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : height)
    property real imageWidth2: Math.max(1, source2.sourceSize.width)
    property real imageHeight2: Math.max(1, source2.sourceSize.height)
    property real screenWidth: width
    property real screenHeight: height

    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_disc.frag.qsb")
  }

  // Stripes
  ShaderEffect {
    id: stripesShader
    anchors.fill: parent
    visible: root.transitionType === "stripes" && (root.hasCurrent || root.booting)

    property var source1: root.hasCurrent ? currentWallpaper : transparentSource
    property var source2: nextWallpaper
    property real progress: root.transitionProgress
    property real smoothness: root.edgeSmoothness
    property real aspectRatio: root.width / Math.max(1.0, root.height)
    property real stripeCount: root.stripesCount
    property real angle: root.stripesAngle
    property real fillMode: 1.0
    property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : width)
    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : height)
    property real imageWidth2: Math.max(1, source2.sourceSize.width)
    property real imageHeight2: Math.max(1, source2.sourceSize.height)
    property real screenWidth: width
    property real screenHeight: height

    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_stripes.frag.qsb")
  }

  // Portal
  ShaderEffect {
    id: portalShader
    anchors.fill: parent
    visible: root.transitionType === "portal" && (root.hasCurrent || root.booting)

    property var source1: root.hasCurrent ? currentWallpaper : transparentSource
    property var source2: nextWallpaper
    property real progress: root.transitionProgress
    // Provide same common uniforms many shaders expect
    property real smoothness: root.edgeSmoothness
    property real aspectRatio: root.width / Math.max(1.0, root.height)
    property real centerX: 0.5
    property real centerY: 0.5
    property real fillMode: 1.0
    property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
    property real imageWidth1: Math.max(1, root.hasCurrent ? source1.sourceSize.width : width)
    property real imageHeight1: Math.max(1, root.hasCurrent ? source1.sourceSize.height : height)
    property real imageWidth2: Math.max(1, source2.sourceSize.width)
    property real imageHeight2: Math.max(1, source2.sourceSize.height)
    property real screenWidth: width
    property real screenHeight: height

    fragmentShader: Qt.resolvedUrl("../Shaders/qsb/wp_portal.frag.qsb")
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
        if (nextWallpaper.source && nextWallpaper.status === Image.Ready) {
          currentWallpaper.source = nextWallpaper.source;
        }
        nextWallpaper.source = "";
        root.transitionProgress = 0.0;
      });
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
    if (!newUrl || newUrl === currentWallpaper.source)
      return;

    // If an animation is running, fast-forward and commit
    if (transitionAnim.running) {
      transitionAnim.stop();
      root.transitionProgress = 0.0;
      if (nextWallpaper.source)
        currentWallpaper.source = nextWallpaper.source;
      nextWallpaper.source = "";
    }

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
        currentWallpaper.source = nextWallpaper.source;
        nextWallpaper.source = "";
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
