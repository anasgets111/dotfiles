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
        id: tzProc
        command: ["sh", "-c", "timedatectl show -p Timezone --value"]
        stdout: StdioCollector {
            onStreamFinished: dateTimeService.timeZone = text.trim()
        }
    }

    Process {
        id: ntpEnabledProc
        command: ["sh", "-c", "timedatectl show -p NTP --value"]
        stdout: StdioCollector {
            onStreamFinished: {
                dateTimeService.ntpEnabled = (text.trim().toLowerCase() === "yes");
                console.log("[DateTimeService] NTP Enabled:", dateTimeService.ntpEnabled);
            }
        }
    }

    Process {
        id: ntpSyncedProc
        command: ["sh", "-c", "timedatectl show -p NTPSynchronized --value"]
        stdout: StdioCollector {
            onStreamFinished: {
                dateTimeService.ntpSynced = (text.trim().toLowerCase() === "yes");
                console.log("[DateTimeService] NTP Synced:", dateTimeService.ntpSynced);
            }
        }
    }

    Process {
        id: ntpToggleProc
        stdout: StdioCollector {
            onStreamFinished: dateTimeService.checkNtpStatus()
        }
    }

    Component.onCompleted: {
        detectTimeZone();
        checkNtpStatus();
        ready = true;
        console.log("[DateTimeService] Ready");
    }

    function updateDateTime() {
        var d = new Date();
        currentDate = d;
        formattedDateTime = Qt.formatDateTime(d, "yyyy-MM-dd hh:mm:ss");
    }

    function detectTimeZone() {
        tzProc.running = true;
    }

    function checkNtpStatus() {
        ntpEnabledProc.running = true;
        ntpSyncedProc.running = true;
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
