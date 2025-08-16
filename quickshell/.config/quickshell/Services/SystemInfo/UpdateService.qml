pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import "../" as Services

Singleton {
    id: updateService

    // Lifecycle
    property bool ready: false

    // State
    property bool busy: false
    property int updates: 0
    property var updatePackages: []
    property string rawOutput: ""
    property double lastSync: 0
    property bool lastWasFull: false
    property int failureCount: 0
    property int failureThreshold: 3

    // Timing
    property int minuteMs: 60 * 1000
    property int pollInterval: 1 * minuteMs
    property int syncInterval: 5 * minuteMs

    // Cache
    PersistentProperties {
        id: cache
        reloadableId: "ArchCheckerCache"

        property var cachedUpdatePackages: []
        property double cachedLastSync: 0
    }

    Component.onCompleted: {
        // Restore from cache
        if (cache.cachedUpdatePackages && cache.cachedUpdatePackages.length) {
            updateService.updatePackages = cache.cachedUpdatePackages;
            updateService.updates = cache.cachedUpdatePackages.length;
        }
        if (cache.cachedLastSync && cache.cachedLastSync > 0) {
            updateService.lastSync = cache.cachedLastSync;
        }

        doPoll();
        pollTimer.start();
        ready = true;
        console.log("[UpdateService] Ready");
    }

    function startUpdateProcess(cmd) {
        pkgProc.command = cmd;
        pkgProc.running = true;
        killTimer.interval = lastWasFull ? 60 * 1000 : minuteMs;
        killTimer.restart();
    }

    function doPoll(forceFull = false) {
        if (busy)
            return;

        busy = true;
        const now = Date.now();
        const full = forceFull || (now - lastSync > syncInterval);
        lastWasFull = full;

        if (full)
            startUpdateProcess(["checkupdates", "--nocolor"]);
        else
            startUpdateProcess(["checkupdates", "--nosync", "--nocolor"]);
    }

    Process {
        id: pkgProc

        onExited: function (exitCode, exitStatus) {
            const stderrText = (err.text || "").trim();
            if (stderrText)
                console.warn("[UpdateService] stderr:", stderrText);

            if (!pkgProc.running && !updateService.busy)
                return;

            killTimer.stop();
            updateService.busy = false;

            const raw = (out.text || "").trim();
            updateService.rawOutput = raw;
            const list = raw ? raw.split(/\r?\n/) : [];
            updateService.updates = list.length;

            var pkgs = [];
            for (var i = 0; i < list.length; ++i) {
                var m = list[i].match(/^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/);
                if (m)
                    pkgs.push({
                        "name": m[1],
                        "oldVersion": m[2],
                        "newVersion": m[3]
                    });
            }
            updateService.updatePackages = pkgs;

            if (exitCode !== 0 && exitCode !== 2) {
                updateService.failureCount++;
                if (updateService.failureCount >= updateService.failureThreshold) {
                    console.error("[UpdateService] Update check failed", exitCode);
                    updateService.failureCount = 0;
                }
                updateService.updates = 0;
                updateService.updatePackages = [];
                return;
            }
            updateService.failureCount = 0;

            if (updateService.lastWasFull) {
                updateService.lastSync = Date.now();
            }

            cache.cachedUpdatePackages = updateService.updatePackages;
            cache.cachedLastSync = updateService.lastSync;
        }

        stdout: StdioCollector {
            id: out
        }
        stderr: StdioCollector {
            id: err
        }
    }

    Timer {
        id: pollTimer
        interval: updateService.pollInterval
        repeat: true
        onTriggered: updateService.doPoll()
    }

    Timer {
        id: killTimer
        interval: updateService.minuteMs
        repeat: false
        onTriggered: {
            if (pkgProc.running) {
                updateService.busy = false;
                console.error("[UpdateService] Update check killed (timeout)");
            }
        }
    }
}
