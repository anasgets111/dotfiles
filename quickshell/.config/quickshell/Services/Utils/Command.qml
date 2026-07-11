pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // Reusable Process instances. Grown on demand, never destroyed: destroying a
  // Quickshell Process from within its own exit handler is a use-after-free.
  // In-flight lanes are tracked by scanning this pool rather than mutating a
  // shared JS object — repeated key add/delete on a `property var` object churns
  // V4 internal classes and crashes under high-frequency calls.
  property var _pool: []

  function detached(argv: var): void {
    Quickshell.execDetached(argv);
  }

  function run(argv: var, callback: var, lane: var): void {
    let idle = null;
    for (let i = 0; i < root._pool.length; i++) {
      const candidate = root._pool[i];
      if (lane && candidate._busy && candidate._lane === lane)
        return;
      if (!candidate._busy && !idle)
        idle = candidate;
    }
    if (!idle) {
      idle = oneShot.createObject(root);
      root._pool.push(idle);
    }

    idle._busy = true;
    idle._callback = callback ?? null;
    idle._lane = lane ?? "";
    idle.command = argv;
    idle.stdinEnabled = true;
    idle.running = true;
  }

  Component {
    id: oneShot

    Process {
      property bool _busy: false
      property var _callback
      property string _lane
      property bool _started: false

      function _finish(exitCode: int): void {
        const callback = _callback;
        const result = {
          exitCode,
          stdout: outCollector.text,
          stderr: errCollector.text
        };
        _busy = false;
        _callback = null;
        _lane = "";
        _started = false;
        if (callback)
          callback(result);
      }

      stderr: StdioCollector {
        id: errCollector
      }
      stdout: StdioCollector {
        id: outCollector
      }

      onRunningChanged: if (_busy && !running && !_started)
        _finish(-1)
      onStarted: {
        _started = true;
        stdinEnabled = false;
      }
      onExited: exitCode => _finish(exitCode)
    }
  }
}
