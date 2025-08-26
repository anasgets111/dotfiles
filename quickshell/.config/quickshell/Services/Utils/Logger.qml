pragma Singleton

import QtQuick
import Quickshell
import qs.Services.SystemInfo

Singleton {
    id: loggerService

    // Toggle global debug logging on/off
    property bool debug: true
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
