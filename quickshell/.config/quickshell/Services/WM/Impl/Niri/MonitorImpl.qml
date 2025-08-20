// NiriMonitorService.qml
pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import qs.Services
import qs.Services.SystemInfo

Singleton {
    id: niriMonitorService
    property var logger: LoggerService
    readonly property bool active: MainService.ready && MainService.currentWM === "niri"
    readonly property bool enabled: niriMonitorService.active

    function runCmd(cmd, onDone) {
        const proc = Qt.createQmlObject('import Quickshell.Io; Process { }', niriMonitorService);
        const collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
        proc.stdout = collector;
        collector.onStreamFinished.connect(function () {
            onDone(collector.text);
        });
        proc.command = cmd;
        proc.running = true;
    }

    function getAvailableFeatures(name, callback) {
        runCmd(["niri", "msg", "outputs"], function (output) {
            const lines = output.split(/\r?\n/);
            let current = null;
            let result = null;
            let inModes = false;

            for (let line of lines) {
                line = line.trim();
                const outMatch = line.match(/^Output\s+"(.+)"\s+\(([^)]+)\)/);
                if (outMatch) {
                    if (current && current.name === name) {
                        result = current;
                        break;
                    }
                    current = {
                        fullName: outMatch[1],
                        name: outMatch[2],
                        modes: [],
                        vrr: {
                            active: false
                        },
                        hdr: {
                            active: false
                        }
                    };
                    inModes = false;
                    continue;
                }
                if (!current)
                    continue;
                if (line.startsWith("Variable refresh rate:")) {
                    if (/not supported/i.test(line)) {
                        current.vrr = {
                            active: false
                        };
                    } else {
                        current.vrr = {
                            active: /enabled|on/i.test(line)
                        };
                    }
                }
                if (line.startsWith("Available modes:")) {
                    inModes = true;
                    continue;
                }
                if (inModes) {
                    if (!line.startsWith(" ")) {
                        inModes = false;
                    } else {
                        const modeMatch = line.trim().match(/^(\d+)x(\d+)@([\d.]+)/);
                        if (modeMatch) {
                            current.modes.push({
                                width: parseInt(modeMatch[1]),
                                height: parseInt(modeMatch[2]),
                                refreshRate: parseFloat(modeMatch[3])
                            });
                        }
                    }
                }
            }
            if (current && current.name === name) {
                result = current;
            }
            if (result) {
                callback({
                    modes: result.modes,
                    vrr: result.vrr,
                    hdr: result.hdr
                });
            } else {
                callback(null);
            }
        });
    }

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
