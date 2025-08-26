pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils
import qs.Services.SystemInfo

Singleton {
    id: updateService
    property bool isArchBased: MainService.isArchBased
    property bool checkupdatesAvailable: false
    readonly property bool ready: isArchBased && checkupdatesAvailable
    readonly property bool busy: pkgProc.running
    readonly property int updates: updatePackages.length
    property var updatePackages: []
    property double lastSync: 0
    property bool lastWasFull: false
    property int failureCount: 0
    readonly property int failureThreshold: 5
    readonly property int minuteMs: 60 * 1000
    readonly property int pollInterval: 1 * minuteMs
    readonly property int syncInterval: 15 * minuteMs
    property int lastNotifiedUpdates: 0

    readonly property var updateCommand: ["xdg-terminal-exec", "--title=Global Updates", "-e", "sh", "-c", "$BIN/update.sh"]
    readonly property string notifyApp: "UpdateService"
    readonly property string notifyIcon: "system-software-update"
    readonly property var updateLineRe: /^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/

    PersistentProperties {
        id: cache
        reloadableId: "ArchCheckerCache"

        property string cachedUpdatePackagesJson: "[]"
        property double cachedLastSync: 0
    }

    Component.onCompleted: {
        const persisted = JSON.parse(cache.cachedUpdatePackagesJson || "[]");
        if (persisted.length)
            updatePackages = _clonePackageList(persisted);
        if (cache.cachedLastSync > 0)
            lastSync = cache.cachedLastSync;
    }

    function runUpdate() {
        if (updates > 0) {
            updateRunner.command = updateCommand;
            updateRunner.running = true;
        } else {
            doPoll(true);
        }
    }

    Connections {
        target: NotificationService
        function onActionInvoked(summary, appName, actionId, body) {
            if (String(appName) !== updateService.notifyApp)
                return;
            if (String(actionId) === "run-updates") {
                updateRunner.command = updateService.updateCommand;
                updateRunner.running = true;
            }
        }
    }

    function startUpdateProcess(cmd) {
        pkgProc.command = cmd;
        if (updateService.lastWasFull)
            killTimer.restart();
        pkgProc.running = true;
    }

    function doPoll(forceFull = false) {
        if (busy)
            return;
        const full = forceFull || (Date.now() > lastSync + syncInterval);
        lastWasFull = full;
        startUpdateProcess(full ? ["checkupdates", "--nocolor"] : ["checkupdates", "--nosync", "--nocolor"]);
    }

    Process {
        id: updateRunner
        /* qmllint disable */
        onExited: function (exitCode, exitStatus) {
            updateService.doPoll(false);
        }
        /* qmllint enable */
    }

    Process {
        id: pacmanCheck
        running: true
        command: ["sh", "-c", "command -v checkupdates >/dev/null && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                updateService.checkupdatesAvailable = (text || "").trim() === "yes";
                if (updateService.ready) {
                    updateService.doPoll();
                    pollTimer.start();
                }
            }
        }
    }

    Process {
        id: pkgProc
        /* qmllint disable */
        onExited: function (exitCode, exitStatus) {
            killTimer.stop();
            if (exitCode !== 0 && exitCode !== 2) {
                updateService.failureCount++;
                Logger.warn("UpdateService", `checkupdates failed (code: ${exitCode}, status: ${exitStatus})`);
                if (updateService.failureCount >= updateService.failureThreshold) {
                    NotificationService.send(qsTr("Update check failed"), qsTr(`Exit code: ${exitCode} (failed ${updateService.failureCount} times)`), {
                        appName: updateService.notifyApp,
                        appIcon: updateService.notifyIcon,
                        summaryKey: "update-check-failed"
                    });
                    updateService.failureCount = 0;
                }
                updateService.updatePackages = [];
            }
        }
        /* qmllint enable */

        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                if (pkgProc.running)
                    return;

                const parsed = updateService._parseUpdateOutput(out.text);
                updateService.updatePackages = parsed.pkgs;

                if (updateService.lastWasFull) {
                    updateService.lastSync = Date.now();
                }

                if (updateService.updates === 0) {
                    updateService.lastNotifiedUpdates = 0;
                } else if (updateService.updates > updateService.lastNotifiedUpdates) {
                    const added = updateService.updates - updateService.lastNotifiedUpdates;
                    const msg = added === 1 ? qsTr("One new package can be upgraded (") + updateService.updates + qsTr(")") : `${added} ${qsTr("new packages can be upgraded (")} ${updateService.updates} ${qsTr(")")}`;
                    NotificationService.send(qsTr("Updates Available"), msg, {
                        appName: updateService.notifyApp,
                        appIcon: updateService.notifyIcon,
                        summaryKey: "updates-available",
                        actions: [
                            {
                                id: "run-updates",
                                title: qsTr("Run updates"),
                                iconName: updateService.notifyIcon
                            }
                        ]
                    });
                    updateService.lastNotifiedUpdates = updateService.updates;
                }
            }
        }
        stderr: StdioCollector {
            id: err
            onStreamFinished: {
                const stderrText = (err.text || "").trim();
                if (stderrText) {
                    Logger.warn("UpdateService", "stderr:", stderrText);
                    updateService.failureCount++;
                    if (updateService.failureCount >= updateService.failureThreshold) {
                        NotificationService.send(qsTr("Update check failed"), stderrText, {
                            appName: updateService.notifyApp,
                            appIcon: updateService.notifyIcon,
                            summaryKey: "update-check-failed"
                        });
                        updateService.failureCount = 0;
                    }
                } else
                    updateService.failureCount = 0;
            }
        }
    }

    function _clonePackageList(list) {
        return (Array.isArray(list) ? list : []).map(p => ({
                    name: String(p.name || ""),
                    oldVersion: String(p.oldVersion || ""),
                    newVersion: String(p.newVersion || "")
                }));
    }

    function _parseUpdateOutput(rawText) {
        const raw = (rawText || "").trim();
        const lines = raw ? raw.split(/\r?\n/) : [];
        const pkgs = [];
        for (const line of lines) {
            const m = line.match(updateService.updateLineRe);
            if (m)
                pkgs.push({
                    name: m[1],
                    oldVersion: m[2],
                    newVersion: m[3]
                });
        }
        return {
            raw,
            pkgs
        };
    }

    Timer {
        id: pollTimer
        interval: updateService.pollInterval
        repeat: true
        onTriggered: if (updateService.ready)
            updateService.doPoll()
    }

    Timer {
        id: killTimer
        interval: updateService.minuteMs
        repeat: false
        onTriggered: {
            if (pkgProc.running && updateService.lastWasFull) {
                Logger.error("UpdateService", "Full update check killed (timeout)");
                NotificationService.send(qsTr("Update check killed"), qsTr("Full sync took too long; terminated"), {
                    appName: updateService.notifyApp,
                    appIcon: updateService.notifyIcon,
                    summaryKey: "update-check-killed"
                });
                pkgProc.running = false;
            }
        }
    }

    onUpdatePackagesChanged: {
        cache.cachedUpdatePackagesJson = JSON.stringify(_clonePackageList(updatePackages));
    }

    onLastSyncChanged: {
        cache.cachedLastSync = lastSync;
    }
}
