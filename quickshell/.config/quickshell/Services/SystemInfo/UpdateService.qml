pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils

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
            Quickshell.execDetached(updateCommand);
        } else {
            doPoll(true);
        }
    }

    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", notifyApp, "-i", notifyIcon, title || "", body || ""]);
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
                    updateService.notify(qsTr("Update check failed"), qsTr(`Exit code: ${exitCode} (failed ${updateService.failureCount} times)`));
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

                updateService._summarizeAndNotify();
            }
        }
        stderr: StdioCollector {
            id: err
            onStreamFinished: {
                const stderrText = (err.text || "").trim();
                if (stderrText) {
                    Logger.warn("UpdateService", "stderr:", stderrText);
                    updateService.failureCount++;
                    updateService._notifyOnFailureThreshold(stderrText);
                } else
                    updateService.failureCount = 0;
            }
        }
    }

    function _notifyOnFailureThreshold(body) {
        if (failureCount >= failureThreshold) {
            notify(qsTr("Update check failed"), body || "");
            failureCount = 0;
            return true;
        }
        return false;
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

    function _summarizeAndNotify() {
        if (updates === 0) {
            lastNotifiedUpdates = 0;
            return;
        }
        if (updates <= lastNotifiedUpdates)
            return;
        const added = updates - lastNotifiedUpdates;
        const msg = added === 1 ? qsTr("One new package can be upgraded (") + updates + qsTr(")") : `${added} ${qsTr("new packages can be upgraded (")} ${updates} ${qsTr(")")}`;
        notify(qsTr("Updates Available"), msg);
        lastNotifiedUpdates = updates;
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
                updateService.notify(qsTr("Update check killed"), qsTr("Full sync took too long; terminated"));
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
