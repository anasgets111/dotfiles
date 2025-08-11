pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io

Singleton {
    id: niriMonitorService

    function runCmd(cmd, onDone) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', niriMonitorService);
        var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
        proc.stdout = collector;
        collector.onStreamFinished.connect(function () {
            onDone(collector.text);
        });
        proc.command = cmd;
        proc.running = true;
    }

    function getAvailableFeatures(name, callback) {
        // First get modes
        runCmd(["niri", "msg", "output", name, "mode", "help"], function (modeOutput) {
            const modes = [];
            modeOutput.split(/\r?\n/).forEach(line => {
                const match = line.trim().match(/^(\d+)x(\d+)@(\d+)/);
                if (match) {
                    modes.push({
                        width: parseInt(match[1]),
                        height: parseInt(match[2]),
                        refreshRate: parseInt(match[3])
                    });
                }
            });

            // Then check VRR
            runCmd(["niri", "msg", "output", name, "vrr", "help"], function (vrrOutput) {
                const vrrSupported = /on|adaptive/i.test(vrrOutput);
                callback({
                    modes: modes,
                    vrr: vrrSupported,
                    hdr: false // Niri doesn't expose HDR toggle yet
                });
            });
        });
    }

    // Control functions
    function setMode(name, width, height, refreshRate) {
        runCmd(["niri", "msg", "output", name, "mode", `${width}x${height}@${refreshRate}`], () => {});
    }
    function setScale(name, scale) {
        runCmd(["niri", "msg", "output", name, "scale", String(scale)], () => {});
    }
    function setTransform(name, transform) {
        runCmd(["niri", "msg", "output", name, "transform", transform], () => {});
    }
    function setPosition(name, x, y) {
        runCmd(["niri", "msg", "output", name, "position", `${x} ${y}`], () => {});
    }
    function setVrr(name, mode) {
        runCmd(["niri", "msg", "output", name, "vrr", mode], () => {});
    }
}
