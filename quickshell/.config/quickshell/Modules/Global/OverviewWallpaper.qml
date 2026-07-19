pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Services.Core

WlrLayershell {
  id: root

  required property var monitor
  readonly property string screenName: monitor?.name ?? ""
  readonly property var screenObject: screenName ? Quickshell.screens.find(s => s?.name === screenName) : null
  readonly property string wallpaperPath: root.screenName ? WallpaperService.wallpaperPath(root.screenName) : ""

  exclusionMode: ExclusionMode.Ignore
  layer: WlrLayer.Background
  namespace: WallpaperService.overviewNamespace
  screen: screenObject

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }
  Image {
    id: wallpaperSource

    anchors.fill: parent
    cache: false
    fillMode: Image.PreserveAspectCrop
    source: root.wallpaperPath
    sourceSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
    visible: false
  }
  MultiEffect {
    anchors.fill: parent
    autoPaddingEnabled: false
    blur: Settings.data.overviewBlurStrength
    blurEnabled: true
    blurMax: Settings.data.overviewBlurMax
    blurMultiplier: Settings.data.overviewBlurMultiplier
    source: wallpaperSource
  }
}
