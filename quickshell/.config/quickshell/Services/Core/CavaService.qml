pragma Singleton

import QtQuick
import Quickshell
import qs.Services.Core
import qs.Services.Utils

Singleton {
  id: root

  property bool _available: false
  property var values: []

  // Cava emits `level;level;...;` at 30 fps, so the frame is parsed into the
  // existing array: allocating a new one per frame is what grew the heap.
  function updateValues(frame: string): void {
    if (!frame.endsWith(";"))
      return;
    const levels = root.values;
    let index = 0;
    let level = 0;
    for (let i = 0, length = frame.length; i < length; i++) {
      const code = frame.charCodeAt(i);
      if (code === 59) {
        levels[index++] = Math.min(1, level / 1000);
        level = 0;
      } else if (code >= 48 && code <= 57) {
        level = level * 10 + (code - 48);
      }
    }
    levels.length = index;
    root.valuesChanged();
  }

  Component.onCompleted: Command.run(["cava", "-v"], result => root._available = result.exitCode === 0)

  CommandStream {
    active: root._available && MediaService.playing
    command: ["cava", "-p", Quickshell.shellPath("Assets/Cava/config")]
    restartDelay: 3000

    onErrorRead: line => {
      const message = line.trim();
      if (message)
        Logger.error("CavaService", message);
    }
    onLineRead: line => root.updateValues(line)
  }
}
