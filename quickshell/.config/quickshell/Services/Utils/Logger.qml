pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  property bool enabled: true
  property list<string> includeModules: []
  readonly property int moduleLabelWidth: 16

  function emit(kind: string, moduleName: string, message: var): void {
    if (!root.shouldLog(moduleName))
      return;

    const formattedMessage = `${root.formatModuleLabel(moduleName)} ${String(message ?? "")}`;
    if (kind === "warn")
      console.warn(formattedMessage);
    else if (kind === "error")
      console.error(formattedMessage);
    else
      console.log(formattedMessage);
  }
  function error(moduleName: string, message: var): void {
    root.emit("error", moduleName, message);
  }
  function formatModuleLabel(moduleName: var): string {
    const label = String(moduleName ?? "").substring(0, root.moduleLabelWidth);
    const padding = root.moduleLabelWidth - label.length;
    return `[${" ".repeat(Math.floor(padding / 2))}${label}${" ".repeat(Math.ceil(padding / 2))}]`;
  }
  function log(moduleName: string, message: var): void {
    root.emit("log", moduleName, message);
  }
  function shouldLog(moduleName: string): bool {
    return root.enabled && (root.includeModules.length === 0 || root.includeModules.includes(moduleName.trim()));
  }
  function warn(moduleName: string, message: var): void {
    root.emit("warn", moduleName, message);
  }
}
