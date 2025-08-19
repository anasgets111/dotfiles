pragma Singleton

import QtQuick
import Quickshell
import qs.Services.SystemInfo

Singleton {
    id: loggerService

    // Toggle debug logging on/off
    property bool debug: false
    function _formatMessage(...args) {
        var time = TimeService.getFormattedTimestamp();

        if (args.length > 1) {
            const maxLength = 14;
            var moduleRaw = String(args.shift());
            // Strip any existing surrounding brackets to avoid truncating them
            if (moduleRaw.startsWith("["))
                moduleRaw = moduleRaw.slice(1);
            if (moduleRaw.endsWith("]"))
                moduleRaw = moduleRaw.slice(0, -1);
            // Truncate to maxLength and left-pad for alignment
            var moduleClean = moduleRaw.substring(0, maxLength).padStart(maxLength, " ");
            // Re-wrap with brackets so closing ']' is guaranteed
            var module = `[${moduleClean}]`;
            return `\x1b[36m[${time}]\x1b[0m \x1b[35m${module}\x1b[0m ` + args.join(" ");
        } else {
            return `\x1b[36m[${time}]\x1b[0m ` + args.join(" ");
        }
    }

    function log(...args) {
        var msg = _formatMessage(...args);
        console.log(msg);
    }

    function warn(...args) {
        var msg = _formatMessage(...args);
        console.warn(msg);
    }

    function error(...args) {
        var msg = _formatMessage(...args);
        console.error(msg);
    }
}
