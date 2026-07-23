pragma Singleton

import QtQuick
import Quickshell
import qs.Services.Core
import qs.Services.Utils

Singleton {
  id: root

  property bool _available: false
  readonly property int barCount: values.length
  property var values: Array(64).fill(0.12)

  function updateValues(line: string): void {
    const payload = line.endsWith(";") ? line.slice(0, -1) : line;
    if (!payload)
      return;
    const next = payload.split(";");
    for (let i = 0; i < next.length; i++) {
      const value = Number(next[i]);
      if (!Number.isFinite(value))
        return;
      next[i] = Math.max(0, Math.min(1, value / 1000));
    }
    values = next;
  }

  Component.onCompleted: Command.run(["cava", "-v"], result => root._available = result.exitCode === 0)

  CommandStream {
    id: cavaProcess

    active: root._available && MediaService.playing
    command: ["cava", "-p", Quickshell.shellPath("Assets/Cava/config")]
    restartDelay: 3000

    onErrorRead: line => {
      if (!line.trim())
        return;
      Logger.error("CavaService", line.trim());
    }
    onLineRead: line => {
      if (MediaService.playing)
        root.updateValues(line);
    }
  }
}
