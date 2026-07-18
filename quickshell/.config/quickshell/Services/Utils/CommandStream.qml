pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// The Watch shape of the Command seam: a long-running, line-streamed command.
// Drive it with `active` (the caller's intent to be running) rather than `running`
// directly. When `restartDelay` > 0 the process is respawned that many ms after it
// dies while still active.
// Connect `onLineRead` / `onErrorRead` for stdout / stderr lines, and
// `onExited` if needed. Callers must NOT override `onRunningChanged`,
// `onActiveChanged` or `Component.onCompleted` — those own the start/restart lifecycle.
Process {
  id: root

  readonly property Timer _restartTimer: Timer {
    interval: root.restartDelay

    onTriggered: root._sync()
  }
  property bool active: false
  property int restartDelay: 0

  signal errorRead(string line)
  signal lineRead(string line)

  function _sync(): void {
    const want = root.active && !!root.command && root.command.length > 0;
    if (want !== root.running)
      root.running = want;
  }

  stderr: SplitParser {
    splitMarker: "\n"

    onRead: line => root.errorRead(line)
  }
  stdout: SplitParser {
    splitMarker: "\n"

    onRead: line => root.lineRead(line)
  }

  Component.onCompleted: root._sync()
  onActiveChanged: {
    _restartTimer.stop();
    root._sync();
  }
  onRunningChanged: {
    if (root.running || !root.active || root.restartDelay <= 0)
      return;
    _restartTimer.interval = root.restartDelay;
    _restartTimer.restart();
  }
}
