pragma Singleton
import QtQuick
import Quickshell
import qs.Services.SystemInfo

Singleton {
  id: root

  readonly property string currentTimestamp: TimeService.timestamp()
  property bool enabled: true
  property list<string> includeModules: []
  readonly property bool isTty: {
    // Check if TERM is set (present in terminals, absent in daemon logs)
    const term = Quickshell.env("TERM");
    return term !== null && term !== "" && term !== "dumb";
  }
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
    if (!args?.length)
      return "";

    const timestamp = root.isTty ? `\x1b[36m[${root.currentTimestamp}]\x1b[0m` : `[${root.currentTimestamp}]`;

    if (args.length === 1)
      return `${timestamp} ${String(args[0])}`;

    const modulePart = root.formatModuleLabel(args[0]);
    const messageCount = args.length - 1;
    const messageParts = new Array(messageCount);

    for (let i = 0; i < messageCount; i++) {
      messageParts[i] = String(args[i + 1] ?? "");
    }

    return `${timestamp} ${modulePart} ${messageParts.join(" ")}`;
  }

  function formatModuleLabel(moduleRaw) {
    const name = String(moduleRaw ?? "").substring(0, root.moduleLabelWidth);
    const totalPad = root.moduleLabelWidth - name.length;
    const left = Math.floor(totalPad / 2);
    const right = totalPad - left;

    return root.isTty ? `\x1b[35m[${" ".repeat(left)}${name}${" ".repeat(right)}]\x1b[0m` : `[${" ".repeat(left)}${name}${" ".repeat(right)}]`;
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
