pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Widgets

Rectangle {
  id: volumeControl

  readonly property bool audioReady: Pipewire.ready && serviceSink && serviceSink.audio
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
  readonly property string deviceIcon: {
    if (!serviceSink)
      return "";
    const props = serviceSink.properties || {};
    const iconName = props["device.icon_name"] || "";
    if (deviceIconMap[iconName])
      return deviceIconMap[iconName];

    const desc = (serviceSink.description || "").toLowerCase();
    for (var key in deviceIconMap)
      if (desc.indexOf(key) !== -1)
        return deviceIconMap[key];

    return (serviceSink.name || "").startsWith("bluez_output") ? deviceIconMap["headphone"] : "";
  }

  // Icon mapping
  readonly property var deviceIconMap: ({
      "headphone": "󰋋",
      "hands-free": "󰋎",
      "headset": "󰋎",
      "phone": "󰏲",
      "portable": "󰏲"
    })

  // Explicit expanded flag to avoid width-dependent logic races
  readonly property bool expanded: rootArea.containsMouse
  property int expandedWidth: 220
  property real maxVolume: 1.0          // allow > 1.0 for overamp
  property bool muted: false

  // Layout
  property int padding: 10
  property bool preserveChannelBalance: false

  // PipeWire state
  property PwNode serviceSink: Pipewire.defaultAudioSink
  property int sliderSteps: 20          // snapping steps

  // Behavior/config
  property real stepSize: 0.05          // 5% per tick

  // Hover animation suppression
  property bool suppressFillAnim: false
  property real volume: 0.0
  readonly property string volumeIcon: {
    const ratio = maxVolume > 0 ? (volume / maxVolume) : 0;
    return audioReady ? (deviceIcon || (muted ? "󰝟" : ratio < 0.01 ? "󰖁" : ratio < 0.33 ? "󰕿" : ratio < 0.66 ? "󰖀" : "󰕾")) : "--";
  }

  function averageVolumeFromAudio(audio) {
    if (!audio)
      return 0.0;
    const v = audio.volume;
    if (typeof v === "number" && !isNaN(v))
      return v;
    const arr = audio.volumes || [];
    return arr.length ? arr.reduce((a, x) => a + x, 0) / arr.length : 0.0;
  }
  function bindToSink() {
    volume = 0.0;
    muted = false;
    if (Pipewire.ready)
      serviceSink = Pipewire.defaultAudioSink;
    if (serviceSink && serviceSink.audio) {
      volume = averageVolumeFromAudio(serviceSink.audio);
      muted = !!serviceSink.audio.muted;
    }
  }

  // Centralized volume setter with optional channel balance preservation
  function setVolumeValue(v) {
    if (!audioReady)
      return;
    const clamped = Math.max(0, Math.min(maxVolume, v));
    const writeVal = maxVolume > 0 ? (clamped / maxVolume) : 0.0;
    const audio = serviceSink.audio;
    if (!audio)
      return;

    if (preserveChannelBalance) {
      const chans = audio.volumes || [];
      if (chans.length) {
        const oldAvg = averageVolumeFromAudio(audio);
        const ratio = oldAvg > 0 ? (writeVal / oldAvg) : 0;
        const newChans = chans.map(c => Math.max(0, Math.min(1, c * ratio)));
        audio.volumes = newChans;
        audio.volume = newChans.reduce((a, x) => a + x, 0) / newChans.length;
      } else {
        audio.volume = writeVal;
      }
    } else {
      audio.volume = writeVal;
      const chans2 = audio.volumes || [];
      if (chans2.length)
        audio.volumes = Array(chans2.length).fill(writeVal);
    }
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

  Component.onCompleted: bindToSink()
  Keys.onPressed: function (e) {
    if (!audioReady)
      return;
    if (e.key === Qt.Key_Left) {
      setVolumeValue(volume - stepSize * maxVolume);
      e.accepted = true;
    } else if (e.key === Qt.Key_Right) {
      setVolumeValue(volume + stepSize * maxVolume);
      e.accepted = true;
    } else if (e.key === Qt.Key_M) {
      muted = !muted;
      serviceSink.audio.muted = muted;
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
        volumeControl.muted = !volumeControl.muted;
        volumeControl.serviceSink.audio.muted = volumeControl.muted;
      }
    }
    onContainsMouseChanged: {
      volumeControl.suppressFillAnim = true;
      hoverTransitionTimer.restart();
    }
    onWheel: function (e) {
      if (!volumeControl.audioReady)
        return;

      const eff = (e.pixelDelta && e.pixelDelta.y) ? e.pixelDelta.y : e.angleDelta.y;
      if (!eff || Math.abs(eff) < 1) {
        e.accepted = true;
        return;
      }

      const unit = 50.0;
      __wheelAccum += eff;
      const whole = Math.trunc(__wheelAccum / unit);
      if (whole === 0) {
        e.accepted = true;
        return;
      }
      __wheelAccum -= whole * unit;

      const delta = whole * volumeControl.stepSize * volumeControl.maxVolume;
      volumeControl.setVolumeValue(volumeControl.volume + delta);
      e.accepted = true;
    }
  }
  Connections {
    function onDefaultAudioSinkChanged() {
      volumeControl.bindToSink();
    }
    function onReadyChanged() {
      volumeControl.bindToSink();
    }

    ignoreUnknownSignals: true
    target: Pipewire
  }
  Connections {
    function onAudioChanged() {
      volumeControl.bindToSink();
    }

    enabled: !!volumeControl.serviceSink
    ignoreUnknownSignals: true
    target: volumeControl.serviceSink
  }
  PwObjectTracker {
    objects: volumeControl.serviceSink && volumeControl.serviceSink.audio ? [volumeControl.serviceSink, volumeControl.serviceSink.audio] : (volumeControl.serviceSink ? [volumeControl.serviceSink] : [])
  }
  Connections {
    function onMutedChanged() {
      volumeControl.muted = volumeControl.serviceSink.audio.muted;
    }
    function onVolumeChanged() {
      volumeControl.volume = volumeControl.averageVolumeFromAudio(volumeControl.serviceSink.audio);
      sliderBg.committing = false;
    }

    enabled: !!(volumeControl.serviceSink && volumeControl.serviceSink.audio)
    ignoreUnknownSignals: true
    target: volumeControl.serviceSink && volumeControl.serviceSink.audio ? volumeControl.serviceSink.audio : null
  }
  Item {
    id: sliderBg

    property bool committing: false
    readonly property real currentNorm: (volumeControl.maxVolume > 0 ? (volumeControl.volume / volumeControl.maxVolume) : 0)
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
        volumeControl.setVolumeValue(stepped * volumeControl.maxVolume);
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
        text: volumeControl.audioReady ? (volumeControl.muted ? "0%" : (sliderBg.dragging || sliderBg.committing ? Math.round(sliderBg.pendingValue * 100) + "%" : Math.round(sliderBg.currentNorm * 100) + "%")) : "--"
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
