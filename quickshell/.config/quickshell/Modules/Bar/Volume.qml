pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.Core
import qs.Components

Rectangle {
  id: volumeControl

  // Backed by AudioService singleton
  readonly property bool audioReady: AudioService && AudioService.sink && AudioService.sink.audio
  readonly property real collapsedWidth: volumeIconItem.implicitWidth + 2 * padding

  // Contrast for icon/percent
  readonly property color contrastColor: {
    const bg = color;
    if (!expanded)
      return Theme.textContrast(bg);
    const leftColor = Theme.activeColor;
    const norm = volSlider ? (volSlider.dragging ? volSlider.pending : volSlider.value) : 0;
    const useColor = norm > 0.5 ? leftColor : bg;
    return Theme.textContrast(Qt.colorEqual(useColor, "transparent") ? bg : useColor);
  }
  readonly property string deviceIcon: (AudioService ? AudioService.sinkIcon : "")

  // Icon mapping moved to AudioService

  // Explicit hover-expanded flag (tracked manually for better control)
  property bool expanded: false
  property int expandedWidth: Theme.volumeExpandedWidth
  // Pull policy from AudioService
  readonly property real maxVolume: (AudioService ? AudioService.maxVolume : 1.0)
  readonly property bool muted: (AudioService ? AudioService.muted : false)
  // 100% base (1.0) with headroom to 150% (1.5)
  readonly property real baseVolume: 1.0
  readonly property real displayMaxVolume: 1.5

  // Layout
  property int padding: 10
  property bool preserveChannelBalance: false
  property int sliderSteps: 30          // snapping steps (30 => 5% of base across 150%)

  // Behavior/config
  // Respect AudioService default if present
  readonly property real stepSize: (AudioService ? AudioService.stepVolume : 0.05)

  // Hover animation suppression
  property bool suppressFillAnim: false
  // Track if width is currently animating (0..animationDuration)
  property bool widthAnimating: false
  // Bind to service volume (0..maxVolume)
  readonly property real volume: (AudioService ? AudioService.volume : 0.0)
  // Keep slider in sync with external volume changes (avoid binding break on commit)
  onVolumeChanged: if (!volSlider.dragging)
    volSlider.value = (displayMaxVolume > 0 ? (volume / displayMaxVolume) : 0)
  readonly property string volumeIcon: {
    // Determine ratio relative to 100% base for icon stages
    const norm = (volSlider ? (volSlider.dragging ? volSlider.pending : volSlider.value) : (displayMaxVolume > 0 ? (volume / displayMaxVolume) : 0));
    const valueAbs = norm * displayMaxVolume;                // 0..1.5
    const ratioBase = baseVolume > 0 ? Math.min(valueAbs / baseVolume, 1.0) : 0; // 0..1.0
    return audioReady ? (deviceIcon || (muted ? "󰝟" : ratioBase < 0.01 ? "󰖁" : ratioBase < 0.33 ? "󰕿" : ratioBase < 0.66 ? "󰖀" : "󰕾")) : "--";
  }

  // Centralized volume setter with optional channel balance preservation
  function setVolumeValue(v) {
    if (!audioReady || !AudioService)
      return;
    const clamped = Math.max(0, Math.min(maxVolume, v));
    AudioService.setVolumeReal(clamped);
  }

  Accessible.name: "Volume"

  // Accessibility & keyboard controls
  Accessible.role: Accessible.Slider
  activeFocusOnTab: true
  clip: true
  color: Theme.inactiveColor
  focus: true
  height: Theme.itemHeight
  radius: Theme.itemRadius
  width: collapsedWidth

  states: [
    State {
      name: "hovered"
      when: volumeControl.expanded

      PropertyChanges {
        volumeControl.width: expandedWidth
      }
    }
  ]
  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
      onRunningChanged: if (running)
        volumeControl.widthAnimating = true
      else
        volumeControl.widthAnimating = false
    }
  }

  Keys.onPressed: function (e) {
    if (!audioReady)
      return;
    if (e.key === Qt.Key_Left) {
      if (AudioService)
        AudioService.decreaseVolume();
      e.accepted = true;
    } else if (e.key === Qt.Key_Right) {
      if (AudioService)
        AudioService.increaseVolume();
      e.accepted = true;
    } else if (e.key === Qt.Key_M) {
      if (AudioService)
        AudioService.toggleMute();
      e.accepted = true;
    }
  }
  Timer {
    id: hoverTransitionTimer
    interval: Theme.animationDuration
    onTriggered: volumeControl.suppressFillAnim = false
  }
  // Hover tracking (non-invasive)
  HoverHandler {
    id: hoverHandler
    onHoveredChanged: {
      volumeControl.suppressFillAnim = true;
      hoverTransitionTimer.restart();
      volumeControl.expanded = hovered;
    }
  }
  MouseArea {
    id: rootArea
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    anchors.fill: parent
    hoverEnabled: true
    onClicked: function (event) {
      if (!volumeControl.audioReady)
        return;
      if (event.button === Qt.MiddleButton && AudioService)
        AudioService.toggleMute();
    }
  }
  // Reusable normalized slider (0..1) scaled to displayMaxVolume (e.g. 0..1.5 absolute)
  Slider {
    id: volSlider
    anchors.fill: parent
    // Represent current volume in normalized headroom space
    // Initial value set on component completion & updated in onVolumeChanged
    steps: volumeControl.sliderSteps // 30 => 5% base increments across 150%
    wheelStep: 1 / steps
    // Animate fill during expansion (remove suppression flag)
    animMs: (volSlider.dragging || volumeControl.widthAnimating) ? 0 : Theme.animationDuration
    interactive: volumeControl.audioReady
    // Hide visual fill when collapsed (still allow wheel for quick adjust)
    opacity: (volumeControl.expanded || volSlider.dragging) ? 1 : 0
    onChanging: function (v) {}
    onCommitted: function (v) {
      if (!volumeControl.audioReady)
        return;
      // Map normalized (0..1 over headroom) back to absolute volume
      volumeControl.setVolumeValue(v * volumeControl.displayMaxVolume);
    }
  }
  Component.onCompleted: volSlider.value = (displayMaxVolume > 0 ? (volume / displayMaxVolume) : 0)
  RowLayout {
    anchors.centerIn: parent
    anchors.margins: volumeControl.padding
    spacing: 8

    // measurement helpers
    Text {
      id: maxIconMeasure

      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize + Theme.fontSize / 2
      text: "󰕾"
      visible: false
    }
    Text {
      id: maxPercentMeasure

      font.bold: true
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      text: "100%"
      visible: false
    }
    Item {
      id: volumeIconItem

      Layout.preferredHeight: implicitHeight
      Layout.preferredWidth: implicitWidth
      clip: true
      implicitHeight: maxIconMeasure.paintedHeight
      implicitWidth: maxIconMeasure.paintedWidth

      Text {
        anchors.centerIn: parent
        color: volumeControl.contrastColor
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + Theme.fontSize / 2
        horizontalAlignment: Text.AlignHCenter
        text: volumeControl.volumeIcon
        verticalAlignment: Text.AlignVCenter
      }
    }
    Item {
      id: percentItem
      Layout.preferredHeight: volumeControl.expanded ? implicitHeight : 0
      Layout.preferredWidth: volumeControl.expanded ? implicitWidth : 0
      implicitHeight: maxPercentMeasure.paintedHeight
      implicitWidth: maxPercentMeasure.paintedWidth
      visible: volumeControl.expanded

      Text {
        anchors.centerIn: parent
        color: volumeControl.contrastColor
        elide: Text.ElideRight
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        // Show percent relative to 100% base; allow up to 150%
        text: volumeControl.audioReady ? (volumeControl.muted ? "0%" : (volSlider.dragging ? Math.round(Math.min(volSlider.pending * volumeControl.displayMaxVolume / volumeControl.baseVolume, 1.5) * 100) + "%" : Math.round(Math.min(volumeControl.volume / volumeControl.baseVolume, 1.5) * 100) + "%")) : "--"
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
