pragma Singleton
import Quickshell

Singleton {
    id: fs

    function _newProc() {
        var p = Qt.createQmlObject('import Quickshell.Io; Process { }', fs);
        var c = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', p);
        p.stdout = c;
        return {
            proc: p,
            collector: c
        };
    }

    // List files matching a glob. Calls cb(arrayOfPaths)
    function listByGlob(pattern, cb) {
        try {
            var h = fs._newProc();
            h.collector.onStreamFinished.connect(function () {
                try {
                    var text = h.collector.text || "";
                    var lines = text.trim().length > 0 ? text.trim().split(/\r?\n/) : [];
                    if (cb)
                        cb(lines);
                } finally {
                    // cleanup transient objects
                    try {
                        h.collector.destroy();
                    } catch (e) {}
                    try {
                        h.proc.destroy();
                    } catch (e2) {}
                }
            });
            h.proc.command = ["bash", "-lc", "ls -1 " + String(pattern) + " 2>/dev/null || true"]; // safe: caller controls pattern
            h.proc.running = true;
        } catch (e) {
            if (cb)
                cb([]);
        }
    }

    function _quotePaths(paths) {
        if (!paths || !paths.length)
            return "";
        var out = [];
        for (var i = 0; i < paths.length; i++) {
            var p = String(paths[i]);
            out.push("'" + p.replace(/'/g, "'\\''") + "'");
        }
        return out.join(" ");
    }

    // Poll multiple groups of paths; returns array of booleans (any nonzero per group) in cb.
    function pollGroupsAnyNonzero(groups, cb) {
        if (!groups || !groups.length) {
            if (cb)
                cb([]);
            return;
        }
        var script = "";
        for (var i = 0; i < groups.length; i++) {
            var list = fs._quotePaths(groups[i] || []);
            var varName = "g" + i + "_on";
            script += varName + "=0; for p in " + (list || ":") + "; do v=$(cat \"$p\" 2>/dev/null || echo 0); if [ \"$v\" -gt 0 ]; then " + varName + "=1; break; fi; done; ";
        }
        script += "printf '";
        for (var j = 0; j < groups.length; j++) {
            script += "%s" + (j < groups.length - 1 ? " " : "");
        }
        script += "\\n'";
        for (var k = 0; k < groups.length; k++) {
            script += " \"$g" + k + "_on\"";
        }
        try {
            var h2 = fs._newProc();
            h2.collector.onStreamFinished.connect(function () {
                try {
                    var parts = (h2.collector.text || "").trim().split(/\s+/);
                    var out = [];
                    for (var i2 = 0; i2 < parts.length; i2++)
                        out.push(parts[i2] === "1");
                    if (cb)
                        cb(out);
                } finally {
                    try {
                        h2.collector.destroy();
                    } catch (e) {}
                    try {
                        h2.proc.destroy();
                    } catch (e2) {}
                }
            });
            h2.proc.command = ["bash", "-lc", script];
            h2.proc.running = true;
        } catch (e2) {
            if (cb)
                cb([]);
        }
    }
}
