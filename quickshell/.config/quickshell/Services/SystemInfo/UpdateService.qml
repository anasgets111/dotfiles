pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils
import qs.Services.SystemInfo

Singleton {
    id: updateService

    // Core state
    property bool isArchBased: MainService.isArchBased
    property bool checkupdatesAvailable: false
    readonly property bool ready: isArchBased && checkupdatesAvailable
    readonly property bool busy: pkgProc.running
    readonly property bool aurBusy: aurProc.running
    property var updatePackages: []
    property var aurPackages: []
    readonly property int updates: updatePackages.length
    readonly property int aurUpdates: aurPackages.length
    readonly property int totalUpdates: updates + aurUpdates
    readonly property var allPackages: updatePackages.concat(aurPackages)
    property double lastSync: 0
    property bool lastWasFull: false
    property int failureCount: 0
    readonly property int failureThreshold: 5
    readonly property int minuteMs: 60 * 1000
    readonly property int pollInterval: 1 * minuteMs
    readonly property int syncInterval: 15 * minuteMs
    property int lastNotifiedTotal: 0

    readonly property var updateCommand: ["xdg-terminal-exec", "--title=Global Updates", "-e", "sh", "-c", "$BIN/update.sh"]
    readonly property string notifyApp: "UpdateService"
    readonly property string notifyIcon: "system-software-update"
    readonly property var updateLineRe: /^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/

    PersistentProperties {
        id: cache
        reloadableId: "ArchCheckerCache"
        property string cachedUpdatePackagesJson: "[]"
        property double cachedLastSync: 0
        property string cachedAurPackagesJson: "[]"
    }

    Component.onCompleted: {
        const persisted = JSON.parse(cache.cachedUpdatePackagesJson || "[]");
        if (persisted.length)
            updatePackages = _clonePackageList(persisted);

        if (cache.cachedLastSync > 0)
            lastSync = cache.cachedLastSync;

        const persistedAur = JSON.parse(cache.cachedAurPackagesJson || "[]");
        if (persistedAur.length)
            aurPackages = _clonePackageList(persistedAur);
    }

    function _notifyTotalsIfIncreased() {
        if (!ready)
            return;
        if (totalUpdates === 0) {
            lastNotifiedTotal = 0;
            return;
        }
        if (totalUpdates > lastNotifiedTotal) {
            const added = totalUpdates - lastNotifiedTotal;
            const msg = added === 1 ? qsTr("One new package can be upgraded (") + totalUpdates + qsTr(")") : `${added} ${qsTr("new packages can be upgraded (")} ${totalUpdates} ${qsTr(")")}`;
            NotificationService.send(qsTr("Updates Available"), msg, {
                appName: notifyApp,
                appIcon: notifyIcon,
                summaryKey: "updates-available",
                actions: [
                    {
                        id: "run-updates",
                        title: qsTr("Run updates"),
                        iconName: notifyIcon
                    }
                ]
            });
            lastNotifiedTotal = totalUpdates;
        }
    }

    function _parseStandardOutput(rawText) {
        const raw = (rawText || "").trim();
        if (!raw)
            return {
                raw,
                pkgs: []
            };
        const lines = raw.split(/\r?\n/);
        const pkgs = [];
        for (const line of lines) {
            const m = line.match(updateLineRe);
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

    function _clonePackageList(list) {
        return (Array.isArray(list) ? list : []).map(p => ({
                    name: String(p.name || ""),
                    oldVersion: String(p.oldVersion || ""),
                    newVersion: String(p.newVersion || "")
                }));
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
        if (lastWasFull)
            killTimer.restart();
        pkgProc.running = true;
    }

    function doPoll(forceFull = false) {
        if (busy)
            return;
        const full = forceFull || Date.now() > lastSync + syncInterval;
        lastWasFull = full;
        startUpdateProcess(full ? ["checkupdates", "--nocolor"] : ["checkupdates", "--nosync", "--nocolor"]);
    }

    function doAurPoll() {
        if (aurBusy)
            return;
        aurProc.command = ["sh", "-c", "if command -v yay >/dev/null 2>&1; then yay -Qua --color=never;" + "elif command -v paru >/dev/null 2>&1; then paru -Qua --color=never;" + "else exit 3; fi"];
        aurProc.running = true;
    }

    Process {
        id: updateRunner
        onExited: function (exitCode, exitStatus) {
            updateService.doPoll(false);
        }
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
                    updateService.doAurPoll();
                    pollTimer.start();
                }
            }
        }
    }

    Process {
        id: pkgProc
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
        stdout: StdioCollector {
            id: repoStdout
            onStreamFinished: {
                if (pkgProc.running)
                    return;
                const parsed = updateService._parseStandardOutput(repoStdout.text);
                updateService.updatePackages = parsed.pkgs;
                if (updateService.lastWasFull)
                    updateService.lastSync = Date.now();
                updateService._notifyTotalsIfIncreased();
            }
        }
        stderr: StdioCollector {
            id: repoStderr
            onStreamFinished: {
                const stderrText = (repoStderr.text || "").trim();
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
                } else {
                    updateService.failureCount = 0;
                }
            }
        }
    }

    Process {
        id: aurProc
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0)
                return;
            if (exitCode === 3) {
                Logger.log("UpdateService", "AUR helpers not found (yay/paru). AUR polling disabled.");
                return;
            }
            Logger.warn("UpdateService", `AUR check failed (code: ${exitCode}, status: ${exitStatus})`);
            updateService.aurPackages = [];
        }
        stdout: StdioCollector {
            id: aurStdout
            onStreamFinished: {
                if (aurProc.running)
                    return;
                const parsed = updateService._parseStandardOutput(aurStdout.text);
                updateService.aurPackages = parsed.pkgs;
                updateService._notifyTotalsIfIncreased();
            }
        }
        stderr: StdioCollector {
            id: aurStderr
            onStreamFinished: {
                const t = (aurStderr.text || "").trim();
                if (t)
                    Logger.warn("UpdateService", "AUR stderr:", t);
            }
        }
    }

    Timer {
        id: pollTimer
        interval: updateService.pollInterval
        repeat: true
        onTriggered: if (updateService.ready) {
            updateService.doPoll();
            updateService.doAurPoll();
        }
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

    onAurPackagesChanged: {
        cache.cachedAurPackagesJson = JSON.stringify(_clonePackageList(aurPackages));
        _notifyTotalsIfIncreased();
    }

    onLastSyncChanged: cache.cachedLastSync = lastSync
}
