pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils

Singleton {
  id: updateService

  // Core state
  property var updatePackages: []
  property var aurPackages: []
  property double lastSync: 0
  property int lastNotifiedTotal: 0
  property bool checkupdatesAvailable: false
  property int failureCount: 0

  // Poll cycle tracking
  property bool repoComplete: false
  property bool aurComplete: false
  property var tempRepoPackages: []
  property var tempAurPackages: []

  // Computed properties
  readonly property var allPackages: updatePackages.concat(aurPackages)
  readonly property int updates: updatePackages.length
  readonly property int aurUpdates: aurPackages.length
  readonly property int totalUpdates: updates + aurUpdates
  readonly property bool busy: pkgProc.running || aurProc.running
  readonly property bool ready: MainService.isArchBased && checkupdatesAvailable

  // Constants
  readonly property int pollInterval: 15 * 60 * 1000
  readonly property int failureThreshold: 5
  readonly property var updateCommand: ["xdg-terminal-exec", "--title=Global Updates", "-e", "sh", "-c", "$BIN/update.sh"]
  readonly property var updateLineRe: /^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/

  function _clonePackageList(list) {
    return list.map(p => ({
          name: p.name || "",
          oldVersion: p.oldVersion || "",
          newVersion: p.newVersion || "",
          source: p.source || "repo"
        }));
  }

  function _notify(title, message, action) {
    Utils.runCmd(["notify-send", "-a", "UpdateService", "-i", "system-software-update", "-A", `${action}=${qsTr("Run updates")}`, title, message], out => {
      if (String(out || "").trim() === action) {
        updateRunner.command = updateCommand;
        updateRunner.running = true;
      }
    });
  }

  function _handleError(source, message, code) {
    Logger.warn("UpdateService", `${source} error (code: ${code}): ${message}`);
    if (++failureCount >= failureThreshold) {
      _notify(qsTr("Update check failed"), message, "dismiss");
      failureCount = 0;
    }
  }

  function _notifyIfIncreased() {
    if (!ready || totalUpdates === 0) {
      lastNotifiedTotal = 0;
      return;
    }
    if (totalUpdates > lastNotifiedTotal) {
      const added = totalUpdates - lastNotifiedTotal;
      const msg = added === 1 ? `${qsTr("One new package can be upgraded")} (${totalUpdates})` : `${added} ${qsTr("new packages can be upgraded")} (${totalUpdates})`;
      _notify(qsTr("Updates Available"), msg, "run-updates");
      lastNotifiedTotal = totalUpdates;
    }
  }

  function _parseOutput(text, source) {
    const lines = (text || "").trim().split(/\r?\n/).filter(l => l);
    return lines.map(line => {
      const m = line.match(updateLineRe);
      return m ? {
        name: m[1],
        oldVersion: m[2],
        newVersion: m[3],
        source: source || "repo"
      } : null;
    }).filter(p => p);
  }

  function _commitResults() {
    if (!ready || !repoComplete || !aurComplete)
      return;

    updatePackages = _clonePackageList(tempRepoPackages);
    aurPackages = _clonePackageList(tempAurPackages);
    lastSync = Date.now();
    _notifyIfIncreased();
  }
  function doAurPoll() {
    if (busy)
      return;

    aurProc.command = ["sh", "-c", "if command -v yay >/dev/null 2>&1; then yay -Qua --color=never;" + "elif command -v paru >/dev/null 2>&1; then paru -Qua --color=never;" + "else exit 3; fi"];
    aurProc.running = true;
  }
  function doPoll() {
    if (busy)
      return;

    repoComplete = false;
    aurComplete = false;
    tempRepoPackages = [];
    tempAurPackages = [];
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
    updatePackages = _clonePackageList(JSON.parse(cache.cachedUpdatePackagesJson || "[]"));
    aurPackages = _clonePackageList(JSON.parse(cache.cachedAurPackagesJson || "[]"));
    if (cache.cachedLastSync > 0)
      lastSync = cache.cachedLastSync;
  }
  onUpdatePackagesChanged: cache.cachedUpdatePackagesJson = JSON.stringify(_clonePackageList(updatePackages))
  onAurPackagesChanged: cache.cachedAurPackagesJson = JSON.stringify(_clonePackageList(aurPackages))
  onLastSyncChanged: cache.cachedLastSync = lastSync

  PersistentProperties {
    id: cache

    property string cachedAurPackagesJson: "[]"
    property double cachedLastSync: 0
    property string cachedUpdatePackagesJson: "[]"

    reloadableId: "ArchCheckerCache"
  }
  Process {
    id: updateRunner

    onExited: (exitCode, exitStatus) => {
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
      onStreamFinished: {
        const msg = (text || "").trim();
        if (msg)
          updateService._handleError("checkupdates", msg, -1);
        else
          updateService.failureCount = 0;
      }
    }

    stdout: StdioCollector {
      onStreamFinished: {
        if (pkgProc.running)
          return;
        updateService.tempRepoPackages = updateService._parseOutput(text, "repo");
        updateService.repoComplete = true;
        updateService._commitResults();
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 && exitCode !== 2) {
        updateService._handleError("checkupdates", `Exit code: ${exitCode}`, exitCode);
        updateService.tempRepoPackages = [];
      }
      updateService.repoComplete = true;
      updateService._commitResults();
    }
  }
  Process {
    id: aurProc

    stderr: StdioCollector {
      onStreamFinished: {
        const msg = (text || "").trim();
        if (msg)
          Logger.warn("UpdateService", "AUR stderr:", msg);
      }
    }

    stdout: StdioCollector {
      onStreamFinished: {
        if (aurProc.running)
          return;
        updateService.tempAurPackages = updateService._parseOutput(text, "aur");
        updateService.aurComplete = true;
        updateService._commitResults();
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 3) {
        Logger.log("UpdateService", "AUR helpers not found (yay/paru). AUR polling disabled.");
      } else if (exitCode !== 0 && exitCode !== 1) {
        Logger.warn("UpdateService", `AUR check failed (code: ${exitCode})`);
      }
      updateService.tempAurPackages = [];
      updateService.aurComplete = true;
      updateService._commitResults();
    }
  }
  Component.onDestruction: {
    pollTimer.stop();
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
