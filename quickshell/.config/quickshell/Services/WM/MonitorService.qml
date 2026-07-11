pragma Singleton
import Quickshell
import QtQml
import QtQuick
import qs.Services
import qs.Services.Utils
import qs.Services.WM.Impl.Hyprland as Hyprland
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: root

  property var _capsCache: ({})
  property var _drmCallbacks: []
  property var _drmEntries: null
  property bool _drmLoading: false
  property var _edidQueue: []
  property bool _edidRunning: false
  property int _featuresRunId: 0
  readonly property string activeMain: preferredMain || (monitors.count > 0 ? monitors.get(0).name : "")
  readonly property var activeMainScreen: Quickshell.screens.find(screen => screen?.name === activeMain) || Quickshell.screens[0] || null
  readonly property var backend: MainService.currentWM === "hyprland" ? Hyprland.MonitorImpl : MainService.currentWM === "niri" ? Niri.MonitorImpl : null
  readonly property var effectiveMainScreen: activeMainScreen
  readonly property var monitorKeyFields: ["name", "width", "height", "scale", "fps", "bitDepth", "orientation"]
  property ListModel monitors: ListModel {
  }
  property string preferredMain: MainService.mainMon || ""
  readonly property bool ready: backend !== null

  signal monitorsUpdated

  function _processEdidQueue(): void {
    if (_edidRunning || !_edidQueue.length)
      return;
    _edidRunning = true;
    const job = _edidQueue.shift();
    Command.run(["edid-decode", job.path], result => {
      root._edidRunning = false;
      if (job.callback)
        job.callback({
          vrr: {
            supported: /Adaptive-Sync|FreeSync|Vendor-Specific Data Block \(AMD\)/i.test(result.stdout)
          },
          hdr: {
            supported: /HDR Static Metadata|SMPTE ST2084|HLG|BT2020/i.test(result.stdout)
          }
        });
      root._processEdidQueue();
    });
  }

  function emitChangedDebounced(): void {
    changeDebounce.restart();
  }

  function findMonitorIndexByName(name: string): int {
    for (let monitorIndex = 0; monitorIndex < monitors.count; monitorIndex++)
      if (monitors.get(monitorIndex).name === name)
        return monitorIndex;
    return -1;
  }

  function isSameMonitor(leftMonitor: var, rightMonitor: var): bool {
    if (!leftMonitor || !rightMonitor)
      return false;
    return monitorKeyFields.every(key => leftMonitor[key] === rightMonitor[key]);
  }

  function normalizeScreens(screens: var): var {
    return Array.from(screens).map(screen => ({
          name: screen.name,
          width: screen.width,
          height: screen.height,
          scale: screen.devicePixelRatio || 1,
          fps: screen.refreshRate || 60,
          bitDepth: screen.colorDepth || 8,
          orientation: screen.orientation,
          vrr: "off",
          vrrSupported: false,
          hdrSupported: false,
          vrrActive: false,
          hdrActive: false
        }));
  }

  function readDrmEntries(callback: var): void {
    if (_drmEntries) {
      callback(_drmEntries);
      return;
    }
    if (typeof callback === "function")
      _drmCallbacks.push(callback);
    if (_drmLoading)
      return;
    _drmLoading = true;
    Command.run(["sh", "-c", "ls /sys/class/drm"], result => {
      root._drmLoading = false;
      root._drmEntries = result.stdout.split(/\r?\n/).filter(Boolean);
      root._drmCallbacks.splice(0).forEach(cb => cb(root._drmEntries));
    });
  }

  function readEdidCaps(connectorName: string, callback: var): void {
    const defaultCaps = {
      vrr: {
        supported: false
      },
      hdr: {
        supported: false
      }
    };
    readDrmEntries(entries => {
      const match = entries.find(line => line.endsWith(`-${connectorName}`));
      if (!match)
        return callback(defaultCaps);
      _edidQueue.push({
        path: `/sys/class/drm/${match}/edid`,
        callback
      });
      _processEdidQueue();
    });
  }

  function refreshFeatures(monitorsList: var): void {
    if (!backend?.fetchFeatures)
      return;
    const fetchFeatures = backend.fetchFeatures;
    const runId = ++_featuresRunId;

    for (const monitor of monitorsList) {
      const monitorName = monitor.name;
      const cachedCaps = _capsCache[monitorName];
      const updateCaps = caps => {
        if (runId !== _featuresRunId)
          return;
        const monitorIndex = findMonitorIndexByName(monitorName);
        if (monitorIndex < 0)
          return;
        const vrrSupported = !!(caps?.vrr?.supported);
        const hdrSupported = !!(caps?.hdr?.supported);
        let changed = setMonitorPropertyIfChanged(monitorIndex, "vrrSupported", vrrSupported);
        changed = setMonitorPropertyIfChanged(monitorIndex, "hdrSupported", hdrSupported) || changed;
        if (changed)
          emitChangedDebounced();

        fetchFeatures(monitorName, features => {
          if (runId !== _featuresRunId || !features)
            return;
          const featureIndex = findMonitorIndexByName(monitorName);
          if (featureIndex < 0)
            return;
          const vrrActive = !!(features.vrr && (features.vrr.active || features.vrr.enabled));
          const hdrActive = !!(features.hdr && (features.hdr.active || features.hdr.enabled));
          let featureChanged = setMonitorPropertyIfChanged(featureIndex, "vrrActive", vrrActive);
          featureChanged = setMonitorPropertyIfChanged(featureIndex, "hdrActive", hdrActive) || featureChanged;
          featureChanged = setMonitorPropertyIfChanged(featureIndex, "vrr", vrrActive ? "on" : "off") || featureChanged;
          if (featureChanged)
            emitChangedDebounced();
        });
      };

      cachedCaps ? updateCaps(cachedCaps) : readEdidCaps(monitorName, caps => {
        _capsCache[monitorName] = caps;
        updateCaps(caps);
      });
    }
  }

  function setMonitorPropertyIfChanged(monitorIndex: int, propertyName: string, value: var): bool {
    if (monitors.get(monitorIndex)[propertyName] === value)
      return false;
    monitors.setProperty(monitorIndex, propertyName, value);
    return true;
  }

  function toArray(): var {
    const result = [];
    for (let monitorIndex = 0; monitorIndex < monitors.count; monitorIndex++)
      result.push(monitors.get(monitorIndex));
    return result;
  }

  function updateMonitors(newScreens: var): void {
    const oldCount = monitors.count;
    const newCount = newScreens.length;
    let changed = false;

    const sharedCount = Math.min(oldCount, newCount);
    for (let monitorIndex = 0; monitorIndex < sharedCount; monitorIndex++) {
      const currentMonitor = monitors.get(monitorIndex);
      const nextMonitor = newScreens[monitorIndex];
      if (!isSameMonitor(currentMonitor, nextMonitor)) {
        monitors.set(monitorIndex, Object.assign({}, currentMonitor, nextMonitor));
        changed = true;
      }
    }
    if (oldCount > newCount) {
      changed = true;
      for (let monitorIndex = oldCount - 1; monitorIndex >= newCount; monitorIndex--) {
        monitors.remove(monitorIndex);
      }
    }
    if (newCount > oldCount) {
      changed = true;
      for (let monitorIndex = oldCount; monitorIndex < newCount; monitorIndex++)
        monitors.append(newScreens[monitorIndex]);
    }
    if (changed)
      emitChangedDebounced();
  }

  Component.onCompleted: {
    const norm = normalizeScreens(Quickshell.screens);
    updateMonitors(norm);
    if (backend)
      refreshFeatures(norm);
  }
  onBackendChanged: {
    if (backend)
      refreshFeatures(toArray());
  }

  Timer {
    id: changeDebounce

    interval: 0
    repeat: false

    onTriggered: root.monitorsUpdated()
  }

  Connections {
    function onScreensChanged() {
      const norm = root.normalizeScreens(Quickshell.screens);
      root.updateMonitors(norm);
      if (root.backend)
        root.refreshFeatures(norm);
    }

    target: Quickshell
  }

  Connections {
    function onFeaturesChanged() {
      root.refreshFeatures(root.toArray());
    }

    target: root.backend
  }

  Binding {
    property: "enabled"
    target: Hyprland.MonitorImpl
    value: root.backend === Hyprland.MonitorImpl
  }

  Binding {
    property: "enabled"
    target: Niri.MonitorImpl
    value: root.backend === Niri.MonitorImpl
  }
}
