pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services.Utils

Singleton {
  id: root

  property double _currentStartAt: 0
  property string currentDetails: ""
  property int currentLevel: levelInfo
  property string currentMessage: ""
  property int currentRepeatCount: 0
  property bool dedupe: true
  property bool doNotDisturb: false
  property int durationError: 5000
  property int durationErrorWithDetails: 8000
  property int durationInfo: 3000
  property int durationWarn: 4000
  readonly property bool hasDetails: root.currentDetails.length > 0
  readonly property int levelError: 2
  readonly property int levelInfo: 0
  readonly property int levelWarn: 1
  property int maxVisibleMs: 5000
  property bool replaceWhileVisible: true
  property var toastQueue: []
  property int toastQueueMax: 200
  property bool toastVisible: false
  property string wallpaperErrorStatus: ""

  signal resetToastState

  function _applyTimerFor(level, hasDetails) {
    let baseInterval = 0;
    if (level === levelError && hasDetails) {
      baseInterval = root.durationErrorWithDetails;
    } else if (level === levelError) {
      baseInterval = root.durationError;
    } else if (level === levelWarn) {
      baseInterval = root.durationWarn;
    } else {
      baseInterval = root.durationInfo;
    }
    const currentTime = Date.now();
    const remainingVisibleCap = (root.toastVisible && root._currentStartAt > 0) ? Math.max(0, root.maxVisibleMs - (currentTime - root._currentStartAt)) : -1;
    if (remainingVisibleCap === 0) {
      root.hideToast();
      return;
    }
    toastTimer.interval = remainingVisibleCap > 0 ? Math.min(baseInterval, remainingVisibleCap) : baseInterval;
    toastTimer.restart();
  }
  function _processQueue() {
    if (root.toastVisible)
      return;
    if (root.doNotDisturb)
      return;
    if (root.toastQueue.length === 0)
      return;
    const remainingQueue = root.toastQueue.slice();
    const nextToast = remainingQueue.shift();
    root.toastQueue = remainingQueue;
    root.currentMessage = nextToast.message;
    root.currentLevel = nextToast.level;
    root.currentDetails = nextToast.details || "";
    root.currentRepeatCount = nextToast.repeat || 0;
    root.toastVisible = true;
    root._currentStartAt = Date.now();
    root.resetToastState();
    root._applyTimerFor(nextToast.level, root.hasDetails);
    Logger.log("OSDService", `show: level=${root.currentLevel}, repeats=${root.currentRepeatCount}`);
  }
  function _restartTimerForCurrent() {
    root._applyTimerFor(root.currentLevel, root.hasDetails);
  }
  function clearQueue() {
    root.toastQueue = [];
  }
  function clearWallpaperError() {
    root.wallpaperErrorStatus = "";
  }
  function hideToast() {
    root.toastVisible = false;
    root.currentMessage = "";
    root.currentDetails = "";
    root.currentLevel = levelInfo;
    root.currentRepeatCount = 0;
    root._currentStartAt = 0;
    toastTimer.stop();
    root.resetToastState();
    if (!root.doNotDisturb)
      root._processQueue();
    Logger.log("OSDService", "hideToast");
  }
  function restartTimer() {
    root._restartTimerForCurrent();
  }
  function setDoNotDisturb(enabled) {
    const enabledBool = !!enabled;
    if (root.doNotDisturb === enabledBool)
      return;
    root.doNotDisturb = enabledBool;
    if (enabledBool) {
      // Hide immediately and stop timer
      toastTimer.stop();
      root.toastVisible = false;
      root.resetToastState();
    } else {
      root._processQueue();
    }
    Logger.log("OSDService", `DND=${root.doNotDisturb}`);
  }
  function showError(message, details = "") {
    showToast(message, levelError, details);
  }
  function showInfo(message, details = "") {
    showToast(message, levelInfo, details);
  }

  // TimeService provides wall-clock time; prefer it over ad-hoc Date.now

  function showToast(message, level = levelInfo, details = "") {
    if (message === null || message === undefined)
      return;
    const messageText = String(message);
    const detailText = (details === undefined || details === null) ? "" : String(details);
    Logger.log("OSDService", `showToast: level=${level}, msg='${messageText}'`);

    if (root.toastVisible && root.dedupe && messageText === root.currentMessage && level === root.currentLevel) {
      root.currentRepeatCount += 1;
      root._restartTimerForCurrent();
      return;
    }

    if (root.toastVisible && root.replaceWhileVisible && level >= root.currentLevel) {
      root.currentMessage = messageText;
      root.currentDetails = detailText;
      root.currentLevel = level;
      root._restartTimerForCurrent();
      return;
    }

    const queuedItem = {
      message: messageText,
      level: level,
      details: detailText,
      repeat: 0
    };

    if (root.dedupe && root.toastQueue.length > 0) {
      const lastQueuedToast = root.toastQueue[root.toastQueue.length - 1];
      if (lastQueuedToast && lastQueuedToast.message === messageText && lastQueuedToast.level === level) {
        const updatedQueue = root.toastQueue.slice();
        updatedQueue[updatedQueue.length - 1] = {
          message: lastQueuedToast.message,
          level: lastQueuedToast.level,
          details: lastQueuedToast.details,
          repeat: (lastQueuedToast.repeat || 0) + 1
        };
        root.toastQueue = updatedQueue;
        Logger.log("OSDService", `dedupe: bumped repeat to ${updatedQueue[updatedQueue.length - 1].repeat}`);
      } else {
        let q = root.toastQueue.concat([queuedItem]);
        if (q.length > root.toastQueueMax)
          q = q.slice(q.length - root.toastQueueMax);
        root.toastQueue = q;
        Logger.log("OSDService", `enqueued: level=${level}`);
      }
    } else {
      let q = root.toastQueue.concat([queuedItem]);
      if (q.length > root.toastQueueMax)
        q = q.slice(q.length - root.toastQueueMax);
      root.toastQueue = q;
      Logger.log("OSDService", `enqueued: level=${level}`);
    }

    if (!root.toastVisible && !root.doNotDisturb)
      root._processQueue();
  }
  function showWarning(message, details = "") {
    showToast(message, levelWarn, details);
  }
  function stopTimer() {
    toastTimer.stop();
  }

  Timer {
    id: toastTimer

    interval: 5000
    repeat: false
    running: false

    onTriggered: root.hideToast()
  }
}
