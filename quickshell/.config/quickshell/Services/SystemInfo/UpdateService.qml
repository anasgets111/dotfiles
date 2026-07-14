pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services
import qs.Services.Utils

Singleton {
  id: root

  property bool _cancelCommandDone: false
  property int _cancelledUpdateExitCode: -1
  property bool _cancellingUpdate: false
  property bool _checkUpdatesAvailable: false
  property bool _checking: false
  property int _failureCount: 0
  readonly property int _failureThreshold: 5
  readonly property bool _hasPackageCache: Settings.isStateLoaded && Array.isArray(Settings.state.updates.packages)
  readonly property double _lastSync: Settings.isStateLoaded ? Settings.state.updates.lastSync : 0
  readonly property string _notificationAppName: "System Updates"
  property var _pendingActionArgs: null
  readonly property int _pollInterval: 15 * 60 * 1000
  readonly property int _pollTimerInterval: _hasPackageCache && _lastSync > 0 ? Math.max(1, _pollInterval - Math.max(0, Date.now() - _lastSync)) : 1
  property var _packageSizes: ({})
  readonly property string _runUpdatesAction: "run-updates"
  property string _state: "idle"
  property bool _updateProcessStarted: false

  readonly property bool busy: _checking || updateProcess.running || cancelProcess.running || isUpdating
  property int currentPackageIndex: 0
  property string currentStep: ""
  property string errorMessage: ""
  readonly property bool isError: _state === "error"
  readonly property bool isIdle: _state === "idle"
  readonly property bool isSystemPackageStep: currentStep.startsWith("System Packages")
  readonly property bool isUpdating: _state === "updating"
  property var outputLines: []
  readonly property bool ready: MainService.isArchBased && _checkUpdatesAvailable && Settings.isStateLoaded
  readonly property int totalDownloadSize: updatePackages.reduce((totalSize, packageInfo) => totalSize + (_packageSizes[packageInfo.name] ?? 0), 0)
  property int totalPackagesToUpdate: 0
  readonly property int totalUpdates: updatePackages.length
  readonly property var updatePackages: _hasPackageCache ? Settings.state.updates.packages : []

  function _completionMessage(packageCount: int): string {
    if (packageCount === 0)
      return "Developer tooling update completed";
    const packageMessage = packageCount === 1 ? "1 system package updated" : `${packageCount} system packages updated`;
    return `${packageMessage}; developer tooling completed`;
  }

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
    if (_failureCount < _failureThreshold)
      return;
    _notify(qsTr("Update check failed"), message, "critical");
    _failureCount = 0;
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

  function _resetUpdateProgress(): void {
    currentPackageIndex = 0;
    currentStep = "";
    errorMessage = "";
    outputLines = [];
    totalPackagesToUpdate = 0;
  }

  function _showActionNotification(args: var): void {
    NotificationService.dismissNotificationsByAppName(_notificationAppName);
    _pendingActionArgs = args;
    if (actionNotifyProcess.running)
      actionNotifyProcess.running = false;
    else
      _launchPendingActionNotification();
  }

  function _completeCancellation(): void {
    if (!_cancelCommandDone || updateProcess.running)
      return;
    _cancelCommandDone = false;
    _cancelledUpdateExitCode = -1;
    _cancellingUpdate = false;
    _state = "idle";
    _resetUpdateProgress();
    doPoll();
  }

  function _finishUpdate(exitCode: int): void {
    _state = exitCode === 0 ? "completed" : "error";
    if (exitCode === 0) {
      const completedPackageCount = totalPackagesToUpdate || updatePackages.length;
      Logger.log("UpdateService", `Updates completed (${completedPackageCount}): ${updatePackages.map(packageInfo => packageInfo.name).join(", ")}`);
      _notify("Update Complete", _completionMessage(completedPackageCount));
    } else {
      if (!errorMessage)
        errorMessage = exitCode < 0 ? "Failed to start the update command" : `Update failed with code ${exitCode}`;
      _notify("Update Failed", errorMessage, "critical");
    }
    Qt.callLater(root.doPoll);
  }

  function _handleCancelExit(exitCode: int): void {
    _cancelCommandDone = true;
    if (exitCode === 0) {
      _completeCancellation();
      return;
    }

    _cancelCommandDone = false;
    _cancellingUpdate = false;
    errorMessage = "Failed to cancel the update safely";
    outputLines = outputLines.concat(errorMessage);
    Logger.error("UpdateService", `${errorMessage} (code: ${exitCode})`);
    if (!updateProcess.running)
      _finishUpdate(_cancelledUpdateExitCode >= 0 ? _cancelledUpdateExitCode : exitCode);
  }

  function _handleUpdateExit(exitCode: int): void {
    _updateProcessStarted = false;
    if (_cancellingUpdate) {
      _cancelledUpdateExitCode = exitCode;
      _completeCancellation();
      return;
    }
    _finishUpdate(exitCode);
  }

  function doPoll(): void {
    if (!ready || busy)
      return;
    Settings.state.updates.lastSync = Date.now();
    _checking = true;
    Command.run(["checkupdates", "--nocolor"], result => {
      root._checking = false;
      if (!root.isError)
        root._state = "idle";
      if (result.exitCode === 0 || result.exitCode === 2) {
        const packages = root._parseUpdatePackages(result.stdout);
        root._failureCount = 0;
        Settings.state.updates.packages = packages;
        root._notifyIfIncreased(packages);
      } else {
        root._recordFailure("checkupdates", (result.stderr || "").trim() || `Exit code: ${result.exitCode}`, result.exitCode);
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
    _state = "updating";
    updateProcess.command = ["update"];
    updateProcess.running = true;
  }

  function cancelUpdate(): void {
    if (_cancellingUpdate || cancelProcess.running)
      return;
    if (!updateProcess.running) {
      _state = "idle";
      _resetUpdateProgress();
      return;
    }
    if (!_updateProcessStarted) {
      _cancellingUpdate = true;
      _cancelCommandDone = true;
      updateProcess.running = false;
      Qt.callLater(root._completeCancellation);
      return;
    }
    _cancellingUpdate = true;
    _cancelCommandDone = false;
    _cancelledUpdateExitCode = -1;
    outputLines = outputLines.concat(qsTr("Cancelling update safely..."));
    cancelProcess.command = ["update", "--cancel"];
    cancelProcess.running = true;
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
      const trimmedLine = lineText.trim();
      if (!trimmedLine)
        return;
      root.outputLines = root.outputLines.concat(trimmedLine);
      const stepMatch = trimmedLine.match(/^▶\s+(.+)$/);
      if (stepMatch)
        root.currentStep = stepMatch[1];
      const failureMatch = trimmedLine.match(/^\[FAIL\]\s+(.+)$/);
      if (failureMatch && !root.errorMessage)
        root.errorMessage = `${failureMatch[1]} update failed`;
      const progressMatch = trimmedLine.match(/^\(\s*(\d+)\/\d+\)\s+(?:installing|upgrading)\s+/i);
      if (root.isSystemPackageStep && progressMatch)
        root.currentPackageIndex = Math.min(Number(progressMatch[1]), root.totalPackagesToUpdate);
    }

    stderr: SplitParser {
      onRead: data => {
        const lineText = data.trim();
        if (!lineText)
          return;
        updateProcess.appendOutputLine(lineText);
        const detectedMessage = root._detectErrorMessage(lineText);
        if (detectedMessage && !root.errorMessage)
          root.errorMessage = detectedMessage;
      }
    }
    stdout: SplitParser {
      onRead: data => {
        const lineText = data.trim();
        if (!lineText)
          return;
        updateProcess.appendOutputLine(lineText);
      }
    }

    onRunningChanged: {
      if (!running && root.isUpdating && !root._updateProcessStarted && !root._cancellingUpdate)
        root._finishUpdate(-1);
    }
    onStarted: root._updateProcessStarted = true
    onExited: exitCode => root._handleUpdateExit(exitCode)
  }

  Process {
    id: cancelProcess

    property bool _started: false

    stderr: SplitParser {
      onRead: data => updateProcess.appendOutputLine(data)
    }
    stdout: SplitParser {
      onRead: data => updateProcess.appendOutputLine(data)
    }

    onRunningChanged: {
      if (!running && root._cancellingUpdate && !_started)
        root._handleCancelExit(-1);
    }
    onStarted: _started = true
    onExited: exitCode => {
      _started = false;
      root._handleCancelExit(exitCode);
    }
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
