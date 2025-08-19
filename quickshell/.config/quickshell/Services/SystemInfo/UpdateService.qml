pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import "../" as Services
import qs.Services.SystemInfo

Singleton {
    id: updateService
    property var logger: LoggerService

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
            // Clone to current engine to avoid cross-engine JSValue warning
            try {
                updateService.updatePackages = JSON.parse(JSON.stringify(cache.cachedUpdatePackages));
            } catch (e) {
                updateService.updatePackages = cache.cachedUpdatePackages.slice();
            }
            updateService.updates = updateService.updatePackages.length;
        }
        if (cache.cachedLastSync && cache.cachedLastSync > 0) {
            updateService.lastSync = cache.cachedLastSync;
        }

        doPoll();
        pollTimer.start();
        ready = true;
        updateService.logger.log("UpdateService", "Ready");
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

        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                // stderr is handled below
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

                if (updateService.lastWasFull) {
                    updateService.lastSync = Date.now();
                }

                // Store a cloned copy to decouple references
                try {
                    cache.cachedUpdatePackages = JSON.parse(JSON.stringify(updateService.updatePackages));
                } catch (e) {
                    cache.cachedUpdatePackages = updateService.updatePackages.slice();
                }
                cache.cachedLastSync = updateService.lastSync;
            }
        }
        stderr: StdioCollector {
            id: err
            onStreamFinished: {
                const stderrText = (err.text || "").trim();
                if (stderrText)
                    updateService.logger.warn("UpdateService", "stderr:", stderrText);
            }
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
                updateService.logger.error("UpdateService", "Update check killed (timeout)");
            }
        }
    }
}
