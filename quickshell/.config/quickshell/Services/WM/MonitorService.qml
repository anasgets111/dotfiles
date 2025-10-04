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

  property int _featuresRunId: 0
  property var _drmEntries: null
  property var _capsCache: ({})
  property var backend: MainService.currentWM === "hyprland" ? Hyprland.MonitorImpl : MainService.currentWM === "niri" ? Niri.MonitorImpl : null
  readonly property bool ready: backend !== null
  property ListModel monitors: ListModel {}
  property string preferredMain: MainService.mainMon || ""
  property string lastKnownGoodMainName: ""
  readonly property var monitorKeyFields: ["name", "width", "height", "scale", "fps", "bitDepth", "orientation"]
  readonly property string activeMain: preferredMain || (monitors.count > 0 ? monitors.get(0).name : "")
  readonly property var activeMainScreen: (() => {
      const screens = Quickshell.screens;
      return activeMain ? (screens.find(s => s?.name === activeMain) || screens[0] || null) : (screens[0] || null);
    })()
  readonly property var effectiveMainScreen: activeMainScreen || screenByName(lastKnownGoodMainName) || Quickshell.screens[0] || null

  signal monitorsUpdated

  function applySettings(settings) {
    if (!backend)
      return;
    const {
      name,
      width,
      height,
      refreshRate,
      scale,
      transform,
      position,
      vrr
    } = settings;
    if (width !== undefined && height !== undefined && refreshRate !== undefined)
      backend.setMode(name, width, height, refreshRate);
    if (scale !== undefined)
      backend.setScale(name, scale);
    if (transform !== undefined)
      backend.setTransform(name, transform);
    if (position?.x !== undefined && position?.y !== undefined)
      backend.setPosition(name, position.x, position.y);
    if (vrr !== undefined)
      backend.setVrr(name, vrr);
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
    return Array.prototype.slice.call(screens).map(screen => ({
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
  function readDrmEntries(cb) {
    if (_drmEntries) {
      cb(_drmEntries);
      return;
    }
    Utils.runCmd(["sh", "-c", "ls /sys/class/drm"], stdout => {
      _drmEntries = stdout.split(/\r?\n/).filter(Boolean);
      cb(_drmEntries);
    }, root);
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
      if (!match) {
        callback(def);
        return;
      }
      const edidPath = `/sys/class/drm/${match}/edid`;
      Utils.runCmd(["edid-decode", edidPath], text => {
        const vrrSupported = /Adaptive-Sync|FreeSync|Vendor-Specific Data Block \(AMD\)/i.test(text);
        const hdrSupported = /HDR Static Metadata|SMPTE ST2084|HLG|BT2020/i.test(text);
        callback({
          vrr: {
            supported: vrrSupported
          },
          hdr: {
            supported: hdrSupported
          }
        });
      }, root);
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
  function screenByName(name) {
    const screens = Quickshell.screens;
    return screens.find(s => s?.name === name) || screens[0] || null;
  }
  function setMode(name, width, height, refreshRate) {
    backend?.setMode(name, width, height, refreshRate);
  }
  function setPosition(name, x, y) {
    backend?.setPosition(name, x, y);
  }
  function setScale(name, scale) {
    backend?.setScale(name, scale);
  }
  function setTransform(name, transform) {
    backend?.setTransform(name, transform);
  }
  function setVrr(name, mode) {
    backend?.setVrr(name, mode);
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

  onActiveMainScreenChanged: {
    if (root.activeMainScreen)
      root.lastKnownGoodMainName = root.activeMain;
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      const norm = root.normalizeScreens(Quickshell.screens);
      root.updateMonitors(norm);
      if (root.backend)
        root.refreshFeatures(norm);
    }
  }
  Connections {
    target: (root.backend && MainService.currentWM === "niri") ? root.backend : null
    function onFeaturesChanged() {
      root.refreshFeatures(root.toArray());
    }
  }
}
