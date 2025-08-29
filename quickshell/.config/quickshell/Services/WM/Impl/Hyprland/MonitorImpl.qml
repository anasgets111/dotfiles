pragma Singleton
import Quickshell
import Quickshell.Hyprland
import qs.Services

Singleton {
  id: hyprMonitorService

  readonly property bool active: MainService.ready && MainService.currentWM === "hyprland"

  function fetchFeatures(name, callback) {
    const monitors = (Hyprland.monitors && Hyprland.monitors.values) || [];
    const monitor = monitors.find(m => {
      return m && (m.name === name || m.id === name || m.identifier === name || m.outputName === name);
    });
    if (!monitor) {
      callback(null);
      return;
    }
    const modes = (monitor.availableModes || []).map(modeStr => {
      const match = modeStr.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
      return match ? {
        "width": parseInt(match[1]),
        "height": parseInt(match[2]),
        "refreshRate": parseFloat(match[3])
      } : {
        "raw": modeStr
      };
    });
    const hdrActive = monitor.currentFormat && /2101010|P010|P012|PQ/i.test(monitor.currentFormat);
    const isMirror = monitor.mirrorOf && monitor.mirrorOf !== "none";
    callback({
      "modes": modes,
      "vrr": {
        "active": !!monitor.vrr
      },
      "hdr": {
        "active": hdrActive
      },
      "mirror": isMirror
    });
  }
  function setMode(name, width, height, refreshRate) {
    Hyprland.dispatch("output", `${name},mode,${width}x${height}@${refreshRate}`);
  }
  function setPosition(name, x, y) {
    Hyprland.dispatch("output", `${name},position,${x} ${y}`);
  }
  function setScale(name, scale) {
    Hyprland.dispatch("output", `${name},scale,${scale}`);
  }
  function setTransform(name, transform) {
    Hyprland.dispatch("output", `${name},transform,${transform}`);
  }
  function setVrr(name, mode) {
    Hyprland.dispatch("output", `${name},vrr,${mode}`);
  }
}
