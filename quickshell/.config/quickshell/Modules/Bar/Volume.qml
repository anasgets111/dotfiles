pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.Core
import qs.Components
import qs.Modules.Bar

Rectangle {
  id: root

  readonly property real collapsedWidth: iconSize + 20
  readonly property real displayValue: volumeSlider.dragging ? volumeSlider.pending : sliderValue
  property bool expanded: hoverHandler.hovered
  readonly property string icon: {
    if (!ready)
      return "--";
    if (AudioService.sinkIcon)
      return AudioService.sinkIcon;
    if (muted)
      return "󰝟";
    const v = displayValue * maxVol; // actual volume 0-1.5
    if (v < 0.01)
      return "󰖁";
    if (v < 0.33)
      return "󰕿";
    if (v < 0.66)
      return "󰖀";
    return "󰕾";
  }
  readonly property int iconSize: Theme.fontSize * 1.5
  readonly property real maxVol: AudioService.maxVolume
  readonly property bool muted: AudioService.muted
  readonly property string percentText: {
    if (!ready)
      return "--";
    if (muted)
      return "0%";
    return Math.round(Math.min(displayValue * maxVol, 1.5) * 100) + "%";
  }
  readonly property bool ready: AudioService.sink?.audio ?? false

  // Slider value normalized to 0-1 range (where 1.0 = maxVolume)
  readonly property real sliderValue: volume / maxVol
  readonly property color textColor: {
    const ref = expanded && displayValue > 0.5 ? Theme.activeColor : color;
    return Theme.textContrast(ref);
  }
  readonly property real volume: AudioService.volume

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
    splitAt: 1.0 / root.maxVol  // Split at 100% (1.0/1.5 ≈ 0.67)
    steps: 30
    wheelStep: 1 / steps

    onCommitted: normalized => {
      if (root.ready)
        AudioService.setVolume(normalized * root.maxVol);
    }
  }

  RowLayout {
    anchors.centerIn: parent
    spacing: Theme.spacingSm

    OText {
      bold: true
      color: root.textColor
      font.pixelSize: root.iconSize
      horizontalAlignment: Text.AlignHCenter
      text: root.icon
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
