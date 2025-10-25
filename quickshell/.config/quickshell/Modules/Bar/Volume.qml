pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.Core
import qs.Components
import qs.Modules.Bar

Rectangle {
  id: root

  readonly property real baseVolume: 1.0
  readonly property real collapsedWidth: iconMetrics.width + 2 * contentPadding
  property int contentPadding: 10
  readonly property string currentDeviceIcon: AudioService?.sinkIcon ?? ""
  readonly property string currentIcon: {
    if (!isAudioReady)
      return "--";

    const norm = volumeSlider?.dragging ? volumeSlider.pending : volumeSlider?.value ?? 0;
    const valueAbs = norm * displayMaxVolume;
    const ratioBase = Math.min(valueAbs / baseVolume, 1.0);

    if (currentDeviceIcon)
      return currentDeviceIcon;
    if (isMuted)
      return "󰝟";
    if (ratioBase < 0.01)
      return "󰖁";
    if (ratioBase < 0.33)
      return "󰕿";
    if (ratioBase < 0.66)
      return "󰖀";
    return "󰕾";
  }
  readonly property real currentVolume: AudioService?.volume ?? 0.0
  readonly property real displayMaxVolume: 1.5
  property bool expanded: hoverHandler.hovered
  property int expandedWidth: Theme.volumeExpandedWidth
  readonly property bool isAudioReady: AudioService?.sink?.audio ?? false
  readonly property bool isMuted: AudioService?.muted ?? false
  property bool isWidthAnimating: false
  readonly property real maxVolume: AudioService?.maxVolume ?? 1.0
  readonly property string percentageText: {
    if (!isAudioReady)
      return "--";
    if (isMuted)
      return "0%";
    const vol = volumeSlider.dragging ? volumeSlider.pending * displayMaxVolume : currentVolume;
    return Math.round(Math.min(vol / baseVolume, 1.5) * 100) + "%";
  }
  property int sliderStepCount: 30
  readonly property color textContrastColor: {
    if (!expanded)
      return Theme.textContrast(color);

    const norm = volumeSlider?.dragging ? volumeSlider.pending : volumeSlider?.value ?? 0;
    const ref = norm > 0.5 ? Theme.activeColor : color;
    return Theme.textContrast(Qt.colorEqual(ref, "transparent") ? color : ref);
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

  Component.onCompleted: {
    volumeSlider.value = currentVolume / displayMaxVolume;
  }
  onCurrentVolumeChanged: {
    if (!volumeSlider.dragging)
      volumeSlider.value = currentVolume / displayMaxVolume;
  }

  HoverHandler {
    id: hoverHandler

  }

  MouseArea {
    acceptedButtons: Qt.MiddleButton | Qt.RightButton
    anchors.fill: parent

    onClicked: function (mouse) {
      if (mouse.button === Qt.MiddleButton && root.isAudioReady && AudioService) {
        AudioService.toggleMute();
      } else if (mouse.button === Qt.RightButton) {
        audioPanelLoader.active = true;
      }
    }
  }

  Slider {
    id: volumeSlider

    anchors.fill: parent
    animMs: 0
    fillColor: Theme.activeColor
    headroomColor: Theme.critical
    interactive: root.isAudioReady
    opacity: (root.expanded || dragging) ? 1 : 0
    radius: root.radius
    splitAt: 2 / 3
    steps: root.sliderStepCount
    wheelStep: 1 / steps

    onCommitted: normalized => {
      if (root.isAudioReady)
        root.setAbsoluteVolume(normalized * root.displayMaxVolume);
    }
  }

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
        text: root.currentIcon
        verticalAlignment: Text.AlignVCenter
      }
    }

    Item {
      id: percentItem

      Layout.preferredHeight: root.expanded ? percentMetrics.height : 0
      Layout.preferredWidth: root.expanded ? percentMetrics.width : 0
      visible: root.expanded

      Text {
        anchors.centerIn: parent
        color: root.textContrastColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        text: root.percentageText
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  // Component definition for AudioPanel (better isolation)
  Component {
    id: audioPanelComponent

    AudioPanel {
      property var loaderRef

      onPanelClosed: loaderRef.active = false
    }
  }

  // Loader for lazy-loading the panel
  Loader {
    id: audioPanelLoader

    active: false
    sourceComponent: audioPanelComponent

    onLoaded: {
      const panel = item as AudioPanel;
      panel.loaderRef = audioPanelLoader;
      panel.openAtItem(root, 0, 0);
    }
  }
}
