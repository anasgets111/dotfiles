pragma Singleton
import Quickshell
import Quickshell.Io
import QtQml
import QtQuick
import qs.Services
import qs.Services.WM.Impl.Hyprland as Hyprland
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: root

  property var _capsCache: ({})
  property var _drmEntries: null
  property var _edidQueue: []
  property int _featuresRunId: 0
  property var _pendingEdidCallback: null
  readonly property string activeMain: preferredMain || (monitors.count > 0 ? monitors.get(0).name : "")
  readonly property var activeMainScreen: Quickshell.screens.find(s => s?.name === activeMain) || Quickshell.screens[0] || null
  property var backend: MainService.currentWM === "hyprland" ? Hyprland.MonitorImpl : MainService.currentWM === "niri" ? Niri.MonitorImpl : null
  readonly property var effectiveMainScreen: activeMainScreen || Quickshell.screens.find(s => s?.name === lastKnownGoodMainName) || Quickshell.screens[0] || null
  property string lastKnownGoodMainName: ""
  readonly property var monitorKeyFields: ["name", "width", "height", "scale", "fps", "bitDepth", "orientation"]
  property ListModel monitors: ListModel {
  }
  property string preferredMain: MainService.mainMon || ""
  readonly property bool ready: backend !== null

  signal monitorsUpdated

  function _processEdidQueue() {
    if (_edidProc.running || !_edidQueue.length)
      return;
    const job = _edidQueue.shift();
    _pendingEdidCallback = job.cb;
    _edidProc.command = ["edid-decode", job.path];
    _edidProc.running = true;
  }

  function emitChangedDebounced() {
    changeDebounce.restart();
  }

  function findMonitorIndexByName(name) {
    for (let i = 0; i < monitors.count; i++)
      if (monitors.get(i).name === name)
        return i;
    return -1;
  }

  function getAvailableFeatures(name, callback) {
    const fn = backend?.fetchFeatures || backend?.getAvailableFeatures;
    fn ? fn(name, callback) : callback(null);
  }

  function isSameMonitor(monA, monB) {
    if (!monA || !monB)
      return false;
    return monitorKeyFields.every(key => monA[key] === monB[key]);
  }

  function normalizeScreens(screens) {
    return Array.from(screens).map(s => ({
          name: s.name,
          width: s.width,
          height: s.height,
          scale: s.devicePixelRatio || 1,
          fps: s.refreshRate || 60,
          bitDepth: s.colorDepth || 8,
          orientation: s.orientation,
          vrr: "off",
          vrrSupported: false,
          hdrSupported: false,
          vrrActive: false,
          hdrActive: false
        }));
  }

  function readDrmEntries(cb) {
    if (_drmEntries) {
      cb(_drmEntries);
      return;
    }
    _drmProc._cb = cb;
    _drmProc.running = true;
  }

  function readEdidCaps(connectorName, callback) {
    const def = {
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
        return callback(def);
      _edidQueue.push({
        path: `/sys/class/drm/${match}/edid`,
        cb: callback
      });
      _processEdidQueue();
    });
  }

  function refreshFeatures(monitorsList) {
    if (!backend || (!backend.fetchFeatures && !backend.getAvailableFeatures))
      return;
    const fetchFn = backend.fetchFeatures || backend.getAvailableFeatures;
    const runId = ++_featuresRunId;

    for (const m of monitorsList) {
      const name = m.name;
      const cached = _capsCache[name];
      const afterCaps = caps => {
        if (runId !== _featuresRunId)
          return;
        const idx1 = findMonitorIndexByName(name);
        if (idx1 < 0)
          return;
        const vrrSupported = !!(caps?.vrr?.supported);
        const hdrSupported = !!(caps?.hdr?.supported);
        let dirtyMeta = false;
        if (monitors.get(idx1).vrrSupported !== vrrSupported) {
          monitors.setProperty(idx1, "vrrSupported", vrrSupported);
          dirtyMeta = true;
        }
        if (monitors.get(idx1).hdrSupported !== hdrSupported) {
          monitors.setProperty(idx1, "hdrSupported", hdrSupported);
          dirtyMeta = true;
        }
        if (dirtyMeta)
          emitChangedDebounced();

        fetchFn(name, features => {
          if (runId !== _featuresRunId || !features)
            return;
          const idx2 = findMonitorIndexByName(name);
          if (idx2 < 0)
            return;
          const cur = monitors.get(idx2);
          let dirty = false;
          const vrrActive = !!(features.vrr && (features.vrr.active || features.vrr.enabled));
          const hdrActive = !!(features.hdr && (features.hdr.active || features.hdr.enabled));
          if (cur.vrrActive !== vrrActive) {
            monitors.setProperty(idx2, "vrrActive", vrrActive);
            dirty = true;
          }
          if (cur.hdrActive !== hdrActive) {
            monitors.setProperty(idx2, "hdrActive", hdrActive);
            dirty = true;
          }
          const legacy = vrrActive ? "on" : "off";
          if (cur.vrr !== legacy) {
            monitors.setProperty(idx2, "vrr", legacy);
            dirty = true;
          }
          if (dirty)
            emitChangedDebounced();
        });
      };

      cached ? afterCaps(cached) : readEdidCaps(name, caps => {
        _capsCache[name] = caps;
        afterCaps(caps);
      });
    }
  }

  function toArray() {
    const result = [];
    for (let i = 0; i < monitors.count; i++)
      result.push(monitors.get(i));
    return result;
  }

  function updateMonitors(newScreens) {
    const oldCount = monitors.count;
    const newCount = newScreens.length;
    let changed = false;

    const min = Math.min(oldCount, newCount);
    for (let i = 0; i < min; i++) {
      const cur = monitors.get(i);
      const inc = newScreens[i];
      if (!isSameMonitor(cur, inc)) {
        monitors.set(i, Object.assign({}, cur, inc));
        changed = true;
      }
    }
    if (oldCount > newCount) {
      changed = true;
      for (let i = oldCount - 1; i >= newCount; i--) {
        monitors.remove(i);
      }
    }
    if (newCount > oldCount) {
      changed = true;
      for (let i = oldCount; i < newCount; i++)
        monitors.append(newScreens[i]);
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
  onActiveMainScreenChanged: {
    if (root.activeMainScreen)
      root.lastKnownGoodMainName = root.activeMain;
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

    target: (root.backend && MainService.currentWM === "niri") ? root.backend : null
  }

  Process {
    id: _drmProc

    property var _cb: null

    command: ["sh", "-c", "ls /sys/class/drm"]

    stdout: StdioCollector {
      onStreamFinished: {
        root._drmEntries = text.split(/\r?\n/).filter(Boolean);
        const cb = _drmProc._cb;
        _drmProc._cb = null;
        if (cb)
          cb(root._drmEntries);
      }
    }
  }

  Process {
    id: _edidProc

    stdout: StdioCollector {
      onStreamFinished: {
        const cb = root._pendingEdidCallback;
        root._pendingEdidCallback = null;
        if (cb) {
          cb({
            vrr: {
              supported: /Adaptive-Sync|FreeSync|Vendor-Specific Data Block \(AMD\)/i.test(text)
            },
            hdr: {
              supported: /HDR Static Metadata|SMPTE ST2084|HLG|BT2020/i.test(text)
            }
          });
        }
        root._processEdidQueue();
      }
    }

    onRunningChanged: if (!running)
      root._processEdidQueue()
  }
}
