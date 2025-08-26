// HyprMonitorService.qml
pragma Singleton
import Quickshell
import qs.Services.Utils
import Quickshell.Hyprland
import qs.Services

Singleton {
    id: hyprMonitorService

    readonly property bool active: MainService.ready && MainService.currentWM === "hyprland"

    function getAvailableFeatures(name, callback) {
        const monitorsRaw = Hyprland.monitors?.values || Hyprland.monitors || [];
        const monitors = Array.isArray(monitorsRaw) ? monitorsRaw : Object.values(monitorsRaw || {});
        function matches(candidate) {
            if (!candidate)
                return false;
            return candidate.name === name || candidate.id === name || candidate.identifier === name || candidate.outputName === name;
        }

        const monitor = monitors.find(matches);
        if (!monitor) {
            callback(null);
            return;
        }

        const modes = monitor.availableModes.map(modeStr => {
            const match = modeStr.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
            return match ? {
                width: parseInt(match[1]),
                height: parseInt(match[2]),
                refreshRate: parseFloat(match[3])
            } : {
                raw: modeStr
            };
        });

        const hdrActive = monitor.currentFormat && /2101010|P010|P012|PQ/i.test(monitor.currentFormat);
        const isMirror = monitor.mirrorOf && monitor.mirrorOf !== "none";

        callback({
            modes,
            vrr: {
                active: !!monitor.vrr
            },
            hdr: {
                active: hdrActive
            },
            mirror: isMirror
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
