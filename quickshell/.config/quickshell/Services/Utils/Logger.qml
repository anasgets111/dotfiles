pragma Singleton
import QtQuick
import Quickshell
import qs.Services.SystemInfo

Singleton {
  id: root

  property bool enabled: true
  property list<string> includeModules: []
  readonly property int moduleLabelWidth: 16

  function emit(kind, args) {
    const moduleRaw = root.extractModule(args);
    if (!root.shouldLog(moduleRaw))
      return;
    const msg = root.formatMessage(args);
    if (kind === "warn")
      console.warn(msg);
    else if (kind === "error")
      console.error(msg);
    else
      console.log(msg);
  }

  function error() {
    root.emit("error", arguments);
  }

  function extractModule(args) {
    return args?.length > 1 ? args[0] : null;
  }

  function formatMessage(args) {
    if (!args || args.length === 0)
      return "";
    if (args.length === 1) {
      return `\x1b[36m[${TimeService.timestamp()}]\x1b[0m ${args[0]}`;
    }
    const modulePart = root.formatModuleLabel(args[0]);
    const messageParts = [];
    for (let i = 1; i < args.length; i++)
      messageParts.push(args[i]);
    return `\x1b[36m[${TimeService.timestamp()}]\x1b[0m ${modulePart} ${messageParts.join(" ")}`;
  }

  function formatModuleLabel(moduleRaw) {
    const name = String(moduleRaw).substring(0, root.moduleLabelWidth);
    const totalPad = root.moduleLabelWidth - name.length;
    const left = Math.floor(totalPad / 2);
    const right = totalPad - left;
    return `\x1b[35m[${" ".repeat(left)}${name}${" ".repeat(right)}]\x1b[0m`;
  }

  function log() {
    root.emit("log", arguments);
  }

  function setIncludeModules(list) {
    if (!list) {
      root.includeModules = [];
      return;
    }
    const normalized = list.map(x => String(x).trim()).filter(x => x.length > 0);
    root.includeModules = [...new Set(normalized)];
  }

  function shouldLog(moduleName) {
    if (!root.enabled)
      return false;
    if (root.includeModules.length === 0)
      return true;
    if (!moduleName)
      return false;
    return root.includeModules.includes(String(moduleName).trim());
  }

  function warn() {
    root.emit("warn", arguments);
  }
}
