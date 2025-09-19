pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property int count: 44

  // Colors from cava config for visualization
  property var gradientColors: ["#3b3c59", "#4b4464", "#4b4464", "#6d5276", "#7f597e", "#926184", "#a4688a", "#b6708e", "#c87990", "#d98292"]
  property bool isRunning: false

  // Lighter version of gradient colors for visualization
  property var lighterGradientColors: gradientColors.map(function (color) {
    return Qt.lighter(color, 1.4);
  })
  property var values: []

  // Start the cava process
  function start() {
    if (!isRunning) {
      isRunning = true;
      cavaProcess.running = true;
    }
  }

  // Stop the cava process
  function stop() {
    isRunning = false;
    cavaProcess.running = false;
  }

  Component.onCompleted: {
    createConfigProcess.running = true;
  }
  Component.onDestruction: {
    root.stop();
  }

  Process {
    id: cavaProcess

    command: ["/usr/bin/cava", "-p", "/tmp/cava_config"]
    running: false

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        const line = data.trim();
        if (!line)
          return;
        const parts = line.split(';');
        const newValues = [];
        for (let i = 0; i < parts.length; i++) {
          const value = parseFloat(parts[i]);
          if (!Number.isNaN(value))
            newValues.push(Math.min(1.0, Math.max(0.0, value / 1000.0)));
        }
        if (newValues.length > 0)
          root.values = newValues;
      }
    }

    onRunningChanged: {
      if (!cavaProcess.running && root.isRunning) {
        // Restart if it was supposed to be running
        cavaProcess.running = true;
      }
    }
  }

  // Create cava config file
  Process {
    id: createConfigProcess

    command: ["bash", "-c", `
            cat > /tmp/cava_config << 'EOF'
[general]
autosens = 1
overshoot = 1
bars = 35
bar_width = 0.0
bar_spacing = 1.0

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
channels = stereo

[smoothing]
monstercat = 0
waves = 0
gravity = 100

[eq]
#1 = 1 # bass
#2 = 1
#3 = 1 # midtone
#4 = 1
#5 = 1 # treble
EOF
        `]
    running: false

    onRunningChanged: {
      if (!createConfigProcess.running) {
        root.start();
      }
    }
  }
}
