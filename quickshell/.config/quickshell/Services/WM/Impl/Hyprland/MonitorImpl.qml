// HyprMonitorService.qml
pragma Singleton
import Quickshell
import qs.Services.Utils
import Quickshell.Hyprland
import qs.Services.Utils
import qs.Services

Singleton {
    id: hyprMonitorService
    readonly property bool active: MainService.ready && MainService.currentWM === "hyprland"

    // Enable/disable this backend (controlled by aggregator)
    readonly property bool enabled: hyprMonitorService.active

    function getAvailableFeatures(name, callback) {
        Utils.runCmd(["hyprctl", "monitors", "-j"], function (output) {
            try {
                const clean = Utils.stripAnsi(output).trim();
                const data = JSON.parse(clean);
                const mon = data.find(m => m.name === name);
                if (!mon) {
                    callback(null);
                    return;
                }
                const modes = (mon.availableModes || []).map(modeStr => {
                    const match = modeStr.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
                    if (match) {
                        return {
                            width: parseInt(match[1]),
                            height: parseInt(match[2]),
                            refreshRate: parseFloat(match[3])
                        };
                    }
                    return {
                        raw: modeStr
                    };
                });
                const hdrActive = mon.currentFormat && /2101010|P010|P012|PQ/i.test(mon.currentFormat);
                const isMirror = mon.mirrorOf && mon.mirrorOf !== "none";
                callback({
                    modes: modes,
                    vrr: {
                        active: !!mon.vrr
                    },
                    hdr: {
                        active: hdrActive
                    },
                    mirror: isMirror
                });
            } catch (e) {
                Logger.error("HyprMonitorService", "Failed to parse hyprctl output", e, output);
                callback(null);
            }
        });
    }

    function setMode(name, width, height, refreshRate) {
        Hyprland.dispatch("output", `${name},mode,${width}x${height}@${refreshRate}`);
    }
    function setScale(name, scale) {
        Hyprland.dispatch("output", `${name},scale,${scale}`);
    }
    function setTransform(name, transform) {
        Hyprland.dispatch("output", `${name},transform,${transform}`);
    }
    function setPosition(name, x, y) {
        Hyprland.dispatch("output", `${name},position,${x} ${y}`);
    }
    function setVrr(name, mode) {
        Hyprland.dispatch("output", `${name},vrr,${mode}`);
    }
}
