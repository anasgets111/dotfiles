pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
    id: updateService
    // Ensure our notification server is instantiated
    property var notifications: NotificationService

    Connections {
        target: NotificationService
        function onActionInvoked(summary, appName, actionId, body) {
            const id = String(actionId || "").toLowerCase();
            Logger.log("UpdateService", "Notification action:", id, "summary:", summary, "app:", appName, "body:", body);
            if (id === "update" || (!id && String(summary || "") === qsTr("Updates Available")))
                updateService.runUpdate();
        }
    }

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
    // Track last notified count to avoid duplicate notices
    property int lastNotifiedUpdates: 0

    // Command to run updates when user clicks action
    // Avoid shell-style quotes in argv; pass a single arg with spaces
    property var updateCommand: ["xdg-terminal-exec", "--title=Global Updates", "-e", "sh", "-c", "$BIN/update.sh"]

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
        Logger.log("UpdateService", "cache.cachedUpdatePackagesJson:", cache.cachedUpdatePackagesJson);
        const persisted = JSON.parse(cache.cachedUpdatePackagesJson || "[]");
        if (persisted && persisted.length) {
            updateService.updatePackages = _clonePackageList(persisted);
            updateService.updates = updateService.updatePackages.length;
            Logger.log("UpdateService", "Restored", updateService.updates, "packages from cache");
        }
        if (cache.cachedLastSync && cache.cachedLastSync > 0) {
            updateService.lastSync = cache.cachedLastSync;
            Logger.log("UpdateService", "Restored lastSync from cache:", updateService.lastSync);
        }

        doPoll();
        pollTimer.start();
        ready = true;
        Logger.log("UpdateService", "Ready");
    }

    // Launch updater in a terminal
    function runUpdate() {
        Logger.log("UpdateService", "runUpdate(): exec", JSON.stringify(updateService.updateCommand));
        Quickshell.execDetached(updateService.updateCommand);
    }

    // Send a notification via our NotificationService with actions/images/icons
    function notify(urgency, title, body) {
        const u = String(urgency || "normal").toLowerCase();
        const isCritical = (u === "critical");
        const opts = {
            appName: "UpdateService",
            appIcon: "system-software-update",
            urgency: u,
            expireTimeout: -1,
            actions: isCritical ? [] : [
                {
                    id: "update",
                    title: qsTr("Update Now"),
                    icon: "system-software-update"
                }
            ]
        };
        NotificationService.send(String(title || ""), String(body || ""), opts);
    }

    function startUpdateProcess(cmd) {
        pkgProc.command = cmd;
        pkgProc.running = true;
        killTimer.interval = lastWasFull ? 60 * 1000 : minuteMs;
        Logger.log("UpdateService", "Starting checkupdates:", cmd.join(" "), "timeoutMs:", killTimer.interval);
        killTimer.restart();
    }

    function doPoll(forceFull = false) {
        if (busy) {
            Logger.log("UpdateService", "Poll skipped: busy");
            return;
        }

        busy = true;
        const now = Date.now();
        const full = forceFull || (now - lastSync > syncInterval);
        lastWasFull = full;

        Logger.log("UpdateService", "Poll start", full ? "full" : "nosync", "lastSyncDeltaMs:", (lastSync ? (now - lastSync) : -1));

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
                    Logger.log("UpdateService", "Full sync complete; lastSync:", updateService.lastSync);
                }

                cache.cachedUpdatePackagesJson = JSON.stringify(updateService._clonePackageList(updateService.updatePackages));
                cache.cachedLastSync = updateService.lastSync;

                // Summary logs
                const count = updateService.updates;
                Logger.log("UpdateService", "Update check finished:", count, "packages");
                if (count === 0) {
                    Logger.log("UpdateService", "System is up to date");
                    // Reset notification baseline when up-to-date
                    updateService.lastNotifiedUpdates = 0;
                } else {
                    var preview = pkgs.slice(0, Math.min(3, pkgs.length)).map(function (p) {
                        return p.name + " " + p.oldVersion + "->" + p.newVersion;
                    }).join(", ");
                    Logger.log("UpdateService", "Packages:", preview + (count > 3 ? " …" : ""));
                    // Notify only when the count increases
                    if (count > updateService.lastNotifiedUpdates) {
                        const added = count - updateService.lastNotifiedUpdates;
                        const msg = added === 1 ? qsTr("One new package can be upgraded (") + count + qsTr(")") : added + qsTr(" new packages can be upgraded (") + count + qsTr(")");
                        updateService.notify("normal", qsTr("Updates Available"), msg);
                        updateService.lastNotifiedUpdates = count;
                    }
                }
            }
        }
        stderr: StdioCollector {
            id: err
            onStreamFinished: {
                const stderrText = (err.text || "").trim();
                if (stderrText) {
                    Logger.warn("UpdateService", "stderr:", stderrText);
                    // Treat non-empty stderr as a failure indication
                    updateService.failureCount++;
                    if (updateService.failureCount >= updateService.failureThreshold) {
                        updateService.notify("critical", qsTr("Update check failed"), stderrText);
                        updateService.failureCount = 0;
                    }
                } else {
                    // Clear failure streak on clean stderr
                    updateService.failureCount = 0;
                }
            }
        }
    }

    // No external notify-send process needed; actions handled via NotificationService

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
            Logger.log("UpdateService", "Poll timer triggered");
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
                Logger.error("UpdateService", "Update check killed (timeout)");
                updateService.notify("critical", qsTr("Update check killed"), qsTr("Process took too long"));
            }
        }
    }
}
