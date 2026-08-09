pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// `active` owns stream lifecycle; callers use the completion signals instead of lifecycle handlers.
Process {
  id: root

  property bool _started: false
  readonly property Timer _restartTimer: Timer {
    interval: root.restartDelay

    onTriggered: root._sync()
  }
  property bool active: false
  property int restartDelay: 0

  signal errorRead(string line)
  signal failedToStart
  signal lineRead(string line)
  signal processExited(int exitCode)

  function _sync(): void {
    const want = root.active && !!root.command && root.command.length > 0;
    if (want !== root.running) {
      if (want)
        root._started = false;
      root.running = want;
    }
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
  onExited: exitCode => root.processExited(exitCode)
  onRunningChanged: {
    if (!root.running && root.active && !root._started)
      root.failedToStart();
    if (root.running || !root.active || root.restartDelay <= 0)
      return;
    _restartTimer.interval = root.restartDelay;
    _restartTimer.restart();
  }
  onStarted: root._started = true
}
