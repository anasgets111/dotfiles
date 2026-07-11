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
  property bool _checking: false
  property var _notifyQueue: []
  property bool _notifying: false
  property var _pendingActionArgs: null
  property bool _updateProcessStarted: false
  readonly property bool busy: _checking || updateProcess.running || cancelProcess.running || updateState === status.Updating
  property bool checkUpdatesAvailable: false
  property int currentPackageIndex: 0
  property string errorMessage: ""
  property int failureCount: 0
  readonly property int failureThreshold: 5
  property string lastNotifiedPackageNamesKey: ""
  property double lastSync: 0
  readonly property string notificationAppName: "System Updates"
  property var outputLines: []
  property var packageSizes: ({})
  readonly property int pollInterval: 15 * 60 * 1000
  readonly property int pollTimerInterval: lastSync > 0 ? Math.max(1, pollInterval - Math.max(0, Date.now() - lastSync)) : 1
  readonly property bool ready: MainService.isArchBased && checkUpdatesAvailable && Settings.isStateLoaded
  readonly property string runUpdatesAction: "run-updates"
  readonly property var status: Object.freeze({
    Idle: 0,
    Updating: 1,
    Completed: 2,
    Error: 3
  })
  readonly property int totalDownloadSize: updatePackages.reduce((totalSize, packageInfo) => totalSize + (packageSizes[packageInfo.name] ?? 0), 0)
  property int totalPackagesToUpdate: 0
  readonly property int totalUpdates: updatePackages.length
  property var updatePackages: []
  property int updateState: status.Idle

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

  function _init(): void {
    if (!Settings.isStateLoaded)
      return;
    const updatesState = Settings.state.updates;
    lastSync = updatesState.lastSync || 0;
    lastNotifiedPackageNamesKey = updatesState.notifiedPackagesKey || "";
    try {
      const cachedPackages = JSON.parse(updatesState.cachedUpdatePackagesJson || "[]");
      updatePackages = Array.isArray(cachedPackages) ? cachedPackages : [];
    } catch (error) {
      Logger.warn("UpdateService", `Failed to load cached updates: ${error}`);
      updatePackages = [];
    }
  }

  function _launchPendingActionNotification(): void {
    if (!_pendingActionArgs || actionNotifyProcess.running)
      return;
    const launchArgs = _pendingActionArgs;
    _pendingActionArgs = null;
    actionNotifyProcess.command = ["notify-send"].concat(launchArgs);
    actionNotifyProcess.running = true;
  }

  function _notify(title: string, message: string, urgency = "normal", actionName = ""): void {
    Logger.log("UpdateService", `Sending notification: ${title} - ${message}`);
    const baseArgs = ["-u", urgency, "-a", notificationAppName, "-n", "system-software-update"];
    // The "Run updates" prompt needs notify-send --wait to detect the action click, which
    // keeps its process alive until the notification is closed. It runs on its own process
    // so it never blocks the fire-and-forget queue below.
    if (actionName === runUpdatesAction) {
      _showActionNotification(baseArgs.concat("--print-id", "--replace-id", "8001", "--wait", "-A", `${actionName}=${qsTr("Run updates")}`, title, message));
      return;
    }
    _notifyQueue.push(baseArgs.concat("--replace-id", "8002", title, message));
    _processNotifyQueue();
  }

  function _notifyIfIncreased(): void {
    if (!ready || totalUpdates === 0) {
      lastNotifiedPackageNamesKey = "";
      return;
    }
    const packageNames = updatePackages.map(packageInfo => packageInfo.name).filter(Boolean).sort();
    const previousNames = new Set(lastNotifiedPackageNamesKey ? lastNotifiedPackageNamesKey.split("\n") : []);
    const newPackageCount = packageNames.filter(packageName => !previousNames.has(packageName)).length;
    lastNotifiedPackageNamesKey = packageNames.join("\n");
    if (newPackageCount === 0)
      return;
    const notificationMessage = newPackageCount === 1 ? `${qsTr("One new package can be upgraded")} (${totalUpdates})` : `${newPackageCount} ${qsTr("new packages can be upgraded")} (${totalUpdates})`;
    _notify(qsTr("Updates Available"), notificationMessage, "normal", runUpdatesAction);
  }

  function _parsePackageSizes(outputText: string): var {
    return (outputText ?? "").trim().split("\n").reduce((sizeMap, outputLine) => {
      const [sizeInKiB, packageName] = outputLine.split("|");
      const sizeValue = parseFloat(sizeInKiB);
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

  function _processNotifyQueue(): void {
    if (_notifying || !_notifyQueue.length)
      return;
    _notifying = true;
    Command.run(["notify-send"].concat(_notifyQueue.shift()), () => {
      root._notifying = false;
      root._processNotifyQueue();
    });
  }

  function _recordFailure(sourceName: string, message: string, exitCode: int): void {
    Logger.warn("UpdateService", `${sourceName} error (code: ${exitCode}): ${message}`);
    failureCount += 1;
    if (failureCount < failureThreshold)
      return;
    _notify(qsTr("Update check failed"), message, "critical");
    failureCount = 0;
  }

  function _resetUpdateProgress(): void {
    currentPackageIndex = 0;
    errorMessage = "";
    outputLines = [];
  }

  function _showActionNotification(args: var): void {
    NotificationService.dismissNotificationsByAppName(notificationAppName);
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
    updateState = status.Idle;
    _resetUpdateProgress();
    doPoll();
  }

  function _finishUpdate(exitCode: int): void {
    updateState = exitCode === 0 ? status.Completed : status.Error;
    if (exitCode === 0) {
      const completedPackageCount = totalPackagesToUpdate || updatePackages.length;
      Logger.log("UpdateService", `Updates completed (${completedPackageCount}): ${updatePackages.map(packageInfo => packageInfo.name).join(", ")}`);
      _notify("Update Complete", completedPackageCount === 1 ? "1 package updated successfully" : `${completedPackageCount} packages updated successfully`);
    } else {
      if (!errorMessage)
        errorMessage = exitCode < 0 ? "Failed to start the update command" : `Update failed with code ${exitCode}`;
      _notify("Update Failed", errorMessage, "critical");
    }
    doPoll();
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

  function cancelUpdate(): void {
    if (_cancellingUpdate || cancelProcess.running)
      return;
    if (!updateProcess.running) {
      updateState = status.Idle;
      _resetUpdateProgress();
      return;
    }
    if (!_updateProcessStarted || updateProcess.processId <= 0) {
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
    cancelProcess.command = ["update", "--cancel", String(updateProcess.processId)];
    cancelProcess.running = true;
  }

  function closeAllNotifications(): void {
    _notifyQueue = [];
    _pendingActionArgs = null;
    if (actionNotifyProcess.running)
      actionNotifyProcess.running = false;
    NotificationService.dismissNotificationsByAppName(notificationAppName);
  }

  function doPoll(): void {
    if (!ready || busy)
      return;
    lastSync = Date.now();
    _checking = true;
    Command.run(["checkupdates", "--nocolor"], result => {
      root._checking = false;
      if (root.updateState !== root.status.Error)
        root.updateState = root.status.Idle;
      if (result.exitCode === 0 || result.exitCode === 2) {
        const packages = root._parseUpdatePackages(result.stdout);
        root.failureCount = 0;
        root.updatePackages = packages;
        root._notifyIfIncreased();
        if (packages.length > 0)
          root.fetchPackageSizes();
      } else {
        root._recordFailure("checkupdates", (result.stderr || "").trim() || `Exit code: ${result.exitCode}`, result.exitCode);
      }
    }, "update.check");
  }

  function executeUpdate(): void {
    if (!ready || totalUpdates === 0 || busy)
      return;
    _pendingActionArgs = null;
    NotificationService.dismissNotificationsByAppName(notificationAppName);
    totalPackagesToUpdate = totalUpdates;
    _resetUpdateProgress();
    _updateProcessStarted = false;
    updateState = status.Updating;
    updateProcess.command = ["setsid", "update"];
    updateProcess.running = true;
  }

  function fetchPackageSizes(): void {
    if (!updatePackages.length)
      return;
    Command.run(["expac", "-S", "%k|%n"].concat(updatePackages.map(packageInfo => packageInfo.name)), result => root.packageSizes = Object.assign({}, root.packageSizes, root._parsePackageSizes(result.stdout ?? "")), "update.size");
  }

  Component.onCompleted: {
    Command.run(["sh", "-c", "command -v checkupdates >/dev/null && echo yes || echo no"], result => root.checkUpdatesAvailable = (result.stdout ?? "").trim() === "yes");
    if (Settings.isStateLoaded)
      _init();
  }
  onLastNotifiedPackageNamesKeyChanged: if (Settings.isStateLoaded)
    Settings.state.updates.notifiedPackagesKey = lastNotifiedPackageNamesKey
  onLastSyncChanged: if (Settings.isStateLoaded)
    Settings.state.updates.lastSync = lastSync
  onReadyChanged: {
    if (!ready)
      return;
    if ((Date.now() - lastSync) > 60 * 1000)
      doPoll();
  }
  onUpdatePackagesChanged: if (Settings.isStateLoaded)
    Settings.state.updates.cachedUpdatePackagesJson = JSON.stringify(updatePackages)

  Connections {
    function onIsStateLoadedChanged(): void {
      if (Settings.isStateLoaded)
        root._init();
    }

    target: Settings
  }

  Process {
    id: updateProcess

    function appendOutputLine(lineText: string): void {
      const trimmedLine = lineText.trim();
      if (!trimmedLine)
        return;
      root.outputLines = root.outputLines.concat(trimmedLine);
      const progressMatch = trimmedLine.match(/(?:installing|upgrading)\s+(\S+)/i);
      if (progressMatch) {
        root.currentPackageIndex += 1;
      }
    }

    stderr: SplitParser {
      onRead: data => {
        const lineText = data.trim();
        if (!lineText)
          return;
        updateProcess.appendOutputLine(lineText);
        const detectedMessage = root._detectErrorMessage(lineText);
        if (detectedMessage)
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
      if (!running && root.updateState === root.status.Updating && !root._updateProcessStarted && !root._cancellingUpdate)
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

    interval: root.pollTimerInterval
    repeat: true
    running: root.ready && !root.busy

    onTriggered: {
      interval = root.pollInterval;
      root.doPoll();
    }
  }

  Process {
    id: actionNotifyProcess

    stdout: StdioCollector {
      onStreamFinished: {
        const outputLines = (text || "").trim().split("\n");
        if (outputLines.some(outputLine => outputLine.trim().split(/\s+/).includes(root.runUpdatesAction)))
          root.executeUpdate();
      }
    }

    onExited: Qt.callLater(root._launchPendingActionNotification)
  }
}
