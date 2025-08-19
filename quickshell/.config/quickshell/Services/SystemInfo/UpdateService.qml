pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
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

        property string cachedUpdatePackagesJson: "[]"
        property double cachedLastSync: 0
    }

    Component.onCompleted: {
        // Restore from cache
        updateService.logger.log("UpdateService", "cache.cachedUpdatePackagesJson:", cache.cachedUpdatePackagesJson);
        const persisted = JSON.parse(cache.cachedUpdatePackagesJson || "[]");
        if (persisted && persisted.length) {
            updateService.updatePackages = _clonePackageList(persisted);
            updateService.updates = updateService.updatePackages.length;
            updateService.logger.log("UpdateService", "Restored", updateService.updates, "packages from cache");
        }
        if (cache.cachedLastSync && cache.cachedLastSync > 0) {
            updateService.lastSync = cache.cachedLastSync;
            updateService.logger.log("UpdateService", "Restored lastSync from cache:", updateService.lastSync);
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
        updateService.logger.log("UpdateService", "Starting checkupdates:", cmd.join(" "), "timeoutMs:", killTimer.interval);
        killTimer.restart();
    }

    function doPoll(forceFull = false) {
        if (busy) {
            updateService.logger.log("UpdateService", "Poll skipped: busy");
            return;
        }

        busy = true;
        const now = Date.now();
        const full = forceFull || (now - lastSync > syncInterval);
        lastWasFull = full;

        updateService.logger.log("UpdateService", "Poll start", full ? "full" : "nosync", "lastSyncDeltaMs:", (lastSync ? (now - lastSync) : -1));

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
                    updateService.logger.log("UpdateService", "Full sync complete; lastSync:", updateService.lastSync);
                }

                cache.cachedUpdatePackagesJson = JSON.stringify(updateService._clonePackageList(updateService.updatePackages));
                cache.cachedLastSync = updateService.lastSync;

                // Summary logs
                const count = updateService.updates;
                updateService.logger.log("UpdateService", "Update check finished:", count, "packages");
                if (count === 0) {
                    updateService.logger.log("UpdateService", "System is up to date");
                } else {
                    var preview = pkgs.slice(0, Math.min(3, pkgs.length)).map(function (p) {
                        return p.name + " " + p.oldVersion + "->" + p.newVersion;
                    }).join(", ");
                    updateService.logger.log("UpdateService", "Packages:", preview + (count > 3 ? " …" : ""));
                }
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

    // Ensure cached packages are plain objects with expected fields only
    function _clonePackageList(list) {
        const out = [];
        if (!list || typeof list.length !== 'number')
            return out;
        for (let i = 0; i < list.length; i++) {
            const p = list[i] || {};
            out.push({
                name: String(p.name || ""),
                oldVersion: String(p.oldVersion || ""),
                newVersion: String(p.newVersion || "")
            });
        }
        return out;
    }

    Timer {
        id: pollTimer
        interval: updateService.pollInterval
        repeat: true
        onTriggered: {
            updateService.logger.log("UpdateService", "Poll timer triggered");
            updateService.doPoll();
        }
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
