pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.Core
import qs.Components

Rectangle {
  id: root

  readonly property bool isAudioReady: !!(AudioService?.sink?.audio)
  readonly property real maxVolume: AudioService ? AudioService.maxVolume : 1.0
  readonly property bool isMuted: AudioService ? AudioService.muted : false
  readonly property real baseVolume: 1.0
  readonly property real displayMaxVolume: 1.5
  readonly property real currentVolume: AudioService ? AudioService.volume : 0.0
  readonly property string currentDeviceIcon: AudioService ? AudioService.sinkIcon : ""

  property bool expanded: hoverHandler.hovered
  property int expandedWidth: Theme.volumeExpandedWidth
  property int contentPadding: 10
  property int sliderStepCount: 30
  property bool isWidthAnimating: false

  TextMetrics {
    id: iconMetrics
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize + Theme.fontSize / 2
    text: "󰕾"
  }
  TextMetrics {
    id: percentMetrics
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: "100%"
  }

  readonly property real collapsedWidth: iconMetrics.width + 2 * contentPadding
  readonly property color textContrastColor: {
    const bg = color;
    if (!expanded)
      return Theme.textContrast(bg);
    const active = Theme.activeColor;
    const norm = volumeSlider ? (volumeSlider.dragging ? volumeSlider.pending : volumeSlider.value) : 0;
    const ref = norm > 0.5 ? active : bg;
    return Theme.textContrast(Qt.colorEqual(ref, "transparent") ? bg : ref);
  }
  readonly property string currentIcon: {
    const norm = volumeSlider ? (volumeSlider.dragging ? volumeSlider.pending : (displayMaxVolume > 0 ? currentVolume / displayMaxVolume : 0)) : 0;
    const valueAbs = norm * displayMaxVolume;
    const ratioBase = baseVolume > 0 ? Math.min(valueAbs / baseVolume, 1.0) : 0;
    return isAudioReady ? (currentDeviceIcon || (isMuted ? "󰝟" : ratioBase < 0.01 ? "󰖁" : ratioBase < 0.33 ? "󰕿" : ratioBase < 0.66 ? "󰖀" : "󰕾")) : "--";
  }
  readonly property string percentageText: {
    if (!isAudioReady)
      return "--";
    if (isMuted)
      return "0%";
    const vol = volumeSlider.dragging ? volumeSlider.pending * displayMaxVolume : currentVolume;
    return Math.round(Math.min(vol / baseVolume, 1.5) * 100) + "%";
  }

  function setAbsoluteVolume(absoluteVolume) {
    if (!isAudioReady || !AudioService)
      return;
    const clamped = Math.max(0, Math.min(maxVolume, absoluteVolume));
    AudioService.setVolumeReal(clamped);
  }

  activeFocusOnTab: true
  clip: true
  color: Theme.inactiveColor
  height: Theme.itemHeight
  radius: Theme.itemRadius
  width: expanded ? expandedWidth : collapsedWidth

  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
      onRunningChanged: root.isWidthAnimating = running
    }
  }

  HoverHandler {
    id: hoverHandler
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    onClicked: if (root.isAudioReady && AudioService)
      AudioService.toggleMute()
  }

  Slider {
    id: volumeSlider
    anchors.fill: parent
    steps: root.sliderStepCount
    wheelStep: 1 / steps
    animMs: (dragging || root.isWidthAnimating) ? 0 : Theme.animationDuration
    splitAt: root.displayMaxVolume > 0 ? Math.min(1, root.baseVolume / root.displayMaxVolume) : 1
    fillColor: Theme.activeColor
    headroomColor: Theme.critical
    radius: root.radius
    interactive: root.isAudioReady
    opacity: (root.expanded || dragging) ? 1 : 0
    onCommitted: function (normalized) {
      if (root.isAudioReady)
        root.setAbsoluteVolume(normalized * root.displayMaxVolume);
    }
  }

  onCurrentVolumeChanged: if (!volumeSlider.dragging)
    volumeSlider.value = root.displayMaxVolume > 0 ? currentVolume / root.displayMaxVolume : 0

  Component.onCompleted: volumeSlider.value = root.displayMaxVolume > 0 ? currentVolume / root.displayMaxVolume : 0

  RowLayout {
    anchors.centerIn: parent
    anchors.margins: root.contentPadding
    spacing: 8

    Item {
      id: volumeIconItem
      Layout.preferredHeight: Theme.itemHeight
      Layout.preferredWidth: iconMetrics.width
      clip: true
      Text {
        anchors.centerIn: parent
        color: root.textContrastColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + Theme.fontSize / 2
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.currentIcon
      }
    }

    Item {
      id: percentItem
      visible: root.expanded
      Layout.preferredHeight: root.expanded ? percentMetrics.height : 0
      Layout.preferredWidth: root.expanded ? percentMetrics.width : 0
      Text {
        anchors.centerIn: parent
        color: root.textContrastColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.percentageText
      }
    }
  }
}
