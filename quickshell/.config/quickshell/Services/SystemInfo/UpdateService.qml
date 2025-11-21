pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: root

  readonly property bool busy: pkgProc.running
  property bool checkupdatesAvailable: false
  property var completedPackages: []
  property int currentPackageIndex: 0
  property string currentPackageName: ""
  property string errorMessage: ""
  property string errorType: ""
  property int failureCount: 0
  readonly property int failureThreshold: 5
  property int lastNotificationId: 0
  property int lastNotifiedTotal: 0
  property double lastSync: 0
  property var outputLines: []
  property var packageSizes: ({})
  readonly property int pollInterval: 15 * 60 * 1000
  readonly property bool ready: MainService.isArchBased && checkupdatesAvailable
  readonly property var status: ({
      Idle: 0,
      Updating: 1,
      Completed: 2,
      Error: 3
    })
  readonly property int totalDownloadSize: {
    return updatePackages.reduce((sum, p) => sum + (packageSizes[p.name] || 0), 0);
  }
  property int totalPackagesToUpdate: 0
  readonly property int totalUpdates: updatePackages.length
  readonly property var updateLineRe: /^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/
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
    const args = ["-u", urgency, "-a", "System Updates", "-i", "system-software-update", "--print-id", "--replace-id", String(lastNotificationId)];
    if (action)
      args.push("-A", `${action}=${qsTr("Run updates")}`);
    args.push(title, message);

    Logger.log("UpdateService", `Sending notification: replace=${lastNotificationId}, title=${title}`);

    Utils.runCmd(["notify-send", ...args], out => {
      // Parse output for ID and action response
      const lines = (out || "").trim().split('\n');

      // Extract first numeric line as notification ID
      for (const line of lines) {
        const id = parseInt(line.trim());
        if (!isNaN(id)) {
          Logger.log("UpdateService", `Notification ID updated: ${lastNotificationId} -> ${id}`);
          lastNotificationId = id;
          break;
        }
      }

      // Check if action was triggered
      if (action && lines.some(line => line.includes(action))) {
        executeUpdate();
      }
    });
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

  function cancelUpdate() {
    if (updateProcess.running)
      updateProcess.running = false;
    updateState = status.Idle;
    outputLines = [];
  }

  function closeAllNotifications() {
    Logger.log("UpdateService", "Closing all 'System Updates' notifications");
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
    if (totalUpdates === 0) {
      Logger.warn("UpdateService", "No packages to update");
      return;
    }

    // We do NOT close the notification here. We keep the ID so the next notification
    // (Update Complete/Failed) can replace it, preventing notification spam.

    totalPackagesToUpdate = totalUpdates;
    currentPackageIndex = 0;
    currentPackageName = "";
    outputLines = [];
    completedPackages = [];
    updateState = status.Updating;

    // Use update.sh with --polkit and --stream for integrated output
    // Ensure our Polkit agent is prepared so the authentication prompt appears in Quickshell
    try {
      PolkitService.prepareAgent();
    } catch (e) {
      Logger.warn("UpdateService", `prepareAgent failed: ${e}`);
    }

    Logger.log("UpdateService", `Starting system update`);
    updateProcess.command = [Quickshell.env("HOME") + "/.local/bin/update.sh", "--polkit"];
    updateProcess.running = true;
  }

  function fetchPackageSizes() {
    if (updatePackages.length === 0)
      return;
    sizeFetchProcess.command = ["expac", "-S", "%k\t%n", ...updatePackages.map(p => p.name)];
    sizeFetchProcess.running = true;
  }

  function retryUpdate() {
    errorMessage = "";
    errorType = "";
    executeUpdate();
  }

  Component.onCompleted: {
    updatePackages = JSON.parse(cache.cachedUpdatePackagesJson || "[]");
    if (cache.cachedLastSync > 0)
      lastSync = cache.cachedLastSync;
    if (cache.cachedNotificationId > 0)
      lastNotificationId = cache.cachedNotificationId;
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
        if (parts.length !== 2)
          return;
        const sizeBytes = parseFloat(parts[0]);
        const packageName = parts[1];
        if (!isNaN(sizeBytes) && packageName) {
          // expac %k returns bytes, convert to KiB for consistency
          root.packageSizes = Object.assign({}, root.packageSizes, {
            [packageName]: Math.round(sizeBytes / 1024)
          });
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      Logger.log("UpdateService", `Fetched sizes for ${Object.keys(root.packageSizes).length} packages`);
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
        const parsed = root._parseOutput(text);
        root.updatePackages = parsed;
        root.lastSync = Date.now();
        // We do NOT reset lastNotificationId here anymore.
        // This allows the "Update Complete" notification to persist its ID
        // so it can be closed by the user.
        root._notifyIfIncreased();
        if (parsed.length > 0)
          root.fetchPackageSizes();
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 && exitCode !== 2) {
        root._handleError("checkupdates", `Exit code: ${exitCode}`, exitCode);
      }
    }
  }

  Process {
    id: updateProcess

    function addOutput(line, type) {
      if (!line.trim())
        return;

      // Create a new array reference to trigger QML property change
      var newLines = root.outputLines.slice();
      newLines.push({
        text: line,
        type: type
      });
      root.outputLines = newLines;

      const match = line.match(/(?:installing|upgrading)\s+(\S+)/);
      if (match) {
        root.currentPackageIndex++;
        root.currentPackageName = match[1];
        root.completedPackages.push(match[1]);
      }
    }

    stderr: SplitParser {
      onRead: data => {
        const line = data.trim();
        if (!line)
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
    stdout: SplitParser {
      onRead: data => {
        const line = data.trim();
        const isError = line.toLowerCase().includes("error:") || line.includes("failed");
        updateProcess.addOutput(line, isError ? "error" : "info");
      }
    }

    onExited: (exitCode, exitStatus) => {
      root.updateState = exitCode === 0 ? root.status.Completed : root.status.Error;
      if (exitCode === 0) {
        root._notify("Update Complete", `${root.completedPackages.length} packages updated successfully`);
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

    onTriggered: if (root.ready)
      root.doPoll()
  }
}
