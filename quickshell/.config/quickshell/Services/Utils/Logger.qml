pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  property bool enabled: true
  property list<string> includeModules: []
  readonly property int moduleLabelWidth: 16

  function emit(kind: string, argumentList: var): void {
    const moduleName = argumentList?.length > 1 ? argumentList[0] : null;
    if (!root.shouldLog(moduleName))
      return;

    const message = root.formatMessage(argumentList);
    if (kind === "warn")
      console.warn(message);
    else if (kind === "error")
      console.error(message);
    else
      console.log(message);
  }

  function error() {
    root.emit("error", arguments);
  }

  function formatMessage(argumentList: var): string {
    if (!argumentList?.length)
      return "";

    const timestamp = `[${Qt.formatTime(new Date(), "h:mm:ss AP")}]`;

    if (argumentList.length === 1)
      return `${timestamp} ${String(argumentList[0])}`;

    const modulePart = root.formatModuleLabel(argumentList[0]);
    const messageParts = [];

    for (let argumentIndex = 1; argumentIndex < argumentList.length; argumentIndex++)
      messageParts.push(String(argumentList[argumentIndex] ?? ""));

    return `${timestamp} ${modulePart} ${messageParts.join(" ")}`;
  }

  function formatModuleLabel(moduleName: var): string {
    const label = String(moduleName ?? "").substring(0, root.moduleLabelWidth);
    const padding = root.moduleLabelWidth - label.length;
    const leftPadding = Math.floor(padding / 2);
    const rightPadding = padding - leftPadding;
    return `[${" ".repeat(leftPadding)}${label}${" ".repeat(rightPadding)}]`;
  }

  function log() {
    root.emit("log", arguments);
  }

  function shouldLog(moduleName: var): bool {
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
