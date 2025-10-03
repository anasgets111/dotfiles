pragma Singleton
import QtQml
import Quickshell

Singleton {
  id: fs

  function _newProc() {
    const proc = Qt.createQmlObject('import Quickshell.Io; Process { }', fs);
    const collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
    proc.stdout = collector;
    return {
      proc,
      collector
    };
  }

  function _safeDestroy(obj) {
    if (!obj)
      return;
    try {
      if (obj && typeof obj.destroy === 'function')
        obj.destroy();
    } catch (_) {}
  }

  function _quotePaths(paths) {
    return (paths || []).map(p => "'" + String(p).replace(/'/g, "'\\''") + "'").join(" ");
  }

  // List files matching a glob. Calls cb(arrayOfPaths)
  function listByGlob(pattern, cb) {
    let proc = null;
    let collector = null;
    let timer = null;
    let finished = false;

    const cleanup = () => {
      if (timer)
        _safeDestroy(timer);
      if (collector)
        _safeDestroy(collector);
      if (proc)
        _safeDestroy(proc);
      timer = null;
      collector = null;
      proc = null;
    };

    const complete = lines => {
      if (finished)
        return;
      finished = true;
      try {
        if (cb)
          cb(lines);
      } finally {
        cleanup();
      }
    };

    try {
      const created = fs._newProc();
      proc = created?.proc || null;
      collector = created?.collector || null;

      if (!proc || !collector) {
        complete([]);
        return;
      }

      collector.onStreamFinished.connect(function () {
        const text = (collector.text || "").trim();
        complete(text ? text.split(/\r?\n/) : []);
      });

      if (proc.exited) {
        proc.exited.connect(function () {
          const text = collector ? (collector.text || "").trim() : "";
          complete(text ? text.split(/\r?\n/) : []);
        });
      }

      timer = Qt.createQmlObject('import QtQuick; Timer { interval: 10000; repeat: false }', proc);
      timer.triggered.connect(function () {
        if (proc && proc.running) {
          try {
            proc.running = false;
          } catch (_) {}
        }
        complete([]);
      });
      timer.start();

      proc.command = ["bash", "--noprofile", "--norc", "-c", "ls -1 " + String(pattern) + " 2>/dev/null || true"]; // safe: caller controls pattern
      proc.running = true;
    } catch (e) {
      cleanup();
      if (cb)
        cb([]);
    }
  }
}
