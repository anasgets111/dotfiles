pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils

Singleton {
  id: root

  readonly property var status: ({
      Idle: 0,
      Updating: 1,
      Completed: 2,
      Error: 3
    })

  property int updateState: status.Idle
  property string errorMessage: ""
  property string errorType: ""
  property int currentPackageIndex: 0
  property int totalPackagesToUpdate: 0
  property string currentPackageName: ""
  property var outputLines: []
  property var completedPackages: []
  property var failedPackages: []
  property var selectedPackages: ({})
  property bool selectAll: false
  readonly property var selectedPackageNames: Object.keys(selectedPackages).filter(k => selectedPackages[k])
  property var updatePackages: []
  property double lastSync: 0
  property int lastNotifiedTotal: 0
  property bool checkupdatesAvailable: false
  property int failureCount: 0
  property bool repoComplete: false
  property var tempRepoPackages: []
  property var packageSizes: ({})

  readonly property int totalUpdates: updatePackages.length
  readonly property int selectedCount: Object.values(selectedPackages).filter(v => v).length
  readonly property bool busy: pkgProc.running
  readonly property bool ready: MainService.isArchBased && checkupdatesAvailable
  readonly property int totalDownloadSize: {
    const pkgs = selectedPackageNames.length > 0 ? updatePackages.filter(pkg => selectedPackageNames.includes(pkg.name)) : updatePackages;
    return pkgs.reduce((total, pkg) => total + (packageSizes[pkg.name] || 0), 0);
  }
  readonly property int pollInterval: 15 * 60 * 1000
  readonly property int failureThreshold: 5
  readonly property var updateCommand: ["xdg-terminal-exec", "--title=Global Updates", "-e", "sh", "-c", "$BIN/update.sh"]
  readonly property var updateLineRe: /^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/

  function _clonePackageList(list) {
    return list.map(p => ({
          name: p.name || "",
          oldVersion: p.oldVersion || "",
          newVersion: p.newVersion || ""
        }));
  }

  function _notify(title, message, urgency = "normal", action = null) {
    const args = ["-u", urgency, "-a", "UpdateService", "-i", "system-software-update"];
    if (action)
      args.push("-A", `${action}=${qsTr("Run updates")}`);
    args.push(title, message);

    Utils.runCmd(["notify-send", ...args], out => {
      if (action && String(out || "").trim() === action) {
        updateRunner.command = updateCommand;
        updateRunner.running = true;
      }
    });
  }

  function _handleError(source, message, code) {
    Logger.warn("UpdateService", `${source} error (code: ${code}): ${message}`);
    if (++failureCount >= failureThreshold) {
      _notify(qsTr("Update check failed"), message, "critical", "dismiss");
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
      _notify(qsTr("Updates Available"), msg, "normal", "run-updates");
      lastNotifiedTotal = totalUpdates;
    }
  }

  function _parseOutput(text) {
    return (text || "").trim().split(/\r?\n/).filter(l => l).map(line => {
      const m = line.match(updateLineRe);
      return m ? {
        name: m[1],
        oldVersion: m[2],
        newVersion: m[3]
      } : null;
    }).filter(p => p);
  }

  function _commitResults() {
    if (!ready || !repoComplete)
      return;
    updatePackages = _clonePackageList(tempRepoPackages);
    lastSync = Date.now();
    _notifyIfIncreased();
    if (updatePackages.length > 0)
      fetchPackageSizes();
  }

  function fetchPackageSizes() {
    if (updatePackages.length === 0)
      return;
    sizeFetchProcess.command = ["expac", "-S", "%k\t%n", ...updatePackages.map(pkg => pkg.name)];
    sizeFetchProcess.running = true;
  }

  function doPoll() {
    if (busy)
      return;
    repoComplete = false;
    tempRepoPackages = [];
    pkgProc.command = ["checkupdates", "--nocolor"];
    pkgProc.running = true;
  }

  function runUpdate() {
    totalUpdates > 0 ? (updateRunner.command = updateCommand, updateRunner.running = true) : doPoll();
  }

  function executeUpdate() {
    const packages = selectedPackageNames.length > 0 ? selectedPackageNames : updatePackages.map(pkg => pkg.name);
    if (packages.length === 0) {
      Logger.warn("UpdateService", "No packages to update");
      return;
    }

    totalPackagesToUpdate = packages.length;
    currentPackageIndex = 0;
    currentPackageName = "";
    outputLines = [];
    completedPackages = [];
    failedPackages = [];
    updateState = status.Updating;

    updateProcess.command = ["bash", "-c", `pkexec pacman -S --noconfirm ${packages.join(' ')}`];
    updateProcess.running = true;
    Logger.log("UpdateService", `Starting update of ${packages.length} packages`);
  }

  function cancelUpdate() {
    if (updateProcess.running)
      updateProcess.running = false;
    updateState = status.Idle;
    outputLines = [];
  }

  function retryUpdate() {
    errorMessage = "";
    errorType = "";
    executeUpdate();
  }

  function toggleSelectAll() {
    selectAll = !selectAll;
    const newSelected = {};
    updatePackages.forEach(pkg => newSelected[pkg.name] = selectAll);
    selectedPackages = newSelected;
  }

  function togglePackage(packageName) {
    const newSelected = Object.assign({}, selectedPackages);
    newSelected[packageName] = !newSelected[packageName];
    selectedPackages = newSelected;
    selectAll = updatePackages.every(pkg => selectedPackages[pkg.name]);
  }

  function resetSelection() {
    selectedPackages = {};
    selectAll = false;
  }

  Component.onCompleted: {
    updatePackages = _clonePackageList(JSON.parse(cache.cachedUpdatePackagesJson || "[]"));
    if (cache.cachedLastSync > 0)
      lastSync = cache.cachedLastSync;
  }

  onUpdatePackagesChanged: cache.cachedUpdatePackagesJson = JSON.stringify(_clonePackageList(updatePackages))
  onLastSyncChanged: cache.cachedLastSync = lastSync

  PersistentProperties {
    id: cache
    property string cachedUpdatePackagesJson: "[]"
    property double cachedLastSync: 0
    reloadableId: "ArchCheckerCache"
  }

  Process {
    id: updateRunner
    onExited: (exitCode, exitStatus) => root.doPoll()
  }

  Process {
    id: pacmanCheck
    command: ["sh", "-c", "command -v checkupdates >/dev/null && echo yes || echo no"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        root.checkupdatesAvailable = (text || "").trim() === "yes";
        if (root.ready) {
          root.doPoll();
          pollTimer.start();
        }
      }
    }
  }

  Process {
    id: sizeFetchProcess
    stdout: SplitParser {
      onRead: line => {
        const parts = line.trim().split('\t');
        if (parts.length === 2) {
          const sizeBytes = parseFloat(parts[0]);
          const packageName = parts[1];
          if (!isNaN(sizeBytes) && packageName) {
            const newSizes = Object.assign({}, root.packageSizes);
            newSizes[packageName] = Math.round(sizeBytes);
            root.packageSizes = newSizes;
          }
        }
      }
    }
    onExited: {
      Logger.log("UpdateService", `Fetched sizes for ${Object.keys(root.packageSizes).length} packages`);
      root.totalDownloadSizeChanged();
    }
  }

  Process {
    id: pkgProc
    stderr: StdioCollector {
      onStreamFinished: {
        const msg = (text || "").trim();
        msg ? root._handleError("checkupdates", msg, -1) : (root.failureCount = 0);
      }
    }
    stdout: StdioCollector {
      onStreamFinished: {
        if (!pkgProc.running) {
          root.tempRepoPackages = root._parseOutput(text);
          root.repoComplete = true;
          root._commitResults();
        }
      }
    }
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 && exitCode !== 2) {
        root._handleError("checkupdates", `Exit code: ${exitCode}`, exitCode);
        root.tempRepoPackages = [];
      }
      root.repoComplete = true;
      root._commitResults();
    }
  }

  Process {
    id: updateProcess

    function addOutput(line, type) {
      if (line.trim() === "")
        return;
      root.outputLines.push({
        text: line,
        type: type
      });
      const match = line.match(/(?:installing|upgrading)\s+(\S+)/);
      if (match) {
        root.currentPackageIndex++;
        root.currentPackageName = match[1];
        root.completedPackages.push(match[1]);
      }
    }

    stdout: SplitParser {
      onRead: data => {
        const line = data.trim();
        const isError = line.toLowerCase().includes("error:") || line.includes("failed");
        updateProcess.addOutput(line, isError ? "error" : "info");
      }
    }

    stderr: SplitParser {
      onRead: data => {
        const line = data.trim();
        if (line === "")
          return;
        updateProcess.addOutput(line, "error");

        if (line.includes("failed retrieving") || line.includes("download timeout") || line.includes("connection refused") || line.includes("could not resolve host")) {
          root.errorType = "network";
          root.errorMessage = "Network error: Failed to download packages";
        } else if (line.includes("not enough free disk space")) {
          root.errorType = "disk";
          root.errorMessage = "Insufficient disk space";
        } else if (line.includes("authentication failure") || line.includes("incorrect password")) {
          root.errorType = "auth";
          root.errorMessage = "Authentication failed";
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      root.updateState = exitCode === 0 ? root.status.Completed : root.status.Error;
      if (exitCode === 0) {
        root._notify("Update Complete", `${root.completedPackages.length} packages updated successfully`);
        root.resetSelection();
        root.doPoll();
      } else {
        if (!root.errorType) {
          root.errorType = "unknown";
          root.errorMessage = `Update failed with code ${exitCode}`;
        }
        root._notify("Update Failed", root.errorMessage, "critical");
      }
    }
  }

  Timer {
    id: pollTimer
    interval: root.pollInterval
    repeat: true
    onTriggered: {
      if (root.ready)
        root.doPoll();
    }
  }

  Component.onDestruction: pollTimer.stop()
}
