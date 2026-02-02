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
    fillMode: Image.PreserveAspectCrop
    source: root.wallpaperPath ? `file://${root.wallpaperPath}` : ""
    visible: false  // Source only, not displayed directly
  }

  MultiEffect {
    anchors.fill: parent
    blur: Settings.data.overviewBlurStrength
    blurEnabled: true
    blurMax: Settings.data.overviewBlurMax
    blurMultiplier: Settings.data.overviewBlurMultiplier
    source: wallpaperSource
  }
}
