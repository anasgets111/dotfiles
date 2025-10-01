pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils

Singleton {
  id: updateService

  readonly property var allPackages: updatePackages.concat(aurPackages)
  readonly property bool aurBusy: aurProc.running
  property int aurDoneGeneration: -1
  property var aurPackages: []
  readonly property int aurUpdates: aurPackages.length
  readonly property bool busy: pkgProc.running || aurProc.running
  property bool checkupdatesAvailable: false
  property int failureCount: 0
  readonly property int failureThreshold: 5
  // Core state
  property bool isArchBased: MainService.isArchBased
  property int lastNotifiedTotal: 0
  property double lastSync: 0
  readonly property int minuteMs: 60 * 1000
  readonly property string notifyApp: "UpdateService"
  readonly property string notifyIcon: "system-software-update"
  property var pendingAurPackages: []
  property var pendingRepoPackages: []

  // Poll-cycle aggregation: commit once when both repo and AUR finish
  property int pollGeneration: 0
  readonly property int pollInterval: 15 * minuteMs
  readonly property bool ready: isArchBased && checkupdatesAvailable
  property int repoDoneGeneration: -1
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
      // Send notification via notify-send with an action to run updates
      Utils.runCmd(["notify-send", "-a", updateService.notifyApp, "-i", updateService.notifyIcon, "-A", "run-updates=" + qsTr("Run updates"), qsTr("Updates Available"), msg], function (out) {
        const chosen = String(out || "").trim();
        if (chosen === "run-updates") {
          updateRunner.command = updateService.updateCommand;
          updateRunner.running = true;
        }
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
  function _tryCommitEndOfPoll() {
    if (!ready)
      return;
    if (repoDoneGeneration === pollGeneration && aurDoneGeneration === pollGeneration) {
      // Commit results atomically for UI and cache
      updatePackages = _clonePackageList(pendingRepoPackages);
      aurPackages = _clonePackageList(pendingAurPackages);
      lastSync = Date.now();
      _notifyTotalsIfIncreased();
    }
  }
  function doAurPoll() {
    if (aurBusy)
      return;

    aurProc.command = ["sh", "-c", "if command -v yay >/dev/null 2>&1; then yay -Qua --color=never;" + "elif command -v paru >/dev/null 2>&1; then paru -Qua --color=never;" + "else exit 3; fi"];
    aurProc.running = true;
  }
  function doPoll() {
    if (busy)
      return;

    // New cycle
    pollGeneration++;
    repoDoneGeneration = -1;
    aurDoneGeneration = -1;
    pendingRepoPackages = [];
    pendingAurPackages = [];
    pkgProc.command = ["checkupdates", "--nocolor"];
    pkgProc.running = true;
    doAurPoll();
  }
  function runUpdate() {
    if (totalUpdates > 0) {
      updateRunner.command = updateCommand;
      updateRunner.running = true;
    } else {
      doPoll();
    }
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
  onAurPackagesChanged: cache.cachedAurPackagesJson = JSON.stringify(_clonePackageList(aurPackages))
  onLastSyncChanged: cache.cachedLastSync = lastSync
  onUpdatePackagesChanged: cache.cachedUpdatePackagesJson = JSON.stringify(_clonePackageList(updatePackages))

  PersistentProperties {
    id: cache

    property string cachedAurPackagesJson: "[]"
    property double cachedLastSync: 0
    property string cachedUpdatePackagesJson: "[]"

    reloadableId: "ArchCheckerCache"
  }
  Process {
    id: updateRunner

    onExited: function (exitCode, exitStatus) {
      updateService.doPoll();
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
            Utils.runCmd(["notify-send", "-a", updateService.notifyApp, "-i", updateService.notifyIcon, qsTr("Update check failed"), stderrText]);
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
        updateService.pendingRepoPackages = parsed.pkgs;
        updateService.repoDoneGeneration = updateService.pollGeneration;
        updateService._tryCommitEndOfPoll();
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0 && exitCode !== 2) {
        updateService.failureCount++;
        Logger.warn("UpdateService", `checkupdates failed (code: ${exitCode}, status: ${exitStatus})`);
        if (updateService.failureCount >= updateService.failureThreshold) {
          Utils.runCmd(["notify-send", "-a", updateService.notifyApp, "-i", updateService.notifyIcon, qsTr("Update check failed"), qsTr(`Exit code: ${exitCode} (failed ${updateService.failureCount} times)`)]);
          updateService.failureCount = 0;
        }
        updateService.pendingRepoPackages = [];
        updateService.repoDoneGeneration = updateService.pollGeneration;
        updateService._tryCommitEndOfPoll();
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
        updateService.pendingAurPackages = parsed.pkgs;
        updateService.aurDoneGeneration = updateService.pollGeneration;
        updateService._tryCommitEndOfPoll();
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (exitCode === 3) {
        Logger.log("UpdateService", "AUR helpers not found (yay/paru). AUR polling disabled.");
        updateService.pendingAurPackages = [];
      } else if (exitCode !== 0 && exitCode !== 1) {
        Logger.warn("UpdateService", `AUR check failed (code: ${exitCode}, status: ${exitStatus})`);
        updateService.pendingAurPackages = [];
      }
      updateService.aurDoneGeneration = updateService.pollGeneration;
      updateService._tryCommitEndOfPoll();
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
}
