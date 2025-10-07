pragma Singleton
import QtQml
import Quickshell

Singleton {
  id: fs

  function listByGlob(pattern, callback) {
    let process = null;
    let collector = null;
    let timer = null;

    try {
      process = Qt.createQmlObject('import Quickshell.Io; Process {}', fs);
      collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { waitForEnd: true }', process);
      timer = Qt.createQmlObject('import QtQuick; Timer { interval: 10000; repeat: false }', process);

      process.stdout = collector;

      const cleanup = () => {
        if (timer)
          timer.destroy();
        if (collector)
          collector.destroy();
        if (process)
          process.destroy();
      };

      const complete = lines => {
        try {
          if (callback)
            callback(lines);
        } finally {
          cleanup();
        }
      };

      collector.onStreamFinished.connect(() => {
        const text = collector.text.trim();
        complete(text ? text.split(/\r?\n/) : []);
      });

      timer.triggered.connect(() => {
        if (process.running)
          process.running = false;
        complete([]);
      });

      timer.start();
      process.command = ["sh", "-c", `ls -1 ${String(pattern)} 2>/dev/null || true`];
      process.running = true;
    } catch (e) {
      if (timer)
        timer.destroy();
      if (collector)
        collector.destroy();
      if (process)
        process.destroy();
      if (callback)
        callback([]);
    }
  }
}
