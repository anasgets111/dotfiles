pragma Singleton
import Quickshell
import Quickshell.Hyprland
import qs.Services

Singleton {
  id: root

  readonly property bool active: MainService.ready && MainService.currentWM === "hyprland"

  function _findMonitor(name) {
    const monitors = Hyprland.monitors?.values || [];
    return monitors.find(m => {
      return m && (m.name === name || m.id === name || m.identifier === name || m.outputName === name);
    }) || null;
  }

  function fetchFeatures(name, callback) {
    const monitor = _findMonitor(name);

    if (!monitor) {
      callback(null);
      return;
    }

    const modes = (monitor.availableModes || []).map(modeStr => {
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
}
