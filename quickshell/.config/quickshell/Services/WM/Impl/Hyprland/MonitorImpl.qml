pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Services.Utils

Singleton {
  id: root

  signal featuresChanged

  property int _featurePollsRemaining: 0
  readonly property string configPath: {
    const home = Quickshell.env("HOME") || "";
    const configHome = Quickshell.env("XDG_CONFIG_HOME") || (home ? home + "/.config" : "");
    return configHome ? configHome + "/Obelisk/monitors.lua" : "";
  }
  readonly property var controls: ["mode", "scale", "transform", "position", "vrrMode", "maxBpc", "icc", "lastIccProfile", "colorMode", "sdrBrightness", "sdrSaturation"]
  readonly property real scaleMaximum: 3
  readonly property real scaleMinimum: 0.25
  readonly property real scaleStep: 0.25
  readonly property var _transforms: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]
  readonly property var _vrrModes: ["off", "on", "fullscreen", "content-aware"]
  readonly property var _options: ({ transform: _transforms, vrrMode: _vrrModes, maxBpc: [8, 10], colorMode: ["srgb", "hdr", "hdredid"] })
  readonly property string _installScript: [
    "set -eu",
    "output=$1",
    "candidate=$output.candidate",
    "shift",
    'mkdir -p -- "${output%/*}"',
    'trap \'rm -f -- "$candidate"\' EXIT',
    'cat > "$candidate"',
    '"$@"',
    'if [ ! -f "$output" ] || ! cmp -s -- "$candidate" "$output"; then',
    '    mv -f -- "$candidate" "$output"',
    "fi"
  ].join("\n")

  function _bitDepthFromFormat(format: string): var {
    return /2101010|P010/i.test(format) ? 10 : /P012/i.test(format) ? 12 : /16161616|P016/i.test(format) ? 16 : /8888/i.test(format) ? 8 : null;
  }
  function _findMonitor(name: string): var {
    return Utils.toArray(Hyprland.monitors?.values).find(monitor => monitor?.name === name) || null;
  }
  function _displayModel(make: var, model: var): string {
    return [make, model].filter(part => typeof part === "string" && part && !/^0x[0-9a-f]+$/i.test(part)).join(" ");
  }
  function _safeText(value: var): bool {
    return typeof value === "string" && !!value && !/[\u0000-\u001f]/.test(value);
  }
  function _validValue(field: string, value: var): bool {
    if (field === "sdrBrightness" || field === "sdrSaturation") return Number.isFinite(value) && value >= 0.1 && value <= 5.0;
    if (field === "mode") return _safeText(value);
    if (field === "icc" || field === "lastIccProfile") return value === "" || (_safeText(value) && value.startsWith("/"));
    if (field === "scale") return Number.isFinite(value) && value > 0;
    if (field === "position") return Utils.isObject(value) && Number.isInteger(value.x) && Number.isInteger(value.y) && Object.keys(value).length === 2;
    return (_options[field] ?? []).includes(value);
  }
  function _validate(outputName: string, config: var, label: string): void {
    if (!_safeText(outputName) || !Utils.isObject(config))
      throw new Error(`${label} is not a supported display configuration`);
    for (const field of Object.keys(config))
      if (!controls.includes(field) || !_validValue(field, config[field]))
        throw new Error(`${label}.${field} is not a supported value`);
  }
  function _monitorSpec(outputName: string, config: var): var {
    const spec = { output: outputName };
    if (Utils.has(config, "mode"))
      spec.mode = config.mode;
    if (Utils.has(config, "position"))
      spec.position = `${config.position.x}x${config.position.y}`;
    if (Utils.has(config, "scale"))
      spec.scale = config.scale;
    if (Utils.has(config, "transform"))
      spec.transform = _transforms.indexOf(config.transform);
    if (Utils.has(config, "vrrMode"))
      spec.vrr = _vrrModes.indexOf(config.vrrMode);
    if (Utils.has(config, "maxBpc"))
      spec.bitdepth = config.maxBpc;
    if (config.icc)
      spec.icc = config.icc;
    if (config.colorMode)
      spec.cm = config.colorMode;
    if (Utils.has(config, "sdrBrightness"))
      spec.sdrbrightness = config.sdrBrightness;
    if (Utils.has(config, "sdrSaturation"))
      spec.sdrsaturation = config.sdrSaturation;
    return spec;
  }
  function _luaString(value: string): string {
    return `"${String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
  }
  function _luaTable(fields: var): string {
    return `{ ${Object.keys(fields).map(key => `${key} = ${typeof fields[key] === "string" ? _luaString(fields[key]) : fields[key]}`).join(", ")} }`;
  }
  function _renderMonitor(outputName: string, config: var): string {
    return `hl.monitor(${_luaTable(_monitorSpec(outputName, config))})`;
  }
  function _modeKeyFromState(state: var): string {
    let closest = Infinity;
    for (const modeText of Utils.toArray(state.availableModes)) {
      const match = String(modeText).match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
      if (match && parseInt(match[1]) === state.width && parseInt(match[2]) === state.height) {
        const rate = parseFloat(match[3]);
        if (Math.abs(rate - state.refreshRate) < Math.abs(closest - state.refreshRate)) closest = rate;
      }
    }
    return Utils.modeKey(state.width, state.height, Math.abs(closest - state.refreshRate) <= 0.1 ? closest : state.refreshRate);
  }
  // Hyprland accepts scale in 1/120 steps only when both logical dimensions remain integral.
  function _validScales(width: int, height: int): var {
    const scales = [];
    for (let step = Math.round(scaleMinimum * 120); step <= Math.round(scaleMaximum * 120); step++)
      if ((width * 120) % step === 0 && (height * 120) % step === 0)
        scales.push(step / 120);
    return scales;
  }
  function controlOptions(field: string): var {
    return _options[field] ?? [];
  }
  function fetchFeatures(name: string, callback: var): void {
    const state = _findMonitor(name)?.lastIpcObject;
    if (!state) {
      callback(null);
      return;
    }
    const modeKeys = Utils.toArray(state.availableModes).map(modeText => {
      const match = String(modeText).match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
      return match ? Utils.modeKey(parseInt(match[1]), parseInt(match[2]), parseFloat(match[3])) : "";
    });
    const rotated = [1, 3, 5, 7].includes(state.transform);
    callback({
      colorMode: state.colorManagementPreset,
      currentModeKey: _modeKeyFromState(state),
      displayModel: _displayModel(state.make, state.model),
      logicalHeight: (rotated ? state.width : state.height) / (state.scale || 1),
      logicalWidth: (rotated ? state.height : state.width) / (state.scale || 1),
      logicalX: state.x,
      logicalY: state.y,
      maxBpc: _bitDepthFromFormat(String(state.currentFormat ?? "")),
      modeKeys,
      scale: state.scale,
      scaleKeys: _validScales(state.width, state.height),
      transformMode: _transforms[state.transform] ?? "normal",
      // Hyprland reports whether VRR is active, not the configured mode.
      vrrMode: state.vrr ? "on" : "off",
      vrrSupported: true
    });
  }
  function _pollFeatures(): void {
    // ponytail: Ten polls cap this at one second; replace them when Hyprland exposes a
    // monitor-rule-applied completion event through Quickshell.
    _featurePollsRemaining = 10;
    Hyprland.refreshMonitors();
    featureRefreshPoll.restart();
  }
  function applyConfig(outputName: string, changes: var, callback: var): void {
    let script;
    try {
      _validate(outputName, changes, "changes");
      if (!Object.keys(changes).length)
        throw new Error("changes are empty");
      script = _renderMonitor(outputName, changes);
    } catch (error) {
      callback({ success: false, message: error.message });
      return;
    }
    const handle = Command.run(["hyprctl", "eval", script], result => {
      const ok = result.exitCode === 0;
      if (ok)
        root._pollFeatures();
      callback({
        success: ok,
        message: ok ? "" : (result.stderr || result.stdout || "Hyprland rejected the monitor change").trim()
      });
    }, `hypr-output-${outputName}`);
    if (!handle)
      callback({ success: false, message: "A display change is already in progress" });
  }
  function renderConfig(displays: var): string {
    if (!Utils.isObject(displays))
      throw new Error("displays must be an object");
    const names = Object.keys(displays).sort();
    for (const name of names)
      _validate(name, displays[name], `displays.${name}`);
    const lines = ["-- Generated by Obelisk. These are native hl.monitor tables.", "local monitors = {"];
    for (const name of names)
      lines.push(`  ${_luaTable(_monitorSpec(name, displays[name]))},`);
    lines.push("}", "", "for _, monitor in ipairs(monitors) do", "  hl.monitor(monitor)", "end", "", "return monitors", "");
    return lines.join("\n");
  }
  function saveConfig(displays: var, focusedOutput: string, callback: var): void {
    let text;
    try {
      if (!configPath)
        throw new Error("XDG_CONFIG_HOME and HOME are unavailable");
      text = renderConfig(displays);
    } catch (error) {
      callback({ success: false, message: error.message });
      return;
    }
    const handle = Command.run(["sh", "-c", _installScript, "sh", configPath, "luac", "-p", `${configPath}.candidate`], result => {
      if (result.exitCode !== 0) {
        callback({ success: false, message: (result.stderr || result.stdout || "Could not save the Hyprland display configuration").trim() });
        return;
      }
      const reload = Command.run(["hyprctl", "reload"], reloadResult => {
        const ok = reloadResult.exitCode === 0;
        if (ok)
          root._pollFeatures();
        callback({
          success: ok,
          message: ok ? "" : (reloadResult.stderr || reloadResult.stdout || "Could not reload Hyprland after saving the display configuration").trim()
        });
      }, "hypr-output-reload");
      if (!reload)
        callback({ success: false, message: "A Hyprland reload is already in progress" });
    }, "hypr-output-save", text);
    if (!handle)
      callback({ success: false, message: "A display configuration write is already in progress" });
  }
  function _selfCheck(): bool {
    const scales = _validScales(3440, 1440);
    const rendered = renderConfig({ "DP-1": { scale: 1.25, position: { x: 0, y: -1440 }, transform: "270", vrrMode: "content-aware", maxBpc: 10, icc: "/profiles/display.icc", colorMode: "hdr" } });
    return scales.includes(1) && scales.includes(1.25) && !scales.includes(1.5) && controls.every(field => ["mode", "position", "scale", "transform", "vrrMode", "maxBpc", "icc", "lastIccProfile", "colorMode", "sdrBrightness", "sdrSaturation"].includes(field)) && rendered.includes('{ output = "DP-1", position = "0x-1440", scale = 1.25, transform = 3, vrr = 3, bitdepth = 10, icc = "/profiles/display.icc", cm = "hdr" }') && rendered.includes("hl.monitor(monitor)") && rendered.includes("return monitors");
  }

  Component.onCompleted: console.assert(root._selfCheck(), "Hyprland monitor renderer self-check failed")

  Timer {
    id: featureRefreshPoll

    interval: 100
    repeat: true

    onTriggered: {
      Hyprland.refreshMonitors();
      if (--root._featurePollsRemaining <= 0)
        stop();
    }
  }
  Timer {
    id: featureRefreshDebounce

    interval: 50

    onTriggered: root.featuresChanged()
  }
  Connections {
    function onRawEvent(event: var): void {
      if (!["configreloaded", "fullscreen", "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2"].includes(event?.name))
        return;
      Hyprland.refreshMonitors();
    }

    target: Hyprland
  }
  Instantiator {
    model: Hyprland.monitors

    delegate: Connections {
      required property HyprlandMonitor modelData

      function onLastIpcObjectChanged(): void {
        featureRefreshDebounce.restart();
      }

      target: modelData
    }
  }
}
