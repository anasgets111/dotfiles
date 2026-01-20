pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: root

  property var _notifyQueue: []
  property var _pendingNotifyAction: null
  readonly property bool busy: pkgProc.running
  property bool checkupdatesAvailable: false
  property int currentPackageIndex: 0
  property string currentPackageName: ""
  property string errorMessage: ""
  property int failureCount: 0
  readonly property int failureThreshold: 5
  property int lastNotificationId: 0
  property int lastNotifiedTotal: 0
  property double lastSync: 0
  property var outputLines: []
  property var packageSizes: ({})
  readonly property int pollInterval: 15 * 60 * 1000
  readonly property bool ready: MainService.isArchBased && checkupdatesAvailable
  readonly property var status: Object.freeze({
    Idle: 0,
    Updating: 1,
    Completed: 2,
    Error: 3
  })
  readonly property int totalDownloadSize: updatePackages.reduce((sum, p) => sum + (packageSizes[p.name] ?? 0), 0)
  property int totalPackagesToUpdate: 0
  readonly property int totalUpdates: updatePackages.length
  property var updatePackages: []
  property int updateState: status.Idle

  function _handleError(source, message, code) {
    Logger.warn("UpdateService", `${source} error (code: ${code}): ${message}`);
    if (++failureCount >= failureThreshold) {
      _notify(qsTr("Update check failed"), message, "critical");
      failureCount = 0;
    }
  }

  function _notify(title, message, urgency = "normal", action = null) {
    const args = ["-u", urgency, "-a", "System Updates", "-n", "system-software-update", "--print-id", "--replace-id", String(lastNotificationId)];
    if (action)
      args.push("-A", `${action}=${qsTr("Run updates")}`);
    _notifyQueue.push({
      args: args.concat(title, message),
      action
    });
    _processNotifyQueue();
  }

  function _notifyIfIncreased() {
    if (!ready || totalUpdates === 0) {
      lastNotifiedTotal = 0;
      return;
    }
    if (totalUpdates <= lastNotifiedTotal)
      return;
    const added = totalUpdates - lastNotifiedTotal;
    const msg = added === 1 ? `${qsTr("One new package can be upgraded")} (${totalUpdates})` : `${added} ${qsTr("new packages can be upgraded")} (${totalUpdates})`;
    _notify(qsTr("Updates Available"), msg, "normal", "run-updates");
    lastNotifiedTotal = totalUpdates;
  }

  function _parseOutput(text) {
    const re = /^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/;
    return (text ?? "").trim().split(/\r?\n/).reduce((list, line) => {
      const m = line.match(re);
      if (m)
        list.push({
          name: m[1],
          oldVersion: m[2],
          newVersion: m[3]
        });
      return list;
    }, []);
  }

  function _processNotifyQueue() {
    if (_notifyProc.running || !_notifyQueue.length)
      return;
    const job = _notifyQueue.shift();
    _pendingNotifyAction = job.action;
    _notifyProc.command = ["notify-send"].concat(job.args);
    _notifyProc.running = true;
  }

  function cancelUpdate() {
    if (updateProcess.running)
      updateProcess.running = false;
    updateState = status.Idle;
    outputLines = [];
  }

  function closeAllNotifications() {
    NotificationService.dismissNotificationsByAppName("System Updates");
    lastNotificationId = 0;
  }

  function doPoll() {
    if (busy)
      return;
    pkgProc.command = ["checkupdates", "--nocolor"];
    pkgProc.running = true;
  }

  function executeUpdate() {
    if (totalUpdates === 0)
      return;
    totalPackagesToUpdate = totalUpdates;
    currentPackageIndex = 0;
    currentPackageName = "";
    outputLines = [];
    errorMessage = "";
    updateState = status.Updating;
    updateProcess.command = ["update"];
    updateProcess.running = true;
  }

  function fetchPackageSizes() {
    if (!updatePackages.length)
      return;
    sizeFetchProcess.command = ["expac", "-S", "%k\t%n"].concat(updatePackages.map(p => p.name));
    sizeFetchProcess.running = true;
  }

  Component.onCompleted: {
    const c = cache;
    updatePackages = JSON.parse(c.cachedUpdatePackagesJson || "[]");
    lastSync = c.cachedLastSync || 0;
    lastNotificationId = c.cachedNotificationId || 0;
  }
  Component.onDestruction: pollTimer.stop()
  onLastNotificationIdChanged: cache.cachedNotificationId = lastNotificationId
  onLastSyncChanged: cache.cachedLastSync = lastSync
  onUpdatePackagesChanged: cache.cachedUpdatePackagesJson = JSON.stringify(updatePackages)

  PersistentProperties {
    id: cache

    property double cachedLastSync: 0
    property int cachedNotificationId: 0
    property string cachedUpdatePackagesJson: "[]"

    reloadableId: "ArchCheckerCache"
  }

  Process {
    id: pacmanCheck

    command: ["sh", "-c", "command -v checkupdates >/dev/null && echo yes || echo no"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        root.checkupdatesAvailable = (text ?? "").trim() === "yes";
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
        const size = parseFloat(parts[0]);
        const name = parts[1];
        if (!isNaN(size) && name)
          root.packageSizes = Object.assign({}, root.packageSizes, {
            [name]: Math.round(size / 1024)
          });
      }
    }
  }

  Process {
    id: pkgProc

    stderr: StdioCollector {
      onStreamFinished: {
        const msg = (text ?? "").trim();
        msg ? root._handleError("checkupdates", msg, -1) : (root.failureCount = 0);
      }
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const packages = root._parseOutput(text);
        root.updatePackages = packages;
        root.lastSync = Date.now();
        root._notifyIfIncreased();
        if (packages.length > 0)
          root.fetchPackageSizes();
      }
    }

    onExited: (code, exitStatus) => {
      if (code !== 0 && code !== 2)
        root._handleError("checkupdates", `Exit code: ${code}`, code);
    }
  }

  Process {
    id: updateProcess

    function addLine(line, isError = false) {
      const trimmed = line.trim();
      if (!trimmed)
        return;
      root.outputLines = root.outputLines.concat({
        text: trimmed,
        type: isError ? "error" : "info"
      });
      const match = trimmed.match(/(?:installing|upgrading)\s+(\S+)/i);
      if (match) {
        root.currentPackageIndex++;
        root.currentPackageName = match[1];
      }
    }

    stderr: SplitParser {
      onRead: data => {
        const line = data.trim();
        if (!line)
          return;
        updateProcess.addLine(line, true);
        const lower = line.toLowerCase();
        if (lower.includes("failed retrieving") || lower.includes("download timeout") || lower.includes("connection refused") || lower.includes("could not resolve host")) {
          root.errorMessage = "Network error: Failed to download packages";
        } else if (lower.includes("not enough free disk space")) {
          root.errorMessage = "Insufficient disk space";
        } else if (lower.includes("authentication failure") || lower.includes("incorrect password")) {
          root.errorMessage = "Authentication failed";
        }
      }
    }
    stdout: SplitParser {
      onRead: data => {
        const line = data.trim();
        if (!line)
          return;
        const lower = line.toLowerCase();
        updateProcess.addLine(line, lower.includes("error:") || line.includes("failed"));
      }
    }

    onExited: (code, exitStatus) => {
      root.updateState = code === 0 ? root.status.Completed : root.status.Error;
      if (code === 0) {
        root._notify("Update Complete", `${root.currentPackageIndex} packages updated successfully`);
        root.doPoll();
      } else {
        if (!root.errorMessage)
          root.errorMessage = `Update failed with code ${code}`;
        root._notify("Update Failed", root.errorMessage, "critical");
      }
    }
  }

  Timer {
    id: pollTimer

    interval: root.pollInterval
    repeat: true

    onTriggered: if (root.ready)
      root.doPoll()
  }

  Process {
    id: _notifyProc

    stdout: StdioCollector {
      onStreamFinished: {
        const lines = (text || "").trim().split('\n');
        const id = lines.map(l => parseInt(l.trim())).find(v => !isNaN(v));
        if (!isNaN(id))
          root.lastNotificationId = id;
        const action = root._pendingNotifyAction;
        root._pendingNotifyAction = null;
        if (action && lines.some(l => l.includes(action)))
          root.executeUpdate();
        root._processNotifyQueue();
      }
    }

    onRunningChanged: if (!running)
      root._processNotifyQueue()
  }
}
