pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: updateService

  readonly property var allPackages: updatePackages.concat(aurPackages)
  readonly property bool aurBusy: aurProc.running
  property var aurPackages: []
  readonly property int aurUpdates: aurPackages.length
  readonly property bool busy: pkgProc.running
  property bool checkupdatesAvailable: false
  property int failureCount: 0
  readonly property int failureThreshold: 5
  // Core state
  property bool isArchBased: MainService.isArchBased
  property int lastNotifiedTotal: 0
  property double lastSync: 0
  property bool lastWasFull: false
  readonly property int minuteMs: 60 * 1000
  readonly property string notifyApp: "UpdateService"
  readonly property string notifyIcon: "system-software-update"
  readonly property int pollInterval: 1 * minuteMs
  readonly property bool ready: isArchBased && checkupdatesAvailable
  readonly property int syncInterval: 15 * minuteMs
  readonly property int totalUpdates: updates + aurUpdates
  readonly property var updateCommand: ["xdg-terminal-exec", "--title=Global Updates", "-e", "sh", "-c", "$BIN/update.sh"]
  readonly property var updateLineRe: /^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/
  property var updatePackages: []
  readonly property int updates: updatePackages.length

  function _clonePackageList(list) {
    return (Array.isArray(list) ? list : []).map(p => {
      return ({
          "name": String(p.name || ""),
          "oldVersion": String(p.oldVersion || ""),
          "newVersion": String(p.newVersion || "")
        });
    });
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
        "appName": notifyApp,
        "appIcon": notifyIcon,
        "summaryKey": "updates-available",
        "actions": [
          {
            "id": "run-updates",
            "title": qsTr("Run updates"),
            "iconName": notifyIcon
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
        "raw": raw,
        "pkgs": []
      };

    const lines = raw.split(/\r?\n/);
    const pkgs = [];
    for (const line of lines) {
      const m = line.match(updateLineRe);
      if (m)
        pkgs.push({
          "name": m[1],
          "oldVersion": m[2],
          "newVersion": m[3]
        });
    }
    return {
      "raw": raw,
      "pkgs": pkgs
    };
  }
  function doAurPoll() {
    if (aurBusy)
      return;

    aurProc.command = ["sh", "-c", "if command -v yay >/dev/null 2>&1; then yay -Qua --color=never;" + "elif command -v paru >/dev/null 2>&1; then paru -Qua --color=never;" + "else exit 3; fi"];
    aurProc.running = true;
  }
  function doPoll(forceFull = false) {
    if (busy)
      return;

    const full = forceFull || Date.now() > lastSync + syncInterval;
    lastWasFull = full;
    startUpdateProcess(full ? ["checkupdates", "--nocolor"] : ["checkupdates", "--nosync", "--nocolor"]);
    if (full)
      doAurPoll();
  }
  function runUpdate() {
    if (updates > 0) {
      updateRunner.command = updateCommand;
      updateRunner.running = true;
    } else {
      doPoll(true);
    }
  }
  function startUpdateProcess(cmd) {
    pkgProc.command = cmd;
    if (lastWasFull)
      killTimer.restart();

    pkgProc.running = true;
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
  onAurPackagesChanged: {
    cache.cachedAurPackagesJson = JSON.stringify(_clonePackageList(aurPackages));
    _notifyTotalsIfIncreased();
  }
  onLastSyncChanged: cache.cachedLastSync = lastSync
  onUpdatePackagesChanged: {
    cache.cachedUpdatePackagesJson = JSON.stringify(_clonePackageList(updatePackages));
  }

  PersistentProperties {
    id: cache

    property string cachedAurPackagesJson: "[]"
    property double cachedLastSync: 0
    property string cachedUpdatePackagesJson: "[]"

    reloadableId: "ArchCheckerCache"
  }
  Connections {
    function onActionInvoked(summary, appName, actionId, body) {
      if (String(appName) !== updateService.notifyApp)
        return;

      if (String(actionId) === "run-updates") {
        updateRunner.command = updateService.updateCommand;
        updateRunner.running = true;
      }
    }

    target: NotificationService
  }
  Process {
    id: updateRunner

    onExited: function (exitCode, exitStatus) {
      updateService.doPoll(false);
    }
  }
  Process {
    id: pacmanCheck

    command: ["sh", "-c", "command -v checkupdates >/dev/null && echo yes || echo no"]
    running: true

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

    stderr: StdioCollector {
      id: repoStderr

      onStreamFinished: {
        const stderrText = (repoStderr.text || "").trim();
        if (stderrText) {
          Logger.warn("UpdateService", "stderr:", stderrText);
          updateService.failureCount++;
          if (updateService.failureCount >= updateService.failureThreshold) {
            NotificationService.send(qsTr("Update check failed"), stderrText, {
              "appName": updateService.notifyApp,
              "appIcon": updateService.notifyIcon,
              "summaryKey": "update-check-failed"
            });
            updateService.failureCount = 0;
          }
        } else {
          updateService.failureCount = 0;
        }
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

    onExited: function (exitCode, exitStatus) {
      killTimer.stop();
      if (exitCode !== 0 && exitCode !== 2) {
        updateService.failureCount++;
        Logger.warn("UpdateService", `checkupdates failed (code: ${exitCode}, status: ${exitStatus})`);
        if (updateService.failureCount >= updateService.failureThreshold) {
          NotificationService.send(qsTr("Update check failed"), qsTr(`Exit code: ${exitCode} (failed ${updateService.failureCount} times)`), {
            "appName": updateService.notifyApp,
            "appIcon": updateService.notifyIcon,
            "summaryKey": "update-check-failed"
          });
          updateService.failureCount = 0;
        }
        updateService.updatePackages = [];
      }
    }
  }
  Process {
    id: aurProc

    stderr: StdioCollector {
      id: aurStderr

      onStreamFinished: {
        const t = (aurStderr.text || "").trim();
        if (t)
          Logger.warn("UpdateService", "AUR stderr:", t);
      }
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

    onExited: function (exitCode, exitStatus) {
      if (exitCode === 0 || exitCode === 1)
        return;

      if (exitCode === 3) {
        Logger.log("UpdateService", "AUR helpers not found (yay/paru). AUR polling disabled.");
        return;
      }
      Logger.warn("UpdateService", `AUR check failed (code: ${exitCode}, status: ${exitStatus})`);
      updateService.aurPackages = [];
    }
  }
  Timer {
    id: pollTimer

    interval: updateService.pollInterval
    repeat: true

    onTriggered: {
      if (updateService.ready) {
        updateService.doPoll();
      }
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
          "appName": updateService.notifyApp,
          "appIcon": updateService.notifyIcon,
          "summaryKey": "update-check-killed"
        });
        pkgProc.running = false;
      }
    }
  }
}
