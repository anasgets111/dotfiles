pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import QtQml.Models
import Quickshell
import qs.Config
import qs.Services
import qs.Services.Utils
import qs.Services.WM.Impl.Hyprland as Hypr
import qs.Services.WM.Impl.Niri as Niri

Singleton {
  id: root

  readonly property string _edidSweep: 'for edid in /sys/class/drm/*/edid; do printf "@@drm@@%s\\n" "${edid%/edid}"; edid-decode "$edid" 2>/dev/null; done; true'
  property var _edidCaps: null
  property var _edidCallbacks: []
  property var _edidHandle: null
  property int _featuresRunId: 0
  property bool _initialConfigWritten: false
  property var _savedDisplays: ({})
  property bool busy: false
  property int monitorsRevision: 0
  readonly property var _screenKeyFields: ["name", "width", "height"]
  // ListModel turns array-valued roles into nested models, so mode keys stay text.
  readonly property var _monitorDefaults: ({ displayModel: "", currentModeKey: "", modeKeysText: "", maxBpc: null, maxBpcSupported: null, colorMode: "srgb", transformMode: "normal", vrrMode: "off", vrrSupported: false, hdrSupported: false, displayBusy: false, errorText: "", featuresReady: false })
  readonly property string activeMain: activeMainScreen?.name ?? ""
  readonly property var activeMainScreen: Quickshell.screens.find(screen => screen?.name === preferredMain) || Quickshell.screens[0] || null
  readonly property var backend: MainService.currentWM === "hyprland" ? Hypr.MonitorImpl : MainService.currentWM === "niri" ? Niri.MonitorImpl : null
  readonly property var controls: Utils.toArray(backend?.controls)
  readonly property bool canPersist: Settings.isLoaded && !!backend?.saveConfig
  readonly property real scaleMaximum: Number.isFinite(backend?.scaleMaximum) ? backend.scaleMaximum : 3
  readonly property real scaleMinimum: Number.isFinite(backend?.scaleMinimum) ? backend.scaleMinimum : 0.25
  readonly property real scaleStep: Number.isFinite(backend?.scaleStep) && backend.scaleStep > 0 ? backend.scaleStep : 0.25
  readonly property var arrangementBounds: {
    const revision = monitorsRevision;
    const rects = toArray().map(monitor => _monitorRect(monitor));
    return {
      minX: rects.length ? Math.min(...rects.map(rect => rect.x)) : 0,
      minY: rects.length ? Math.min(...rects.map(rect => rect.y)) : 0,
      maxX: rects.length ? Math.max(...rects.map(rect => rect.x + rect.width)) : 1,
      maxY: rects.length ? Math.max(...rects.map(rect => rect.y + rect.height)) : 1
    };
  }
  property ListModel monitors: ListModel {
    dynamicRoles: true
  }
  property string preferredMain: MainService.mainMon || ""
  readonly property bool ready: backend !== null

  function findMonitorIndexByName(name: string): int {
    for (let index = 0; index < monitors.count; index++)
      if (monitors.get(index).name === name)
        return index;
    return -1;
  }
  function monitor(name: string): var {
    const index = findMonitorIndexByName(name);
    return index < 0 ? null : monitors.get(index);
  }
  function isSameMonitor(leftMonitor: var, rightMonitor: var): bool {
    return !!leftMonitor && !!rightMonitor && _screenKeyFields.every(key => leftMonitor[key] === rightMonitor[key]);
  }
  function supportsControl(field: string): bool {
    return controls.includes(field);
  }
  function controlOptions(field: string): var {
    return backend?.controlOptions ? Utils.toArray(backend.controlOptions(field)) : [];
  }
  function toArray(): var {
    return Array.from({ length: monitors.count }, (_unused, index) => monitors.get(index));
  }
  function setMonitorPropertyIfChanged(index: int, propertyName: string, value: var): void {
    if (monitors.get(index)[propertyName] === value)
      return;
    monitors.setProperty(index, propertyName, value);
    monitorsRevision++;
  }
  function _monitorRect(monitor: var): var {
    const scale = Number.isFinite(monitor?.displayScale) && monitor.displayScale > 0 ? monitor.displayScale : 1;
    return {
      x: Number.isFinite(monitor?.logicalX) ? monitor.logicalX : 0,
      y: Number.isFinite(monitor?.logicalY) ? monitor.logicalY : 0,
      width: Number.isFinite(monitor?.logicalWidth) && monitor.logicalWidth > 0 ? monitor.logicalWidth : Math.max(1, (monitor?.width ?? 1) / scale),
      height: Number.isFinite(monitor?.logicalHeight) && monitor.logicalHeight > 0 ? monitor.logicalHeight : Math.max(1, (monitor?.height ?? 1) / scale)
    };
  }
  function snapMonitorPosition(name: string, position: var, logicalWidth: real, logicalHeight: real, threshold: real): var {
    if (!Utils.isObject(position) || !Number.isFinite(position.x) || !Number.isFinite(position.y))
      return position;
    const limit = Number.isFinite(threshold) && threshold > 0 ? threshold : 24;
    const snap = (value, edges) => {
      let best = value;
      let distance = Infinity;
      for (const edge of edges) {
        const nextDistance = Math.abs(value - edge);
        if (nextDistance <= limit && nextDistance < distance) {
          best = edge;
          distance = nextDistance;
        }
      }
      return Math.round(best);
    };
    const rects = toArray().filter(monitor => monitor.name !== name).map(monitor => _monitorRect(monitor));
    return {
      x: snap(position.x, rects.reduce((edges, rect) => edges.concat([rect.x, rect.x + rect.width, rect.x - logicalWidth, rect.x + rect.width - logicalWidth]), [0])),
      y: snap(position.y, rects.reduce((edges, rect) => edges.concat([rect.y, rect.y + rect.height, rect.y - logicalHeight, rect.y + rect.height - logicalHeight]), [0]))
    };
  }
  function _storedDisplays(): var {
    const stored = Settings.data?.displays;
    return Utils.isObject(stored) ? Utils.clone(stored) : {};
  }
  function _sanitizeDisplays(displays: var): var {
    const sanitized = {};
    for (const name of Object.keys(displays)) {
      if (!Utils.isObject(displays[name]))
        continue;
      sanitized[name] = {};
      for (const field of controls)
        if (Utils.has(displays[name], field))
          sanitized[name][field] = Utils.clone(displays[name][field]);
    }
    return sanitized;
  }
  function _syncStoredMetadata(): void {
    for (let index = 0; index < monitors.count; index++) {
      const config = _savedDisplays[monitors.get(index).name];
      setMonitorPropertyIfChanged(index, "vrrMode", typeof config?.vrrMode === "string" && config.vrrMode ? config.vrrMode : "off");
    }
  }
  function _setMonitorState(name: string, isBusy: bool, errorText: string): void {
    const index = findMonitorIndexByName(name);
    if (index < 0)
      return;
    setMonitorPropertyIfChanged(index, "displayBusy", isBusy);
    setMonitorPropertyIfChanged(index, "errorText", errorText);
  }
  function _finishControl(name: string, result: var, callback: var): void {
    busy = false;
    if (name)
      _setMonitorState(name, false, result?.success ? "" : result?.message || "The compositor rejected the display change");
    if (typeof callback === "function")
      callback(result);
  }
  function _failControl(name: string, message: string, callback: var): void {
    const index = findMonitorIndexByName(name);
    if (index >= 0)
      setMonitorPropertyIfChanged(index, "errorText", message);
    if (typeof callback === "function")
      callback({ success: false, message });
  }
  function _seedMonitorConfig(monitor: var): var {
    const config = {};
    if (controls.includes("mode") && monitor.currentModeKey)
      config.mode = monitor.currentModeKey;
    if (controls.includes("scale") && Number.isFinite(monitor.displayScale) && monitor.displayScale > 0)
      config.scale = monitor.displayScale;
    if (controls.includes("transform") && monitor.transformMode)
      config.transform = monitor.transformMode;
    if (controls.includes("position") && Number.isInteger(monitor.logicalX) && Number.isInteger(monitor.logicalY))
      config.position = { x: monitor.logicalX, y: monitor.logicalY };
    // On-demand VRR cannot be distinguished from ordinary VRR in compositor state.
    if (controls.includes("maxBpc") && controlOptions("maxBpc").includes(monitor.maxBpc))
      config.maxBpc = monitor.maxBpc;
    return config;
  }
  function _withMonitorConfig(name: string, config: var): var {
    const displays = Utils.clone(_savedDisplays);
    displays[name] = config;
    return displays;
  }
  function _persist(displays: var, name: string, callback: var): void {
    const next = Utils.clone(displays);
    try {
      backend.saveConfig(next, activeMain, result => {
        if (result?.success) {
          root._savedDisplays = Utils.clone(next);
          Settings.data.displays = Utils.clone(next);
          root._syncStoredMetadata();
          root.refreshFeatures();
        }
        root._finishControl(name, result ?? { success: false, message: "Could not save the display configuration" }, callback);
      });
    } catch (error) {
      _finishControl(name, { success: false, message: error.message || "Could not save the display configuration" }, callback);
    }
  }
  function _applyMonitorChanges(index: int, changes: var): void {
    const roles = {
      mode: "currentModeKey",
      scale: "displayScale",
      transform: "transformMode",
      vrrMode: "vrrMode",
      maxBpc: "maxBpc",
      colorMode: "colorMode"
    };
    for (const field of Object.keys(roles))
      if (Utils.has(changes, field))
        setMonitorPropertyIfChanged(index, roles[field], changes[field]);
    if (Utils.has(changes, "position")) {
      setMonitorPropertyIfChanged(index, "logicalX", changes.position.x);
      setMonitorPropertyIfChanged(index, "logicalY", changes.position.y);
    }
  }
  function _canStartControl(name: string, changes: var, persist: bool, callback: var): int {
    const index = findMonitorIndexByName(name);
    const fields = Utils.isObject(changes) ? Object.keys(changes) : [];
    const available = (!persist || canPersist) && index >= 0 && fields.length > 0 && fields.every(field => controls.includes(field));
    if (!available || busy || monitors.get(index).displayBusy) {
      _failControl(name, available ? "A display change is already in progress" : "This display control is unavailable", callback);
      return -1;
    }
    busy = true;
    _setMonitorState(name, true, "");
    return index;
  }
  function _applyConfig(name: string, changes: var, callback: var): void {
    try {
      backend.applyConfig(name, changes, callback);
    } catch (error) {
      callback({ success: false, message: error.message || "The compositor rejected the display change" });
    }
  }
  function previewMonitorConfig(name: string, changes: var, callback: var): void {
    const index = _canStartControl(name, changes, false, callback);
    if (index < 0)
      return;
    _applyConfig(name, changes, result => {
      if (result?.success) {
        root._applyMonitorChanges(index, changes);
        root.refreshFeatures();
      }
      root._finishControl(name, result ?? { success: false, message: "The compositor rejected the display change" }, callback);
    });
  }
  function setMonitorConfig(name: string, changes: var, callback: var): void {
    const index = _canStartControl(name, changes, true, callback);
    if (index < 0)
      return;
    _applyConfig(name, changes, result => {
      if (!result?.success) {
        root._finishControl(name, result, callback);
        return;
      }
      root._applyMonitorChanges(index, changes);
      const current = root._savedDisplays[name];
      const config = Utils.isObject(current) ? Utils.clone(current) : root._seedMonitorConfig(root.monitors.get(index));
      Object.assign(config, Utils.clone(changes));
      root._persist(root._withMonitorConfig(name, config), name, callback);
    });
  }
  function resetMonitorConfig(name: string): void {
    const current = _savedDisplays[name];
    if (!canPersist || busy || !Utils.isObject(current)) {
      _failControl(name, busy ? "A display change is already in progress" : "There is no saved display override to reset", null);
      return;
    }
    const reset = Utils.clone(current);
    for (const field of controls)
      delete reset[field];
    busy = true;
    _setMonitorState(name, true, "");
    _persist(_withMonitorConfig(name, reset), name, null);
  }
  function _maybeInitializeDisplayConfig(): void {
    if (_initialConfigWritten || !canPersist || busy || !monitors.count || !toArray().every(monitor => monitor.featuresReady))
      return;
    const displays = _sanitizeDisplays(_storedDisplays());
    _savedDisplays = Utils.clone(displays);
    _syncStoredMetadata();
    for (const monitor of toArray())
      if (!Utils.isObject(displays[monitor.name]))
        displays[monitor.name] = _seedMonitorConfig(monitor);
    _initialConfigWritten = true;
    busy = true;
    _persist(displays, "", null);
  }
  function normalizeScreens(screens: var): var {
    return Array.from(screens).map(screen => {
      const existingIndex = findMonitorIndexByName(screen.name);
      return Object.assign({}, _monitorDefaults, {
        displayScale: screen.devicePixelRatio || 1,
        logicalX: screen.x,
        logicalY: screen.y,
        logicalWidth: screen.width,
        logicalHeight: screen.height
      }, existingIndex >= 0 ? monitors.get(existingIndex) : {}, {
        name: screen.name,
        width: screen.width,
        height: screen.height
      });
    });
  }
  function updateMonitors(newScreens: var): void {
    let changed = monitors.count !== newScreens.length;
    for (let index = 0; index < Math.min(monitors.count, newScreens.length); index++)
      if (!isSameMonitor(monitors.get(index), newScreens[index])) {
        monitors.set(index, newScreens[index]);
        changed = true;
      }
    while (monitors.count > newScreens.length)
      monitors.remove(monitors.count - 1);
    for (let index = monitors.count; index < newScreens.length; index++)
      monitors.append(newScreens[index]);
    if (changed)
      monitorsRevision++;
  }
  function _parseEdidCaps(text: string): var {
    const caps = ({});
    for (const block of text.split("@@drm@@").slice(1)) {
      const connector = block.slice(0, block.indexOf("\n")).replace(/^.*\//, "").replace(/^card\d+-/, "");
      const basicDepth = block.match(/Bits per primary color channel:\s*(\d+)/i);
      const depths = basicDepth ? [parseInt(basicDepth[1])] : [];
      for (const [flag, bpc] of [["DC_30bit", 10], ["DC_36bit", 12], ["DC_48bit", 16]])
        if (block.includes(flag))
          depths.push(bpc);
      caps[connector] = {
        vrr: /Adaptive-Sync|FreeSync|Vendor-Specific Data Block \(AMD\)/i.test(block),
        hdr: /HDR Static Metadata|SMPTE ST2084|HLG|BT2020/i.test(block),
        maxBpc: depths.length ? Math.max(...depths) : null
      };
    }
    return caps;
  }
  function _edidSelfCheck(): bool {
    const caps = _parseEdidCaps("@@drm@@/sys/class/drm/card0-DP-1\nBits per primary color channel: 8\nDC_30bit\nHDR Static Metadata")["DP-1"];
    return caps?.vrr === false && caps?.hdr === true && caps?.maxBpc === 10;
  }
  function _loadEdidCaps(callback: var): void {
    if (_edidCaps) {
      callback(_edidCaps);
      return;
    }
    _edidCallbacks.push(callback);
    if (_edidHandle)
      return;
    _edidHandle = Command.run(["sh", "-c", _edidSweep], result => {
      root._edidHandle = null;
      root._edidCaps = root._parseEdidCaps(result.exitCode === 0 ? result.stdout : "");
      root._edidCallbacks.splice(0).forEach(pending => pending(root._edidCaps));
    });
  }
  function _applyFeatures(index: int, features: var, caps: var): void {
    const current = monitors.get(index);
    const number = (value, fallback) => Number.isFinite(value) ? value : fallback;
    const text = (value, fallback) => typeof value === "string" && value ? value : fallback;
    const properties = {
      displayModel: text(features.displayModel, ""),
      currentModeKey: text(features.currentModeKey, ""),
      modeKeysText: Utils.toArray(features.modeKeys).filter(Boolean).join("\n"),
      colorMode: text(features.colorMode, "srgb"),
      transformMode: text(features.transformMode, current.transformMode),
      vrrMode: text(features.vrrMode, current.vrrMode),
      displayScale: number(features.scale, current.displayScale),
      maxBpc: number(features.maxBpc, null),
      logicalX: number(features.logicalX, current.logicalX),
      logicalY: number(features.logicalY, current.logicalY),
      logicalWidth: number(features.logicalWidth, current.logicalWidth),
      logicalHeight: number(features.logicalHeight, current.logicalHeight),
      vrrSupported: typeof features.vrrSupported === "boolean" ? features.vrrSupported : !!caps.vrr,
      hdrSupported: !!caps.hdr,
      maxBpcSupported: number(caps.maxBpc, null),
      featuresReady: true
    };
    for (const key of Object.keys(properties))
      setMonitorPropertyIfChanged(index, key, properties[key]);
  }
  function refreshFeatures(): void {
    if (!backend?.fetchFeatures)
      return;
    const adapter = backend;
    const runId = ++_featuresRunId;
    _loadEdidCaps(caps => {
      if (runId !== root._featuresRunId)
        return;
      for (const monitor of root.toArray()) {
        const name = monitor.name;
        adapter.fetchFeatures(name, features => {
          const index = root.findMonitorIndexByName(name);
          if (runId !== root._featuresRunId || !features || index < 0)
            return;
          root._applyFeatures(index, features, caps[name] ?? {});
          root._maybeInitializeDisplayConfig();
        });
      }
    });
  }
  function refreshScreens(invalidateCaps: bool): void {
    if (invalidateCaps) {
      _edidCaps = null;
      _edidHandle?.cancel();
      _edidHandle = null;
    }
    updateMonitors(normalizeScreens(Quickshell.screens));
    refreshFeatures();
  }

  Component.onCompleted: {
    console.assert(_edidSelfCheck(), "Monitor EDID parser self-check failed");
    refreshScreens(false);
  }

  onBackendChanged: {
    _initialConfigWritten = false;
    _savedDisplays = {};
    if (backend)
      refreshFeatures();
  }

  Connections {
    function onScreensChanged(): void {
      root.refreshScreens(true);
    }

    target: Quickshell
  }
  Connections {
    function onFeaturesChanged(): void {
      root.refreshScreens(false);
    }

    target: root.backend
  }
  Instantiator {
    model: Quickshell.screens

    delegate: Connections {
      required property ShellScreen modelData

      function onGeometryChanged(): void {
        root.refreshScreens(false);
      }
      function onOrientationChanged(): void {
        root.refreshScreens(false);
      }
      function onPhysicalPixelDensityChanged(): void {
        root.refreshScreens(false);
      }

      target: modelData
    }
  }
  Connections {
    function onIsLoadedChanged(): void {
      root._maybeInitializeDisplayConfig();
    }

    target: Settings
  }
}
