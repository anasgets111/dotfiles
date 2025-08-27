pragma Singleton

import QtQuick
import Quickshell
import qs.Services.SystemInfo

Singleton {
    id: loggerService

    property bool debug: true
    // Module names must match the first argument passed to log/warn/error.
    // If non-empty, only modules listed here will be logged. Example: ["MainService","NetworkService"]
    property var allowedModules: [
        "Shell",
        "LockContent",
        "NetworkService",
        "MainService",
        "AudioService",
        "BatteryService",
        "BrightnessService",
        "ClipboardService",
        "ClipboardLiteService",
        "FileSystemService",
        "IdleService",
        "KeyboardBacklightService",
        "KeyboardLayoutService",
        "LockService",
        "MainService",
        "MediaService",
        "MonitorService",
        "NetworkService",
        "NotificationService",
        "OSDService",
        "ScreenRecordingService",
        "SystemInfoService",
        "SystemTrayService",
        "TimeService",
        "UpdateService",
        "WallpaperService",
        "WeatherService"
    ]

    function setAllowedModules(list) {
        if (!list) {
            loggerService.allowedModules = [];
            return;
        }
        try {
            // Ensure we store simple strings
            loggerService.allowedModules = list.map(function (x) {
                return String(x);
            });
        } catch (e) {
            loggerService.allowedModules = [];
        }
    }

    function shouldLog(moduleName) {
        if (!loggerService.debug)
            return false;
        if (!loggerService.allowedModules || loggerService.allowedModules.length === 0)
            return true;
        if (!moduleName)
            return false;
        try {
            var name = String(moduleName).trim();
            for (var i = 0; i < loggerService.allowedModules.length; ++i) {
                if (loggerService.allowedModules[i] === name)
                    return true;
            }
        } catch (e) {
            return false;
        }
        return false;
    }
    function _formatMessage(...args) {
        const timeNow = TimeService.timestamp();
        const timePart = `\x1b[36m[${timeNow}]\x1b[0m`;
        const maxLength = 16;

        function colorModule(moduleRaw) {
            const name = String(moduleRaw);
            const clipped = name.substring(0, maxLength);
            const totalPadding = maxLength - clipped.length;
            const padLeft = Math.floor(totalPadding / 2);
            const padRight = totalPadding - padLeft;
            const moduleClean = " ".repeat(padLeft) + clipped + " ".repeat(padRight);
            return `\x1b[35m[${moduleClean}]\x1b[0m`;
        }

        let moduleRaw = null;
        let messageText = "";

        if (args.length > 1) {
            moduleRaw = args[0];
            messageText = args.slice(1).join(" ");
        } else {
            messageText = String(args.length ? args[0] : "");
        }

        const modulePart = moduleRaw ? colorModule(moduleRaw) + " " : "";
        return `${timePart} ${modulePart}${messageText}`;
    }

    function log(...args) {
        var moduleRaw = null;
        if (args.length > 1) {
            moduleRaw = args[0];
        }
        if (!loggerService.shouldLog(moduleRaw))
            return;
        console.log(loggerService._formatMessage(...args));
    }

    function warn(...args) {
        var moduleRaw = null;
        if (args.length > 1) {
            moduleRaw = args[0];
        }
        if (!loggerService.shouldLog(moduleRaw))
            return;
        console.warn(loggerService._formatMessage(...args));
    }

    function error(...args) {
        var moduleRaw = null;
        if (args.length > 1) {
            moduleRaw = args[0];
        }
        if (!loggerService.shouldLog(moduleRaw))
            return;
        console.error(loggerService._formatMessage(...args));
    }
}
