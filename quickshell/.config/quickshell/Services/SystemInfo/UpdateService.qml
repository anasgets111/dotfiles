pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services
import qs.Services.Utils

Singleton {
  id: root

  property bool _checkUpdatesAvailable: false
  property bool _checking: false
  property int _failureCount: 0
  readonly property bool _hasPackageCache: Settings.isStateLoaded && Array.isArray(Settings.state.updates.packages)
  readonly property string _notificationAppName: "System Updates"
  property var _packageSizes: ({})
  property var _pendingActionArgs: null
  readonly property int _pollInterval: 15 * 60 * 1000
  readonly property int _pollTimerInterval: _hasPackageCache && lastSuccessfulCheck > 0 ? Math.max(1, _pollInterval - Math.max(0, Date.now() - lastSuccessfulCheck)) : 1
  readonly property string _runUpdatesAction: "run-updates"
  property string _state: "idle"
  property bool _updateProcessStarted: false
  readonly property bool busy: _checking || updateProcess.running || isUpdating
  readonly property string checkError: Settings.isStateLoaded ? Settings.state.updates.lastCheckError : ""
  property int completedPackageCount: 0
  property string currentPackage: ""
  property int currentPackageIndex: 0
  property string currentStep: ""
  property string errorMessage: ""
  readonly property bool isChecking: _checking
  readonly property bool isCompleted: _state === "completed"
  readonly property bool isError: _state === "error"
  readonly property bool isIdle: _state === "idle"
  readonly property bool isStale: !Settings.isStateLoaded || checkError !== "" || lastSuccessfulCheck <= 0 || Date.now() - lastSuccessfulCheck > _pollInterval
  readonly property bool isUpdating: _state === "updating"
  readonly property double lastSuccessfulCheck: Settings.isStateLoaded ? Settings.state.updates.lastSuccessfulCheck : 0
  property var outputLines: []
  property bool progressDeterminate: false
  readonly property bool ready: MainService.isArchBased && _checkUpdatesAvailable && Settings.isStateLoaded
  property bool rebootRequired: false
  readonly property int totalDownloadSize: updatePackages.reduce((totalSize, packageInfo) => totalSize + (_packageSizes[packageInfo.name] ?? 0), 0)
  property int totalPackagesToUpdate: 0
  readonly property int totalUpdates: updatePackages.length
  property double updateDurationMs: 0
  readonly property var updatePackages: _hasPackageCache ? Settings.state.updates.packages : []
  property double updateStartedAt: 0
  property int warningCount: 0

  function _detectErrorMessage(lineText: string): string {
    const normalizedLine = lineText.toLowerCase();
    if (["failed retrieving", "download timeout", "connection refused", "could not resolve host"].some(messagePart => normalizedLine.includes(messagePart)))
      return "Network error: Failed to download packages";
    if (normalizedLine.includes("not enough free disk space"))
      return "Insufficient disk space";
    if (["authentication failure", "incorrect password"].some(messagePart => normalizedLine.includes(messagePart)))
      return "Authentication failed";
    return "";
  }
  function _fetchPackageSizes(packages: var): void {
    const packageNames = packages.map(packageInfo => packageInfo.name).filter(Boolean);
    if (!packageNames.length) {
      _packageSizes = {};
      return;
    }
    const packageNamesKey = packageNames.join("\n");
    Command.run(["expac", "-S", "%k|%n"].concat(packageNames), result => {
      const currentKey = root.updatePackages.map(packageInfo => packageInfo.name).filter(Boolean).join("\n");
      if (currentKey === packageNamesKey)
        root._packageSizes = root._parsePackageSizes(result.stdout ?? "");
    });
  }
  function _finishUpdate(exitCode: int): void {
    _state = exitCode === 0 ? "completed" : "error";
    updateDurationMs = updateStartedAt > 0 ? Date.now() - updateStartedAt : 0;
    completedPackageCount = currentPackageIndex || totalPackagesToUpdate;
    if (exitCode === 0) {
      Logger.log("UpdateService", `Updates completed (${completedPackageCount}): ${updatePackages.map(packageInfo => packageInfo.name).join(", ")}`);
      const packageMessage = completedPackageCount === 1 ? "1 system package updated" : `${completedPackageCount} system packages updated`;
      _notify("Update Complete", completedPackageCount === 0 ? "Developer tooling update completed" : `${packageMessage}; developer tooling completed`);
    } else {
      if (!errorMessage)
        errorMessage = exitCode < 0 ? "Failed to start the update command" : `Update failed with code ${exitCode}`;
      _notify("Update Failed", errorMessage, "critical");
    }
    Qt.callLater(root.doPoll);
  }
  function _handleUpdateExit(exitCode: int): void {
    _updateProcessStarted = false;
    _finishUpdate(exitCode);
  }
  function _launchPendingActionNotification(): void {
    if (!_pendingActionArgs || actionNotifyProcess.running)
      return;
    const launchArgs = _pendingActionArgs;
    _pendingActionArgs = null;
    actionNotifyProcess.command = ["notify-send"].concat(launchArgs);
    actionNotifyProcess.running = true;
  }
  function _notify(title: string, message: string, urgency = "normal", actionable = false): void {
    Logger.log("UpdateService", `Sending notification: ${title} - ${message}`);
    const baseArgs = ["-u", urgency, "-a", _notificationAppName, "-n", "system-software-update"];
    // --wait keeps stdout open so the clicked action can be read.
    if (actionable) {
      _showActionNotification(baseArgs.concat("--print-id", "--replace-id", "8001", "--wait", "-A", `${_runUpdatesAction}=${qsTr("Run updates")}`, title, message));
      return;
    }
    Command.detached(["notify-send"].concat(baseArgs, "--replace-id", "8002", title, message));
  }
  function _notifyIfIncreased(packages: var): void {
    if (!ready || packages.length === 0) {
      Settings.state.updates.notifiedPackagesKey = "";
      return;
    }
    const packageNames = packages.map(packageInfo => packageInfo.name).filter(Boolean).sort();
    const previousKey = Settings.state.updates.notifiedPackagesKey;
    const previousNames = new Set(previousKey ? previousKey.split("\n") : []);
    const newPackageCount = packageNames.filter(packageName => !previousNames.has(packageName)).length;
    Settings.state.updates.notifiedPackagesKey = packageNames.join("\n");
    if (newPackageCount === 0)
      return;
    const notificationMessage = newPackageCount === 1 ? `${qsTr("One new package can be upgraded")} (${packages.length})` : `${newPackageCount} ${qsTr("new packages can be upgraded")} (${packages.length})`;
    _notify(qsTr("Updates Available"), notificationMessage, "normal", true);
  }
  function _parsePackageSizes(outputText: string): var {
    return (outputText ?? "").trim().split("\n").reduce((sizeMap, outputLine) => {
      const [sizeInBytes, packageName] = outputLine.split("|");
      const sizeValue = parseFloat(sizeInBytes);
      if (packageName && isFinite(sizeValue))
        sizeMap[packageName] = Math.round(sizeValue / 1024);
      return sizeMap;
    }, {});
  }
  function _parseUpdatePackages(outputText: string): var {
    const packagePattern = /^(\S+)\s+([^\s]+)\s+->\s+([^\s]+)$/;
    return (outputText ?? "").trim().split(/\r?\n/).reduce((packageList, outputLine) => {
      const packageMatch = outputLine.match(packagePattern);
      if (packageMatch) {
        packageList.push({
          name: packageMatch[1],
          oldVersion: packageMatch[2],
          newVersion: packageMatch[3]
        });
      }
      return packageList;
    }, []);
  }
  function _recordFailure(sourceName: string, message: string, exitCode: int): void {
    Logger.warn("UpdateService", `${sourceName} error (code: ${exitCode}): ${message}`);
    _failureCount += 1;
    if (_failureCount < 5)
      return;
    _notify(qsTr("Update check failed"), message, "critical");
    _failureCount = 0;
  }
  function _resetUpdateProgress(): void {
    completedPackageCount = 0;
    currentPackageIndex = 0;
    currentPackage = "";
    currentStep = "";
    errorMessage = "";
    outputLines = [];
    progressDeterminate = false;
    rebootRequired = false;
    totalPackagesToUpdate = 0;
    updateDurationMs = 0;
    updateStartedAt = 0;
    warningCount = 0;
  }
  function _showActionNotification(args: var): void {
    NotificationService.dismissNotificationsByAppName(_notificationAppName);
    _pendingActionArgs = args;
    if (actionNotifyProcess.running)
      actionNotifyProcess.running = false;
    else
      _launchPendingActionNotification();
  }
  function dismissResult(): void {
    if (isUpdating)
      return;
    _state = "idle";
    _resetUpdateProgress();
    _pendingActionArgs = null;
    if (actionNotifyProcess.running)
      actionNotifyProcess.running = false;
    NotificationService.dismissNotificationsByAppName(_notificationAppName);
  }
  function doPoll(): void {
    if (!ready || busy)
      return;
    _checking = true;
    Command.run(["checkupdates", "--nocolor"], result => {
      root._checking = false;
      if (result.exitCode === 0 || result.exitCode === 2) {
        const packages = root._parseUpdatePackages(result.stdout);
        root._failureCount = 0;
        Settings.state.updates.lastCheckError = "";
        Settings.state.updates.lastSuccessfulCheck = Date.now();
        Settings.state.updates.packages = packages;
        root._notifyIfIncreased(packages);
      } else {
        const message = (result.stderr || "").trim() || `Exit code: ${result.exitCode}`;
        Settings.state.updates.lastCheckError = message;
        root._recordFailure("checkupdates", message, result.exitCode);
      }
    }, "update.check");
  }
  function executeUpdate(): void {
    if (!ready || busy)
      return;
    _pendingActionArgs = null;
    NotificationService.dismissNotificationsByAppName(_notificationAppName);
    _resetUpdateProgress();
    totalPackagesToUpdate = totalUpdates;
    _updateProcessStarted = false;
    updateStartedAt = Date.now();
    _state = "updating";
    updateProcess.command = ["update"];
    updateProcess.running = true;
  }

  Component.onCompleted: {
    Command.run(["sh", "-c", "command -v checkupdates"], result => root._checkUpdatesAvailable = result.exitCode === 0);
  }
  onReadyChanged: {
    if (ready)
      _fetchPackageSizes(updatePackages);
  }
  onUpdatePackagesChanged: if (ready)
    _fetchPackageSizes(updatePackages)

  Process {
    id: updateProcess

    function appendOutputLine(lineText: string): void {
      const cleanLine = String(lineText ?? "").replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "").replace(/\r$/, "");
      root.outputLines = root.outputLines.slice(-299).concat(cleanLine);
      const stepMatch = cleanLine.trim().match(/^▶\s+(.+)$/);
      if (stepMatch) {
        root.currentStep = stepMatch[1];
        root.currentPackage = "";
        root.progressDeterminate = false;
      }
      const normalized = cleanLine.toLowerCase();
      const detectedMessage = root._detectErrorMessage(cleanLine);
      if (detectedMessage && !root.errorMessage)
        root.errorMessage = detectedMessage;
      if (normalized.includes("warning"))
        root.warningCount++;
      if (/^(?:==>\s+|⚠\s+)?Reboot (?:required due to:|is recommended after system updates\.)/.test(cleanLine.trim()))
        root.rebootRequired = true;
      const failureMatch = cleanLine.trim().match(/^\[FAIL\]\s+(.+)$/);
      if (failureMatch && !root.errorMessage)
        root.errorMessage = `${failureMatch[1]} update failed`;
      const progressMatch = cleanLine.trim().match(/^\(\s*(\d+)\/(\d+)\)\s+(?:installing|upgrading)\s+(\S+)/i);
      if (root.currentStep.startsWith("System Packages") && progressMatch) {
        root.totalPackagesToUpdate = Number(progressMatch[2]);
        root.currentPackageIndex = Math.min(Number(progressMatch[1]), root.totalPackagesToUpdate);
        root.currentPackage = progressMatch[3];
        root.progressDeterminate = true;
      }
    }

    stderr: SplitParser {
      onRead: data => updateProcess.appendOutputLine(data)
    }
    stdout: SplitParser {
      onRead: data => {
        updateProcess.appendOutputLine(data);
      }
    }

    onExited: exitCode => root._handleUpdateExit(exitCode)
    onRunningChanged: {
      if (!running && root.isUpdating && !root._updateProcessStarted)
        root._finishUpdate(-1);
    }
    onStarted: root._updateProcessStarted = true
  }
  Timer {
    id: pollTimer

    interval: root._pollTimerInterval
    repeat: true
    running: root.ready && !root.busy

    onTriggered: {
      interval = root._pollInterval;
      root.doPoll();
    }
  }
  Process {
    id: actionNotifyProcess

    stdout: StdioCollector {
      onStreamFinished: {
        if ((text || "").trim().split(/\s+/).includes(root._runUpdatesAction))
          root.executeUpdate();
      }
    }

    onExited: Qt.callLater(root._launchPendingActionNotification)
  }
}
