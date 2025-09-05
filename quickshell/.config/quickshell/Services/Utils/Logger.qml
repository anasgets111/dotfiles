pragma Singleton
import QtQuick
import Quickshell
import qs.Services.SystemInfo

Singleton {
  id: logger

  property bool enabled: true
  // If non-empty, only these modules are logged (exact match, case-sensitive)
  // "Shell", "LockContent", "Bar", "IPC", "NetworkService", "MainService", "AudioService", "BatteryService", "BrightnessService", "ClipboardService", "ClipboardLiteService", "FileSystemService", "IdleService", "KeyboardBacklightService", "KeyboardLayoutService", "LockService", "MediaService", "MonitorService", "NotificationService", "OSDService", "ScreenRecordingService", "SystemInfoService", "SystemTrayService", "TimeService", "UpdateService", "WallpaperService", "WeatherService"
  property var includeModules: [].filter((v, i, a) => {
    return a.indexOf(v) === i;
  })
  readonly property int moduleLabelWidth: 16

  function emit(kind, args) {
    const moduleRaw = extractModule(args);
    if (!logger.shouldLog(moduleRaw))
      return;

    const msg = logger.formatMessage(args);
    if (kind === "warn")
      console.warn(msg);
    else if (kind === "error")
      console.error(msg);
    else
      console.log(msg);
  }
  function error() {
    logger.emit("error", Array.prototype.slice.call(arguments));
  }
  function extractModule(args) {
    if (!args || args.length <= 1)
      return null;

    return args[0];
  }
  function formatMessage(args) {
    const timeNow = TimeService.timestamp();
    const timePart = `\x1b[36m[${timeNow}]\x1b[0m`;
    let moduleRaw = null;
    let messageText = "";
    if (args.length > 1) {
      moduleRaw = args[0];
      messageText = args.slice(1).join(" ");
    } else {
      messageText = String(args.length ? args[0] : "");
    }
    const modulePart = moduleRaw ? (formatModuleLabel(moduleRaw) + " ") : "";
    return `${timePart} ${modulePart}${messageText}`;
  }
  function formatModuleLabel(moduleRaw) {
    const width = logger.moduleLabelWidth;
    const name = String(moduleRaw);
    const clipped = name.substring(0, width);
    const totalPad = width - clipped.length;
    const left = Math.floor(totalPad / 2);
    const right = totalPad - left;
    const padded = " ".repeat(left) + clipped + " ".repeat(right);
    return `\x1b[35m[${padded}]\x1b[0m`;
  }

  // Public API
  function log() {
    logger.emit("log", Array.prototype.slice.call(arguments));
  }

  // Public API: set the allowed/whitelisted module names
  function setIncludeModules(list) {
    if (!list) {
      logger.includeModules = [];
      return;
    }
    const norm = list.map(x => {
      return String(x).trim();
    }).filter(x => {
      return x.length > 0;
    });
    const uniq = [];
    for (let i = 0; i < norm.length; i++) {
      const n = norm[i];
      if (uniq.indexOf(n) === -1)
        uniq.push(n);
    }
    logger.includeModules = uniq;
  }
  function shouldLog(moduleName) {
    // fallthrough

    if (!logger.enabled)
      return false;

    const list = logger.includeModules;
    if (!list || list.length === 0)
      return true;

    if (!moduleName)
      return false;

    try {
      const name = String(moduleName).trim();
      // exact match
      for (let i = 0; i < list.length; i++) {
        if (list[i] === name)
          return true;
      }
    } catch (e) {}
    return false;
  }
  function warn() {
    logger.emit("warn", Array.prototype.slice.call(arguments));
  }
}
