pragma Singleton
import QtQuick
import Quickshell
import qs.Services.Utils
import qs.Services.WM.Impl.Niri

Singleton {
  id: root

  signal featuresChanged

  readonly property var controls: ["mode", "scale", "transform", "position", "vrrMode", "maxBpc"]
  // The matching include in config.kdl is literal, so this path cannot follow Settings.configDir.
  readonly property string configPath: Quickshell.env("HOME") ? Quickshell.env("HOME") + "/.config/Obelisk/outputs.kdl" : ""
  // 6 bpc is below every modern panel's native depth and only saves link bandwidth.
  readonly property var maxBpcValues: [8, 10, 12, 14, 16]
  readonly property real scaleMaximum: 3
  readonly property real scaleMinimum: 0.25
  readonly property real scaleStep: 0.25
  readonly property var _transforms: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]
  readonly property var _vrrModes: ["off", "on", "on-demand"]
  readonly property var _options: ({ transform: _transforms, vrrMode: _vrrModes, maxBpc: maxBpcValues })
  readonly property string _installScript: [
    "set -eu",
    "output=$1",
    "candidate=$output.candidate",
    "shift",
    'mkdir -p -- "${output%/*}"',
    "trap 'rm -f -- \"$candidate\"' EXIT",
    'cat > "$candidate"',
    '"$@"',
    'if [ ! -f "$output" ] || ! cmp -s -- "$candidate" "$output"; then',
    '    mv -f -- "$candidate" "$output"',
    "fi"
  ].join("\n")

  function controlOptions(field: string): var {
    return _options[field] ?? [];
  }
  function _safeText(value: var): bool {
    return typeof value === "string" && !!value && !/[\u0000-\u001f]/.test(value);
  }
  function _validValue(field: string, value: var): bool {
    if (field === "mode") return _safeText(value);
    if (field === "scale") return Number.isFinite(value) && value > 0;
    if (field === "position") return Utils.isObject(value) && Number.isInteger(value.x) && Number.isInteger(value.y) && Object.keys(value).length === 2;
    return (_options[field] ?? []).includes(value);
  }
  function _validate(config: var, label: string): void {
    if (!Utils.isObject(config) || !_safeText(config.selector))
      throw new Error(`${label} needs a selector string`);
    for (const field of Object.keys(config))
      if (field !== "selector" && field !== "lastIccProfile" && field !== "icc" && (!controls.includes(field) || !_validValue(field, config[field])))
        throw new Error(`${label}.${field} is not a supported value`);
  }
  function _renderMonitor(config: var, focusedOutput: string): string {
    const lines = [`output ${JSON.stringify(config.selector)} {`];
    if (Utils.has(config, "mode"))
      lines.push(`    mode ${JSON.stringify(config.mode)}`);
    if (Utils.has(config, "scale"))
      lines.push(`    scale ${config.scale}`);
    if (Utils.has(config, "transform"))
      lines.push(`    transform ${JSON.stringify(config.transform)}`);
    if (Utils.has(config, "position"))
      lines.push(`    position x=${config.position.x} y=${config.position.y}`);
    if (config.vrrMode === "on")
      lines.push("    variable-refresh-rate");
    else if (config.vrrMode === "on-demand")
      lines.push("    variable-refresh-rate on-demand=true");
    if (Utils.has(config, "maxBpc"))
      lines.push(`    max-bpc ${config.maxBpc}`);
    if (config.selector === focusedOutput)
      lines.push("    focus-at-startup");
    lines.push("}");
    return lines.join("\n");
  }
  function renderConfig(displays: var, focusedOutput: string): string {
    if (!Utils.isObject(displays))
      throw new Error("displays must be an object");
    const configs = Object.keys(displays).sort().map(name => Object.assign({}, displays[name], { selector: name }));
    configs.forEach((config, index) => _validate(config, `displays[${index}]`));
    return configs.length ? configs.map(config => _renderMonitor(config, focusedOutput)).join("\n\n") + "\n" : "";
  }
  function _selfCheck(): bool {
    const rendered = renderConfig({ "eDP-1": { mode: "1920x1200@60.001" }, "Lenovo Group Limited Y34wz-30": { vrrMode: "on-demand" } }, "eDP-1");
    try {
      renderConfig({ "eDP-1": { scale: "1" } }, "eDP-1");
      return false;
    } catch (error) {
      return rendered.includes('output "eDP-1"') && rendered.includes("focus-at-startup") && rendered.includes("variable-refresh-rate on-demand=true");
    }
  }
  function _transformKey(value: var): string {
    // Niri serialises its rotation variants as "_90"/"Flipped90".
    const key = String(value ?? "normal").toLowerCase().replace(/^_/, "").replace(/^flipped[-_]?(\d)/, "flipped-$1");
    return _transforms.includes(key) ? key : "normal";
  }
  function _displayModel(make: var, model: var): string {
    // A bare EDID product code identifies nothing a person would recognise.
    return [make, model].filter(part => typeof part === "string" && part && !/^0x[0-9a-f]+$/i.test(part)).join(" ");
  }
  function _commandForChange(outputName: string, field: string, value: var): var {
    switch (field) {
    case "mode":
      return ["niri", "msg", "output", outputName, "mode", value];
    case "scale":
      return ["niri", "msg", "output", outputName, "scale", String(value)];
    case "transform":
      return ["niri", "msg", "output", outputName, "transform", value];
    case "position":
      // Negative coordinates need an option terminator for clap to accept them.
      return ["niri", "msg", "output", outputName, "position", "set", "--", String(value.x), String(value.y)];
    case "vrrMode":
      return value === "on-demand" ? ["niri", "msg", "output", outputName, "vrr", "--on-demand", "on"] : ["niri", "msg", "output", outputName, "vrr", value];
    case "maxBpc":
      return ["niri", "msg", "output", outputName, "max-bpc", String(value)];
    }
    return null;
  }
  function applyConfig(outputName: string, changes: var, callback: var): void {
    try {
      const fields = Utils.isObject(changes) ? Object.keys(changes) : [];
      if (!fields.length || !fields.every(field => controls.includes(field)))
        throw new Error("changes contain an unsupported field");
      _validate(Object.assign({
        selector: outputName
      }, changes), "changes");
    } catch (error) {
      callback({
        success: false,
        message: error.message
      });
      return;
    }

    const commands = controls.filter(field => Utils.has(changes, field)).map(field => _commandForChange(outputName, field, changes[field]));
    const runNext = () => {
      const command = commands.shift();
      if (!command) {
        root.featuresChanged();
        callback({ success: true });
        return;
      }
      const handle = Command.run(command, result => {
        if (result.exitCode === 0)
          runNext();
        else
          callback({
            success: false,
            message: (result.stderr || result.stdout || "niri rejected the output change").trim()
          });
      }, `niri-output-${outputName}`);
      if (!handle)
        callback({ success: false, message: "A display change is already in progress" });
    };
    runNext();
  }
  function saveConfig(displays: var, focusedOutput: string, callback: var): void {
    let text;
    try {
      if (!configPath)
        throw new Error("HOME is unavailable");
      text = renderConfig(displays, focusedOutput);
    } catch (error) {
      callback({ success: false, message: error.message });
      return;
    }
    const command = ["sh", "-c", _installScript, "sh", configPath, "niri", "validate", "--config", `${configPath}.candidate`];
    const handle = Command.run(command, result => {
      const ok = result.exitCode === 0;
      callback({
        success: ok,
        message: ok ? "" : (result.stderr || result.stdout || "Could not save the display configuration").trim()
      });
    }, "niri-output-save", text);
    if (!handle)
      callback({ success: false, message: "A display configuration write is already in progress" });
  }
  function fetchFeatures(outputName: string, callback: var): void {
    NiriService.request('"Outputs"', response => {
      const outputs = response?.Ok?.Outputs;
      const output = outputs?.[outputName] ?? (outputs ? Object.values(outputs).find(candidate => candidate?.name === outputName) : null);
      if (!output) {
        callback(null);
        return;
      }

      const logical = output.logical ?? {};
      const modeKeys = Utils.toArray(output.modes).map(mode => Utils.modeKey(mode.width, mode.height, typeof mode.refresh_rate === "number" ? mode.refresh_rate / 1000 : null));
      callback({
        currentModeKey: Number.isInteger(output.current_mode) ? modeKeys[output.current_mode] ?? "" : "",
        displayModel: root._displayModel(output.make, output.model),
        logicalHeight: logical.height,
        logicalWidth: logical.width,
        logicalX: logical.x,
        logicalY: logical.y,
        maxBpc: output.max_bpc,
        modeKeys,
        // ShellScreen reports the integer buffer scale, which is the ceiling of a
        // fractional scale; only the compositor knows the real one.
        scale: logical.scale,
        transformMode: root._transformKey(logical.transform),
        // Niri cannot distinguish ordinary VRR from on-demand; stored metadata
        // owns the mode rather than silently downgrading it on refresh.
        vrrSupported: !!output.vrr_supported
      });
    });
  }

  Component.onCompleted: {
    console.assert(_transformKey("Normal") === "normal" && _transformKey("_90") === "90" && _transformKey("_270") === "270" && _transformKey("Flipped180") === "flipped-180", "Niri monitor transform self-check failed");
    console.assert(_selfCheck(), "Niri monitor config renderer self-check failed");
  }

  Connections {
    function onConfigLoaded(): void {
      root.featuresChanged();
    }
    function onRequestConnectedChanged(): void {
      if (NiriService.requestConnected)
        root.featuresChanged();
    }

    target: NiriService
  }
}
