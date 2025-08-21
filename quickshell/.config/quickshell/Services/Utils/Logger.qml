pragma Singleton

import QtQuick
import Quickshell
import qs.Services.SystemInfo

Singleton {
    id: loggerService

    // Toggle global debug logging on/off
    property bool debug: true
    function _formatMessage(...args) {
        var time = TimeService.getFormattedTimestamp();
        const timePart = `\x1b[36m[${time}]\x1b[0m`;
        const maxLength = 16;

        function colorModule(moduleRaw) {
            var name = String(moduleRaw);
            var clipped = name.substring(0, maxLength);
            var totalPad = maxLength - clipped.length;
            var left = Math.floor(totalPad / 2);
            var right = totalPad - left;
            var moduleClean = " ".repeat(left) + clipped + " ".repeat(right);
            return `\x1b[35m[${moduleClean}]\x1b[0m`;
        }

        var moduleRaw = null;
        var text = "";

        if (args.length > 1) {
            moduleRaw = args[0];
            text = args.slice(1).join(" ");
        } else {
            text = String(args.length ? args[0] : "");
        }

        var modulePart = moduleRaw ? colorModule(moduleRaw) + " " : "";
        return `${timePart} ${modulePart}${text}`;
    }

    function log(...args) {
        if (!loggerService.debug)
            return;
        console.log(loggerService._formatMessage(...args));
    }

    function warn(...args) {
        if (!loggerService.debug)
            return;
        console.warn(loggerService._formatMessage(...args));
    }

    function error(...args) {
        if (!loggerService.debug)
            return;
        console.error(loggerService._formatMessage(...args));
    }
}
