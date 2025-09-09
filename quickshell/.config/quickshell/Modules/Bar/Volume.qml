pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Config
import qs.Services.Core

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
    const useColor = sliderBg.sliderValue > 0.5 ? leftColor : bg;
    return Theme.textContrast(Qt.colorEqual(useColor, "transparent") ? bg : useColor);
  }
  readonly property string deviceIcon: (AudioService ? AudioService.sinkIcon : "")

  // Icon mapping moved to AudioService

  // Explicit expanded flag to avoid width-dependent logic races
  readonly property bool expanded: rootArea.containsMouse
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
  // Bind to service volume (0..maxVolume)
  readonly property real volume: (AudioService ? AudioService.volume : 0.0)
  readonly property string volumeIcon: {
    // Determine ratio relative to 100% base for icon stages
    const norm = (sliderBg && typeof sliderBg.sliderValue === 'number') ? sliderBg.sliderValue : (displayMaxVolume > 0 ? (volume / displayMaxVolume) : 0);
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
  MouseArea {
    id: rootArea

    // Accumulate wheel deltas to snap to stepSize
    property real __wheelAccum: 0

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    anchors.fill: parent
    hoverEnabled: true

    onClicked: function (event) {
      if (!volumeControl.audioReady)
        return;
      if (event.button === Qt.MiddleButton) {
        if (AudioService)
          AudioService.toggleMute();
      }
    }
    onContainsMouseChanged: {
      volumeControl.suppressFillAnim = true;
      hoverTransitionTimer.restart();
    }
    onWheel: function (e) {
      if (!volumeControl.audioReady)
        return;

      // Use pixelDelta for high-precision touchpads; fall back to angleDelta for mouse wheels.
      // Qt angleDelta is in 1/8 degree units; one wheel notch is 15deg -> 120 units.
      const hasPixel = !!(e.pixelDelta && e.pixelDelta.y);
      const eff = hasPixel ? e.pixelDelta.y : e.angleDelta.y;
      if (!eff || Math.abs(eff) < 1) {
        e.accepted = true;
        return;
      }

      // Accumulate until we cross a unit threshold:
      // - touchpads: ~50px per step feels right (smooth)
      // - mouse wheels: 120 angle units per notch (exact)
      const unit = hasPixel ? 50.0 : 120.0;
      __wheelAccum += eff;
      const whole = Math.trunc(__wheelAccum / unit);
      if (whole === 0) {
        e.accepted = true;
        return;
      }
      __wheelAccum -= whole * unit;

      // Wheel steps should follow 5% of the 100% base, not of the 150% headroom
      const delta = whole * volumeControl.stepSize * volumeControl.baseVolume;
      volumeControl.setVolumeValue(volumeControl.volume + delta);
      e.accepted = true;
    }
  }
  Item {
    id: sliderBg

    property bool committing: false
    // Normalize fill to 150% range so the bar fills fully at 150%
    readonly property real currentNorm: (volumeControl.displayMaxVolume > 0 ? (volumeControl.volume / volumeControl.displayMaxVolume) : 0)
    property bool dragging: false
    property real pendingValue: currentNorm
    readonly property real sliderValue: (dragging || committing) ? pendingValue : currentNorm

    anchors.fill: parent

    ClippingRectangle {
      anchors.fill: parent
      color: "transparent"
      radius: volumeControl.radius
      visible: rootArea.containsMouse || sliderBg.dragging

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        color: Theme.activeColor
        width: parent.width * sliderBg.sliderValue

        Behavior on width {
          NumberAnimation {
            duration: (sliderBg.dragging || sliderBg.committing || volumeControl.suppressFillAnim) ? 0 : Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }
      }
    }
    MouseArea {
      function commitVolume(v) {
        if (!volumeControl.audioReady)
          return;
        const steps = Math.max(1, volumeControl.sliderSteps);
        const stepped = Math.round(v * steps) / steps;
        // Map normalized (0..1 over 0..150%) back to absolute volume
        volumeControl.setVolumeValue(stepped * volumeControl.displayMaxVolume);
        sliderBg.committing = false;
      }
      function update(x) {
        const raw = Math.min(1, Math.max(0, x / parent.width));
        const steps = Math.max(1, volumeControl.sliderSteps);
        sliderBg.pendingValue = Math.round(raw * steps) / steps;
      }

      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor

      onPositionChanged: function (e) {
        if (sliderBg.dragging)
          update(e.x);
      }
      onPressed: function (e) {
        sliderBg.dragging = true;
        update(e.x);
      }
      onReleased: function () {
        sliderBg.committing = true;
        sliderBg.dragging = false;
        commitVolume(sliderBg.pendingValue);
      }
    }
  }
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
      // Do not take space when collapsed
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
        text: volumeControl.audioReady ? (volumeControl.muted ? "0%" : (sliderBg.dragging || sliderBg.committing ? Math.round(Math.min(sliderBg.pendingValue * volumeControl.displayMaxVolume / volumeControl.baseVolume, 1.5) * 100) + "%" : Math.round(Math.min(volumeControl.volume / volumeControl.baseVolume, 1.5) * 100) + "%")) : "--"
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
