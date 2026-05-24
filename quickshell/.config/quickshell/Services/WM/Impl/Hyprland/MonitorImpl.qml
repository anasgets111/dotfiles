pragma Singleton
import Quickshell
import Quickshell.Hyprland
import qs.Services

Singleton {
  id: root

  readonly property bool enabled: MainService.ready && MainService.currentWM === "hyprland"

  function _findMonitor(name: string): var {
    const monitors = Hyprland.monitors?.values || [];
    return monitors.find(monitor => monitor && (monitor.name === name || monitor.id === name || monitor.identifier === name || monitor.outputName === name)) || null;
  }

  function fetchFeatures(name: string, callback: var): void {
    const monitor = _findMonitor(name);
    if (!monitor) {
      callback(null);
      return;
    }

    const modes = (monitor.availableModes || []).map(modeText => {
      const match = modeText.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
      return match ? {
        width: parseInt(match[1]),
        height: parseInt(match[2]),
        refreshRate: parseFloat(match[3])
      } : {
        raw: modeText
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
