pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.Core
import qs.Components
import qs.Modules.Bar

Rectangle {
  id: root

  readonly property real collapsedWidth: volumeIconSize + Theme.spacingLg
  readonly property real displayValue: volumeSlider.dragging ? volumeSlider.pending : sliderValue
  property bool expanded: hoverHandler.hovered
  readonly property bool isMuted: AudioService.muted
  readonly property real maxVolume: AudioService.maxVolume
  readonly property string percentText: {
    if (!ready)
      return "--";
    if (isMuted)
      return "0%";
    return Math.round(Math.min(displayValue * maxVolume, 1.5) * 100) + "%";
  }
  readonly property bool ready: AudioService.sink?.audio ?? false
  // Slider value normalized to 0-1 range (where 1.0 = maxVolume)
  readonly property real sliderValue: currentVolume / maxVolume
  readonly property color textColor: {
    const referenceColor = expanded && displayValue > 0.5 ? Theme.activeColor : color;
    return Theme.textContrast(referenceColor);
  }
  readonly property real currentVolume: AudioService.volume
  readonly property string volumeIcon: {
    if (!ready)
      return "--";
    if (AudioService.sinkIcon)
      return AudioService.sinkIcon;
    if (isMuted)
      return "󰝟";
    const volumeLevel = displayValue * maxVolume;
    if (volumeLevel < 0.01)
      return "󰖁";
    if (volumeLevel < 0.33)
      return "󰕿";
    if (volumeLevel < 0.66)
      return "󰖀";
    return "󰕾";
  }
  readonly property int volumeIconSize: Theme.iconSizeXl

  clip: true
  color: Theme.inactiveColor
  height: Theme.itemHeight
  radius: Theme.itemRadius
  width: expanded ? Theme.volumeExpandedWidth : collapsedWidth

  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  onSliderValueChanged: {
    if (!volumeSlider.dragging)
      volumeSlider.value = sliderValue;
  }

  HoverHandler {
    id: hoverHandler

  }

  MouseArea {
    acceptedButtons: Qt.MiddleButton | Qt.RightButton
    anchors.fill: parent

    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton && root.ready)
        AudioService.toggleMute();
      else if (mouse.button === Qt.RightButton)
        audioPanelLoader.active = true;
    }
  }

  Slider {
    id: volumeSlider

    anchors.fill: parent
    animMs: 0
    fillColor: Theme.activeColor
    headroomColor: Theme.critical
    interactive: root.ready
    opacity: root.expanded || dragging ? 1 : 0
    radius: root.radius
    splitAt: 1.0 / root.maxVolume  // Split at 100% (1.0/1.5 ≈ 0.67)
    steps: 30
    wheelStep: 1 / steps

    onCommitted: normalizedValue => {
      if (root.ready)
        AudioService.setVolume(normalizedValue * root.maxVolume);
    }
  }

  RowLayout {
    anchors.centerIn: parent
    spacing: Theme.spacingSm

    OText {
      bold: true
      color: root.textColor
      font.pixelSize: root.volumeIconSize
      horizontalAlignment: Text.AlignHCenter
      text: root.volumeIcon
    }

    OText {
      bold: true
      color: root.textColor
      horizontalAlignment: Text.AlignHCenter
      text: root.percentText
      verticalAlignment: Text.AlignVCenter
      visible: root.expanded
    }
  }

  Component {
    id: audioPanelComponent

    AudioPanel {
      property var loaderRef

      onPanelClosed: loaderRef.active = false
    }
  }

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
