pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// The Watch shape of the Command seam: a long-running, line-streamed command.
// Drive it with `active` (the caller's intent to be running) rather than `running`
// directly. When `restartDelay` > 0 the process is respawned that many ms after it
// dies while still active; set `restartBackoff` > 1 to grow the delay per consecutive
// attempt (capped at `maxRestartDelay`), and `maxRestarts` > 0 to give up after that
// many consecutive attempts. The attempt counter resets whenever `active` changes.
// Connect `onLineRead` / `onErrorRead` for stdout / stderr lines, and
// `onExited` if needed. Callers must NOT override `onRunningChanged`,
// `onActiveChanged` or `Component.onCompleted` — those own the start/restart lifecycle.
Process {
  id: root

  property int _restartCount: 0
  property bool active: false
  property int maxRestartDelay: 0
  property int maxRestarts: 0
  property real restartBackoff: 1
  property int restartDelay: 0
  property string splitMarker: "\n"

  signal errorRead(string line)
  signal lineRead(string line)

  function _sync(): void {
    const want = root.active && !!root.command && root.command.length > 0;
    if (want !== root.running)
      root.running = want;
  }

  stderr: SplitParser {
    splitMarker: root.splitMarker

    onRead: line => root.errorRead(line)
  }
  stdout: SplitParser {
    splitMarker: root.splitMarker

    onRead: line => root.lineRead(line)
  }

  onActiveChanged: {
    root._restartCount = 0;
    _restartTimer.stop();
    root._sync();
  }
  onRunningChanged: {
    if (root.running || !root.active || root.restartDelay <= 0)
      return;
    if (root.maxRestarts > 0 && root._restartCount >= root.maxRestarts)
      return;
    let delay = root.restartDelay * Math.pow(root.restartBackoff, root._restartCount);
    if (root.maxRestartDelay > 0)
      delay = Math.min(delay, root.maxRestartDelay);
    root._restartCount++;
    _restartTimer.interval = delay;
    _restartTimer.restart();
  }
  Component.onCompleted: root._sync()

  readonly property Timer _restartTimer: Timer {
    interval: root.restartDelay

    onTriggered: root._sync()
  }
}
