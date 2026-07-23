pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Core
import qs.Services.Utils

Singleton {
  id: root

  property bool _available: false
  readonly property int barCount: values.length
  readonly property string configPath: Quickshell.shellPath("Assets/Cava/config")
  property var values: []

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

  FileView {
    path: root.configPath

    onLoaded: {
      const bars = parseInt(text().match(/^\s*bars\s*=\s*(\d+)/m)?.[1] ?? "0", 10);
      if (bars > 0 && root.values.length === 0)
        root.values = Array(bars).fill(0.12);
    }
  }
  CommandStream {
    id: cavaProcess

    active: root._available && MediaService.playing
    command: ["cava", "-p", root.configPath]
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
