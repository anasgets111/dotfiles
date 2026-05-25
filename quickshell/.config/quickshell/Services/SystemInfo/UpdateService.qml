pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: root

  property var _notifyQueue: []
  property string _pendingNotifyAction: ""
  property string _runningAction: ""
  readonly property bool busy: checkUpdatesProcess.running || updateState === status.Updating
  property bool checkUpdatesAvailable: false
  property int currentPackageIndex: 0
  property string currentPackageName: ""
  property string errorMessage: ""
  property int failureCount: 0
  readonly property int failureThreshold: 5
  property int lastNotifiedTotal: 0
  property double lastSync: 0
  readonly property string notificationAppName: "System Updates"
  property var outputLines: []
  property var packageSizes: ({})
  readonly property int pollInterval: 15 * 60 * 1000
  readonly property bool ready: MainService.isArchBased && checkUpdatesAvailable
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
    try {
      const cachedPackages = JSON.parse(updatesState.cachedUpdatePackagesJson || "[]");
      updatePackages = Array.isArray(cachedPackages) ? cachedPackages : [];
    } catch (error) {
      Logger.warn("UpdateService", `Failed to load cached updates: ${error}`);
      updatePackages = [];
    }
  }

  function _notify(title: string, message: string, urgency = "normal", actionName = ""): void {
    Logger.log("UpdateService", `Sending notification: ${title} - ${message}`);
    if (actionName === runUpdatesAction) {
      _notifyQueue = _notifyQueue.filter(notificationJob => notificationJob.action !== actionName);
      NotificationService.dismissNotificationsByAppName(notificationAppName);
    }
    const notifyArgs = ["-u", urgency, "-a", notificationAppName, "-n", "system-software-update", "--print-id", "--replace-id", String(actionName === runUpdatesAction ? 8001 : 8002)];
    if (actionName)
      notifyArgs.push("-A", `${actionName}=${qsTr("Run updates")}`);
    _notifyQueue.push({
      action: actionName,
      args: notifyArgs.concat(title, message)
    });
    _processNotifyQueue();
  }

  function _notifyIfIncreased(): void {
    if (!ready || totalUpdates === 0) {
      lastNotifiedTotal = 0;
      return;
    }
    if (totalUpdates <= lastNotifiedTotal)
      return;
    const newPackageCount = totalUpdates - lastNotifiedTotal;
    const notificationMessage = newPackageCount === 1 ? `${qsTr("One new package can be upgraded")} (${totalUpdates})` : `${newPackageCount} ${qsTr("new packages can be upgraded")} (${totalUpdates})`;
    _notify(qsTr("Updates Available"), notificationMessage, "normal", runUpdatesAction);
    lastNotifiedTotal = totalUpdates;
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
    if (notificationProcess.running || !_notifyQueue.length)
      return;
    const notificationJob = _notifyQueue.shift();
    _pendingNotifyAction = notificationJob.action;
    _runningAction = notificationJob.action;
    notificationProcess.command = ["notify-send"].concat(notificationJob.args);
    notificationProcess.running = true;
  }

  function _recordFailure(sourceName: string, message: string, exitCode: int): void {
    Logger.warn("UpdateService", `${sourceName} error (code: ${exitCode}): ${message}`);
    failureCount += 1;
    if (failureCount < failureThreshold)
      return;
    _notify(qsTr("Update check failed"), message, "critical");
    failureCount = 0;
  }

  function _resetNotificationState(): void {
    _pendingNotifyAction = "";
    _runningAction = "";
  }

  function _resetUpdateProgress(): void {
    currentPackageIndex = 0;
    currentPackageName = "";
    errorMessage = "";
    outputLines = [];
  }

  function cancelUpdate(): void {
    if (updateProcess.running)
      updateProcess.running = false;
    updateState = status.Idle;
    _resetUpdateProgress();
  }

  function doPoll(): void {
    if (!ready || busy)
      return;
    checkUpdatesProcess.command = ["checkupdates", "--nocolor"];
    checkUpdatesProcess.running = true;
  }

  function executeUpdate(): void {
    if (totalUpdates === 0 || updateState === status.Updating)
      return;
    NotificationService.dismissNotificationsByAppName(notificationAppName);
    totalPackagesToUpdate = totalUpdates;
    _resetUpdateProgress();
    updateState = status.Updating;
    updateProcess.command = ["update"];
    updateProcess.running = true;
  }

  function fetchPackageSizes(): void {
    if (!updatePackages.length || sizeFetchProcess.running)
      return;
    sizeFetchProcess.command = ["expac", "-S", "%k|%n"].concat(updatePackages.map(packageInfo => packageInfo.name));
    sizeFetchProcess.running = true;
  }

  Component.onCompleted: if (Settings.isStateLoaded)
    _init()
  Component.onDestruction: pollTimer.stop()
  onLastSyncChanged: if (Settings.isStateLoaded)
    Settings.state.updates.lastSync = lastSync
  onReadyChanged: {
    if (ready) {
      doPoll();
      pollTimer.start();
    } else {
      pollTimer.stop();
    }
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
    id: checkUpdatesProbe

    command: ["sh", "-c", "command -v checkupdates >/dev/null && echo yes || echo no"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: root.checkUpdatesAvailable = (text ?? "").trim() === "yes"
    }
  }

  Process {
    id: sizeFetchProcess

    stdout: StdioCollector {
      onStreamFinished: root.packageSizes = Object.assign({}, root.packageSizes, root._parsePackageSizes(text ?? ""))
    }
  }

  Process {
    id: checkUpdatesProcess

    property string _stderrText: ""
    property string _stdoutText: ""

    stderr: StdioCollector {
      onStreamFinished: checkUpdatesProcess._stderrText = (text ?? "").trim()
    }
    stdout: StdioCollector {
      onStreamFinished: checkUpdatesProcess._stdoutText = text ?? ""
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0 || exitCode === 2) {
        const packages = root._parseUpdatePackages(checkUpdatesProcess._stdoutText);
        root.failureCount = 0;
        root.updatePackages = packages;
        root.lastSync = Date.now();
        root._notifyIfIncreased();
        if (packages.length > 0)
          root.fetchPackageSizes();
      } else {
        root._recordFailure("checkupdates", checkUpdatesProcess._stderrText || `Exit code: ${exitCode}`, exitCode);
      }
      checkUpdatesProcess._stderrText = "";
      checkUpdatesProcess._stdoutText = "";
    }
  }

  Process {
    id: updateProcess

    function appendOutputLine(lineText: string, isErrorLine = false): void {
      const trimmedLine = lineText.trim();
      if (!trimmedLine)
        return;
      root.outputLines = root.outputLines.concat({
        text: trimmedLine,
        type: isErrorLine ? "error" : "info"
      });
      const progressMatch = trimmedLine.match(/(?:installing|upgrading)\s+(\S+)/i);
      if (progressMatch) {
        root.currentPackageIndex += 1;
        root.currentPackageName = progressMatch[1];
      }
    }

    stderr: SplitParser {
      onRead: data => {
        const lineText = data.trim();
        if (!lineText)
          return;
        updateProcess.appendOutputLine(lineText, true);
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
        const normalizedLine = lineText.toLowerCase();
        updateProcess.appendOutputLine(lineText, normalizedLine.includes("error:") || normalizedLine.includes("failed"));
      }
    }

    onExited: (exitCode, exitStatus) => {
      root.updateState = exitCode === 0 ? root.status.Completed : root.status.Error;
      if (exitCode === 0) {
        const completedPackageCount = root.totalPackagesToUpdate || root.updatePackages.length;
        Logger.log("UpdateService", `Updates completed (${completedPackageCount}): ${root.updatePackages.map(packageInfo => packageInfo.name).join(", ")}`);
        root._notify("Update Complete", completedPackageCount === 1 ? "1 package updated successfully" : `${completedPackageCount} packages updated successfully`);
        root.doPoll();
      } else {
        if (!root.errorMessage)
          root.errorMessage = `Update failed with code ${exitCode}`;
        root._notify("Update Failed", root.errorMessage, "critical");
      }
    }
  }

  Timer {
    id: pollTimer

    interval: root.pollInterval
    repeat: true

    onTriggered: root.doPoll()
  }

  Process {
    id: notificationProcess

    stdout: StdioCollector {
      onStreamFinished: {
        const outputLines = (text || "").trim().split("\n");
        const actionName = root._pendingNotifyAction;
        if (actionName && outputLines.some(outputLine => outputLine.trim().split(/\s+/).includes(actionName)))
          root.executeUpdate();
        root._resetNotificationState();
        root._processNotifyQueue();
      }
    }

    onRunningChanged: {
      if (!running)
        root._processNotifyQueue();
    }
  }
}
