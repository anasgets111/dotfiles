// Utils.qml
pragma Singleton
import Quickshell

Singleton {
    id: utils

    // Run a command and collect stdout; optionally parent the Process
    function runCmd(cmd, onDone, parent) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process { }', parent || utils);
        var c = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', p);
        p.stdout = c;
        c.onStreamFinished.connect(function () {
            onDone(c.text);
        });
        p.command = cmd;
        p.running = true;
    }

    // Remove ANSI escape sequences
    function stripAnsi(str) {
        return String(str).replace(/\x1B\[[0-9;]*[A-Za-z]/g, "");
    }

    // Shallow merge (b overrides a)
    function mergeObjects(a, b) {
        var out = {};
        for (var k in a)
            out[k] = a[k];
        for (var k2 in b)
            out[k2] = b[k2];
        return out;
    }
}
