pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../" as Services

Singleton {
    id: dateTimeService

    property bool ready: false
    property date currentDate: new Date()
    property string formattedDateTime: Qt.formatDateTime(currentDate, "yyyy-MM-dd hh:mm:ss")
    property string timeZone: ""
    property int weekStart: 0

    property bool ntpEnabled: false
    property bool ntpSynced: false

    property int updateInterval: 1000

    Timer {
        id: clockTimer
        interval: dateTimeService.updateInterval
        running: true
        repeat: true
        onTriggered: dateTimeService.updateDateTime()
        Component.onCompleted: triggered()
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
                console.log("[DateTimeService] Timezone:", dateTimeService.timeZone, "| NTP Enabled:", dateTimeService.ntpEnabled, "| NTP Synced:", dateTimeService.ntpSynced);
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
        console.log("[DateTimeService] Ready");
    }

    function updateDateTime() {
        var d = new Date();
        currentDate = d;
        formattedDateTime = Qt.formatDateTime(d, "yyyy-MM-dd hh:mm:ss");
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
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }
}
