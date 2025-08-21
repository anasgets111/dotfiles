pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
    id: dateTimeService

    property bool ready: false
    // Default to Minutes to reduce wakeups if you don't display seconds
    property int precision: SystemClock.Seconds
    // Use Quickshell's SystemClock instead of a manual Timer
    property date currentDate: clock.date
    property string formattedDateTime: Qt.formatDateTime(clock.date, dateTimeService.precision === SystemClock.Minutes ? "yyyy-MM-dd hh:mm" : "yyyy-MM-dd hh:mm:ss")
    property string timeZone: ""
    property int weekStart: 0

    property bool ntpEnabled: false
    property bool ntpSynced: false

    SystemClock {
        id: clock
        // Bind precision so callers can switch between Minutes/Seconds
        precision: dateTimeService.precision
    }

    Process {
        id: timeInfoProc
        command: ["sh", "-c", "timedatectl show -p Timezone -p NTP -p NTPSynchronized --value"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split(/\r?\n/);
                if (lines.length >= 3) {
                    dateTimeService.timeZone = lines[0].trim();
                    dateTimeService.ntpEnabled = lines[1].trim().toLowerCase() === "yes";
                    dateTimeService.ntpSynced = lines[2].trim().toLowerCase() === "yes";
                }
                Logger.log("DateTimeService", "Timezone:", dateTimeService.timeZone, "| NTP Enabled:", dateTimeService.ntpEnabled, "| NTP Synced:", dateTimeService.ntpSynced);
            }
        }
    }

    Process {
        id: ntpToggleProc
        stdout: StdioCollector {
            onStreamFinished: dateTimeService.updateTimeInfo()
        }
    }

    Component.onCompleted: {
        dateTimeService.updateTimeInfo();
        ready = true;
        Logger.log("DateTimeService", "Ready");
    }

    function updateTimeInfo() {
        timeInfoProc.running = true;
    }

    function setNtpEnabled(enable) {
        ntpToggleProc.command = ["sh", "-c", "timedatectl set-ntp " + (enable ? "true" : "false")];
        ntpToggleProc.running = true;
    }

    function formatDuration(seconds) {
        seconds = Math.floor(seconds);
        if (seconds <= 0)
            return "";
        var d = Math.floor(seconds / 86400);
        var h = Math.floor((seconds % 86400) / 3600);
        var m = Math.floor((seconds % 3600) / 60);
        var s = seconds % 60;
        var parts = [];
        if (d)
            parts.push(d + "d");
        if (h)
            parts.push(h + "h");
        if (m)
            parts.push(m + "m");
        parts.push(s + "s");
        return parts.join(" ");
    }

    function formatHM(seconds) {
        if (seconds <= 0)
            return "Calculating…";
        var h = Math.floor(seconds / 3600);
        var m = Math.round((seconds % 3600) / 60);
        if (m === 60) {
            h += 1;
            m = 0;
        }
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }
    function getFormattedTimestamp() {
        // Return local wall-clock time, e.g. "11:09:08"
        return Qt.formatDateTime(clock.date, "hh:mm:ss");
    }
}
