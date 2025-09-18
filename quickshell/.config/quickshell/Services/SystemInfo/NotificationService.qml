pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Config

// Notifications.qml — Singleton notification service
Singleton {
  id: notificationsService

  // ————— Runtime state —————
  // Internal ordered list of active notifications in arrival order.
  // The server owns lifetime for tracked notifications; we just keep references.
  property var __orderedActive: []            // Array<Notification>
  property string __pendingActionLogJson: "[]"
  property string __pendingHistoryJson: "[]"
  property string __pendingReplyLogJson: "[]"
  property bool __persistDirty: false
  // Tracks items hidden by policy: id -> "queue" | "suppress"
  property var __queuedOrSuppressed: ({})

  // Logs
  property var actionLog: [] // [{notificationId, actionId, at}]
  // Memory caps / persistence helpers
  property int actionLogCap: 500
  readonly property int activeCount: __orderedActive.length

  // Default timeouts and animation settings for consumers to use.
  readonly property real defaultExpireSecondsCritical: -1.0   // -1 means don't auto-dismiss
  readonly property real defaultExpireSecondsLow: 4.0
  readonly property real defaultExpireSecondsNormal: 6.0

  // DND and lightweight queue/suppress flags
  property var dndPolicy: ({
      enabled: false,
      schedule: [] // [{ days:[0-6], start:"22:00", end:"07:00" }]
      ,
      appRules: ({
          allow: [],
          deny: []
        }),
      urgency: ({
          bypassCritical: true,
          suppressLow: false
        }),
      behavior: "queue" // "suppress" | "queue"
    })
  readonly property int enterAnimationDurationMs: 160
  readonly property int exitAnimationDurationMs: 120
  readonly property int fadeAnimationDurationMs: 140
  property int groupChildrenCap: 50

  // Lightweight grouping
  property var groupsMap: ({})  // groupId -> { id, title, appName, children, updatedAt }

  // Local history snapshot model; each entry is a plain object snapshot to avoid dangling pointers.
  readonly property ListModel historyModel: ListModel {
    id: __historyModel

  }
  property int maxHistoryItems: 200

  // Visibility limit and model for popups.
  property int maxVisibleNotifications: 4
  readonly property int rearrangeAnimationDurationMs: 120
  property var replyLog: []  // [{notificationId, text, at}]

  property int replyLogCap: 300

  // ————— Capabilities advertised to clients (Desktop Notifications Spec) —————
  // These flags inform apps what the server can do; they are hints and do not prevent content.
  // See NotificationServer docs; by default most are false and should be enabled explicitly.
  readonly property NotificationServer server: NotificationServer {
    id: notificationServer

    actionIconsSupported: true
    actionsSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    bodyMarkupSupported: true

    // Capability hints
    bodySupported: true

    // Optional extra hints (can be extended by the user if needed)
    extraHints: []
    imageSupported: true
    inlineReplySupported: true

    // Persistence across reloads and notification re-emission.
    keepOnReload: true
    persistenceSupported: true

    onNotification: function (receivedNotification) {
      // Always track; then let service manage visibility and DND/queueing.
      receivedNotification.tracked = true;
      notificationsService.__wireNotificationLifecycle(receivedNotification);

      // Grouping touch
      notificationsService.__touchGroup(receivedNotification);

      // Evaluate DND and mark if needed
      const dndDecision = notificationsService.__evalDnd(receivedNotification);
      const notificationIdString = String(receivedNotification.id || "");
      if (dndDecision === "queue" || dndDecision === "suppress") {
        notificationsService.__queuedOrSuppressed[notificationIdString] = dndDecision;
      }
      if (dndDecision !== "suppress")
        notificationsService.__enqueueNotificationOrder(receivedNotification);
      notificationsService.__processQueue();
      notificationsService.__rebuildVisibleModel();
      notificationsService.notificationShown(receivedNotification);
    }
  }
  readonly property int slideDistancePx: 16

  // ————— Styling knobs for consumers —————
  // These are not enforced by the service; the UI should read them.
  property var style: ({
      cornerRadius: Theme.itemRadius                   // radius token from Theme
      ,
      borderWidth: 1                                   // keep simple width; Theme has colors
      ,
      spacing: Theme.panelMargin / 2                   // derive spacing from panel margin
      ,
      padding: Theme.panelMargin                       // align paddings with project margin
      ,
      fontFamily: Theme.fontFamily                     // unified font family
      ,
      summaryPointSize: Theme.fontSize                 // summary matches Theme.fontSize
      ,
      bodyPointSize: Math.max(10, Theme.fontSize - 1)  // body slightly smaller
      ,
      iconSize: Theme.iconSize                         // unified icon size
      ,
      actionHeight: Theme.itemHeight                   // control height aligns with items
      ,
      actionPadding: Math.max(8, Math.round(Theme.panelMargin * 0.6)),
      actionRadius: Theme.itemRadius                   // consistent radius
      ,
      // Colors from Theme to ensure visual consistency
      background: Theme.bgColor,
      border: Theme.borderColor,
      summary: Theme.textActiveColor,
      body: Theme.textInactiveColor,
      muted: Theme.inactiveColor,
      accent: Theme.onHoverColor,
      danger: Theme.activeColor // fallback to theme accent; adjust if a red tone is added to Theme
      ,
      actionBg: Theme.panelWindowColor === "transparent" ? Theme.bgColor : Theme.panelWindowColor,
      actionFg: Theme.textActiveColor,
      actionHoverBg: Theme.onHoverColor,
      actionBorder: Theme.borderColor,
      // Collapsed line count for bodies
      bodyCollapsedLines: 2
    })
  readonly property ListModel visibleModel: ListModel {
    id: __visibleModel

  }

  // ————— Signals —————
  signal actionInvoked(var notification, string actionIdentifier)
  signal notificationDismissed(var notification, int reason)
  signal notificationShown(var notification)

  // ————— Internal: history —————
  function __appendHistory(notificationObject, closedReason) {
    __historyModel.append(snapshot(notificationObject, closedReason));
    __saveHistory();
    __scheduleGcHint();
  }
  function __enforceHistoryLimit() {
    while (__historyModel.count > maxHistoryItems) {
      __historyModel.remove(0);
    }
  }

  // ————— Internal: order + visible management —————
  function __enqueueNotificationOrder(notificationObject) {
    __orderedActive.push(notificationObject);
  }
  function __evalDnd(notificationObject) {
    const policy = dndPolicy || {};
    if (!policy.enabled)
      return "bypass";
    const behavior = policy.behavior === "suppress" ? "suppress" : "queue";
    const urgencyValue = (notificationObject && notificationObject.urgency !== undefined) ? Number(notificationObject.urgency) : NotificationUrgency.Normal;
    if (policy.urgency?.bypassCritical && urgencyValue === NotificationUrgency.Critical)
      return "bypass";
    const applicationName = String(notificationObject?.appName || "");
    const allowList = Array.isArray(policy.appRules?.allow) ? policy.appRules.allow : [];
    const denyList = Array.isArray(policy.appRules?.deny) ? policy.appRules.deny : [];
    if (allowList.length && !allowList.includes(applicationName))
      return behavior;
    if (denyList.includes(applicationName))
      return behavior;
    if (Array.isArray(policy.schedule) && policy.schedule.length) {
      const now = new Date();
      const dayOfWeek = now.getDay();
      const hour = now.getHours();
      const minute = now.getMinutes();
      for (let scheduleIndex = 0; scheduleIndex < policy.schedule.length; scheduleIndex++) {
        const scheduleEntry = policy.schedule[scheduleIndex] || {};
        const daysArray = Array.isArray(scheduleEntry.days) ? scheduleEntry.days : [];
        if (daysArray.length && !daysArray.includes(dayOfWeek))
          continue;
        if (__timeInRange(hour, minute, scheduleEntry.start, scheduleEntry.end))
          return behavior;
      }
    }
    if (policy.urgency?.suppressLow && urgencyValue === NotificationUrgency.Low)
      return "suppress";
    return "bypass";
  }
  function __flushPersist() {
    try {
      store.historyStoreJson = __pendingHistoryJson;
    } catch (_) {}
    try {
      store.actionLogJson = __pendingActionLogJson;
    } catch (_) {}
    try {
      store.replyLogJson = __pendingReplyLogJson;
    } catch (_) {}
    __persistDirty = false;
    __scheduleGcHint();
  }

  // ————— Grouping —————
  function __groupIdFor(notificationObject) {
    const applicationName = String(notificationObject?.appName || "");
    const summaryKey = String(notificationObject?.summaryKey || notificationObject?.summary || "");
    if (!applicationName || !summaryKey)
      return "";
    return applicationName + ":" + summaryKey;
  }
  function __isHiddenByDnd(notificationObject) {
    const notificationIdString = String(notificationObject?.id || "");
    return !!__queuedOrSuppressed[notificationIdString];
  }
  function __loadHistory() {
    __historyModel.clear();
    let parsedArray = [];
    try {
      parsedArray = JSON.parse(store.historyStoreJson || "[]");
    } catch (_) {
      parsedArray = [];
    }
    for (let index = 0; index < parsedArray.length; index++) {
      const item = parsedArray[index] || {};
      __historyModel.append({
        id: String(item.id || ""),
        summary: String(item.summary || ""),
        body: String(item.body || ""),
        appName: String(item.appName || ""),
        urgency: Number(item.urgency || 0),
        closedReason: Number(item.closedReason ?? -1),
        closedAtMs: Number(item.closedAtMs || Date.now())
      });
    }
  }
  function __loadLogs() {
    try {
      actionLog = JSON.parse(store.actionLogJson || "[]");
    } catch (_) {
      actionLog = [];
    }
    try {
      replyLog = JSON.parse(store.replyLogJson || "[]");
    } catch (_) {
      replyLog = [];
    }
  }
  function __processQueue() {
    // Promote queued notifications when policy allows
    for (let index = 0; index < __orderedActive.length; index++) {
      const notificationObject = __orderedActive[index];
      if (!notificationObject || !notificationObject.tracked)
        continue;
      const notificationIdString = String(notificationObject.id || "");
      const mark = __queuedOrSuppressed[notificationIdString];
      if (mark === "queue" && __evalDnd(notificationObject) === "bypass") {
        delete __queuedOrSuppressed[notificationIdString];
      }
      // "suppress" remains hidden until policy changes
    }
  }
  function __rebuildVisibleModel() {
    __visibleModel.clear();
    // Keep only still-tracked notifications and not hidden by DND,
    // newest last in order list -> visible are the last N.
    const filteredActiveNotifications = [];
    for (let index = 0; index < __orderedActive.length; index++) {
      const notificationObject = __orderedActive[index];
      if (notificationObject && notificationObject.tracked && !__isHiddenByDnd(notificationObject)) {
        filteredActiveNotifications.push(notificationObject);
      }
    }
    const startIndex = Math.max(0, filteredActiveNotifications.length - maxVisibleNotifications);
    for (let index = startIndex; index < filteredActiveNotifications.length; index++) {
      const notificationObject = filteredActiveNotifications[index];
      __visibleModel.append({
        notification: notificationObject
      });
    }
    __scheduleGcHint();
  }
  function __removeFromOrder(notificationObject) {
    const indexInOrder = __orderedActive.indexOf(notificationObject);
    if (indexInOrder >= 0)
      __orderedActive.splice(indexInOrder, 1);
    __scheduleGcHint();
  }
  function __saveHistory() {
    const outputArray = [];
    for (let index = 0; index < __historyModel.count; index++) {
      const entry = __historyModel.get(index);
      outputArray.push({
        id: String(entry.id || ""),
        summary: String(entry.summary || ""),
        body: String(entry.body || ""),
        appName: String(entry.appName || ""),
        urgency: Number(entry.urgency || 0),
        closedReason: Number(entry.closedReason ?? -1),
        closedAtMs: Number(entry.closedAtMs || 0)
      });
    }
    __pendingHistoryJson = JSON.stringify(outputArray);
    __schedulePersist();
  }
  function __saveLogs() {
    try {
      __pendingActionLogJson = JSON.stringify(actionLog || []);
    } catch (_) {
      __pendingActionLogJson = "[]";
    }
    try {
      __pendingReplyLogJson = JSON.stringify(replyLog || []);
    } catch (_) {
      __pendingReplyLogJson = "[]";
    }
    __schedulePersist();
  }
  function __scheduleGcHint() {
    // Trigger only when the panel is not animating new items heavily
    __gcDebounce.restart();
  }
  function __schedulePersist() {
    if (__persistDirty) {
      __persistDebounce.restart();
      return;
    }
    __persistDirty = true;
    __persistDebounce.start();
  }
  function __timeInRange(nowHour, nowMinute, startString, endString) {
    const toHourMinute = inputString => {
      const segments = String(inputString || "0:0").split(":");
      const parsedHour = Math.max(0, Math.min(23, Number(segments[0] || 0)));
      const parsedMinute = Math.max(0, Math.min(59, Number(segments[1] || 0)));
      return [parsedHour, parsedMinute];
    };
    const [startHour, startMinute] = toHourMinute(startString);
    const [endHour, endMinute] = toHourMinute(endString);
    const startTotal = startHour * 60 + startMinute;
    const endTotal = endHour * 60 + endMinute;
    const nowTotal = nowHour * 60 + nowMinute;
    if (startTotal === endTotal)
      return false;
    return startTotal < endTotal ? (nowTotal >= startTotal && nowTotal < endTotal) : (nowTotal >= startTotal || nowTotal < endTotal); // overnight
  }
  function __touchGroup(notificationObject) {
    const groupId = __groupIdFor(notificationObject);
    if (!groupId)
      return "";
    const nowTimestamp = Date.now();
    const notificationIdString = String(notificationObject?.id || "");
    const currentEntry = groupsMap[groupId] || {
      id: groupId,
      title: String(notificationObject?.summary || ""),
      appName: String(notificationObject?.appName || ""),
      children: [],
      updatedAt: nowTimestamp
    };
    if (!currentEntry.children.includes(notificationIdString)) {
      currentEntry.children = [notificationIdString].concat(currentEntry.children);
      if (currentEntry.children.length > groupChildrenCap)
        currentEntry.children = currentEntry.children.slice(0, groupChildrenCap);
    }
    currentEntry.updatedAt = nowTimestamp;
    groupsMap[groupId] = currentEntry;
    return groupId;
  }

  // ————— Internal: lifecycle wiring —————
  function __wireNotificationLifecycle(notificationObject) {
    // When a notification closes, capture it into local history and update visibility.
    // The 'closed(reason)' signal comes from Quickshell.Services.Notifications Notification type.
    if (!notificationObject)
      return;

    // Guard to not double-connect on reloads
    if (notificationObject.__wired)
      return;
    notificationObject.__wired = true;

    notificationObject.closed.connect(function (reason) {
      const notificationIdString = String(notificationObject.id || "");
      delete notificationsService.__queuedOrSuppressed[notificationIdString];
      notificationsService.__removeFromOrder(notificationObject);
      notificationsService.__rebuildVisibleModel();
      notificationsService.__appendHistory(notificationObject, reason);
      notificationsService.notificationDismissed(notificationObject, reason);
      notificationsService.__enforceHistoryLimit();
      const gId = notificationsService.__groupIdFor(notificationObject);
      if (gId && notificationsService.groupsMap[gId]) {
        const entry = notificationsService.groupsMap[gId];
        entry.children = entry.children.filter(idStr => idStr !== notificationIdString);
        if (!entry.children.length)
          delete notificationsService.groupsMap[gId];
      }
    });
  }

  // ————— Public API: clear/dismiss —————
  function clearHistory() {
    __historyModel.clear();
    __saveHistory();
  }
  function dismissAllActive() {
    for (let index = 0; index < __orderedActive.length; index++) {
      const notificationObject = __orderedActive[index];
      if (notificationObject && notificationObject.tracked)
        notificationObject.tracked = false;
    }
  }
  function dismissNotification(notificationObject) {
    if (!notificationObject || !notificationObject.tracked)
      return;
    notificationObject.tracked = false;
  }

  // ————— Convenience: UI animation recipes (Component factories) —————
  function enterAnimation(targetItem) {
    if (!targetItem)
      return null;
    const startX = targetItem.x + Theme.popupOffset;  // slide in from right
    const endX = targetItem.x;
    targetItem.x = startX;
    // keep opacity at 1 for mechanical slide; remove if prior code set it
    targetItem.opacity = 1.0;
    const anim = __enterAnimationComponent.createObject(targetItem, {
      targetItem: targetItem,
      toX: endX
    });
    anim.running = true;
    return anim;
  }
  function exitAnimation(targetItem) {
    if (!targetItem)
      return null;
    const endX = targetItem.x + Theme.popupOffset;
    const anim = __exitAnimationComponent.createObject(targetItem, {
      targetItem: targetItem,
      toX: endX
    });
    anim.running = true;
    return anim;
  }
  function groups() {
    const groupsArray = Object.values(groupsMap || {});
    groupsArray.sort((a, b) => (b?.updatedAt || 0) - (a?.updatedAt || 0));
    return groupsArray;
  }

  // ————— Public API: actions/replies —————
  function invokeAction(notificationObject, actionIdentifier) {
    if (!notificationObject)
      return;
    const actionsArray = notificationObject.actions || [];
    for (let actionIndex = 0; actionIndex < actionsArray.length; actionIndex++) {
      const actionEntry = actionsArray[actionIndex];
      if (actionEntry.identifier === actionIdentifier) {
        actionEntry.invoke();
        actionInvoked(notificationObject, actionIdentifier);
        actionLog = (actionLog || []).concat([
          {
            notificationId: String(notificationObject.id || ""),
            actionId: String(actionIdentifier || ""),
            at: Date.now()
          }
        ]);
        if (actionLog.length > actionLogCap)
          actionLog = actionLog.slice(actionLog.length - actionLogCap);
        __saveLogs();
        return;
      }
    }
  }

  // ————— Convenience: recommended timeout per urgency —————
  function recommendedExpireSeconds(notificationObject) {
    if (!notificationObject)
      return defaultExpireSecondsNormal;
    switch (notificationObject.urgency) {
    case NotificationUrgency.Low:
      return defaultExpireSecondsLow;
    case NotificationUrgency.Critical:
      return defaultExpireSecondsCritical;
    default:
      return defaultExpireSecondsNormal;
    }
  }
  function sendInlineReply(notificationObject, text) {
    const replyText = String(text || "");
    // Requires server.inlineReplySupported and notification.hasInlineReply, per docs.
    if (!notificationObject || typeof notificationObject.sendInlineReply !== "function") {
      return {
        ok: false,
        error: "no-inline-reply"
      };
    }
    if (!server.inlineReplySupported || !notificationObject.hasInlineReply) {
      return {
        ok: false,
        error: "unsupported"
      };
    }
    notificationObject.sendInlineReply(replyText);
    replyLog = (replyLog || []).concat([
      {
        notificationId: String(notificationObject.id || ""),
        text: replyText,
        at: Date.now()
      }
    ]);
    if (replyLog.length > replyLogCap)
      replyLog = replyLog.slice(replyLog.length - replyLogCap);
    __saveLogs();
    return {
      ok: true
    };
  }

  // ————— DND helpers —————
  function setDndPolicy(patch) {
    function deepMerge(baseObject, patchObject) {
      const merged = {};
      for (const key in baseObject) {
        if (Object.prototype.hasOwnProperty.call(baseObject, key))
          merged[key] = baseObject[key];
      }
      for (const key in patchObject) {
        if (!Object.prototype.hasOwnProperty.call(patchObject, key))
          continue;
        const baseValue = baseObject[key];
        const patchValue = patchObject[key];
        merged[key] = (patchValue && typeof patchValue === "object" && !Array.isArray(patchValue)) ? deepMerge(baseValue || {}, patchValue) : patchValue;
      }
      return merged;
    }
    dndPolicy = deepMerge({
      enabled: false,
      schedule: [],
      appRules: {
        allow: [],
        deny: []
      },
      urgency: {
        bypassCritical: true,
        suppressLow: false
      },
      behavior: "queue"
    }, patch || {});
    __processQueue();
    __rebuildVisibleModel();
  }

  // Build a friendly snapshot object for history entries.
  function snapshot(notificationObject, closedReason) {
    return {
      id: notificationObject ? notificationObject.id : 0,
      appName: notificationObject ? notificationObject.appName : "",
      appIcon: notificationObject ? notificationObject.appIcon : "",
      desktopEntry: notificationObject ? notificationObject.desktopEntry : "",
      summary: notificationObject ? notificationObject.summary : "",
      body: notificationObject ? notificationObject.body : "",
      urgency: notificationObject ? notificationObject.urgency : 1,
      hasActionIcons: notificationObject ? notificationObject.hasActionIcons : false,
      resident: notificationObject ? notificationObject.resident : false,
      image: notificationObject ? notificationObject.image : "",
      expireTimeout: notificationObject ? notificationObject.expireTimeout : 0,
      lastGeneration: notificationObject ? notificationObject.lastGeneration : false,
      closedReason: closedReason ?? -1,
      closedAtMs: Date.now()
    };
  }

  Component.onCompleted: {
    __loadHistory();
    __loadLogs();
  }

  // ————— Persistence: history + logs —————
  PersistentProperties {
    id: store

    property string actionLogJson: "[]"
    property string historyStoreJson: "[]"
    property string replyLogJson: "[]"

    reloadableId: "NotificationService"
  }
  // Debounce persistence writes
  Timer {
    id: __persistDebounce

    interval: 250
    repeat: false

    onTriggered: notificationsService.__flushPersist()
  }

  // ————— Memory pressure hint —————
  // Debounced GC nudge after heavy updates; harmless on Qt builds that ignore gc().
  Timer {
    id: __gcDebounce

    interval: 500
    repeat: false

    onTriggered: {
      try {
        if (typeof gc === "function")
          gc();
      } catch (_) {}
    }
  }

  // ————— Animation Components —————
  // Factory: enter animation (component-based to allow runtime creation)
  Component {
    id: __enterAnimationComponent

    SequentialAnimation {
      id: __enterAnim

      property Item targetItem
      property real toX

      onFinished: destroy()

      PropertyAnimation {
        duration: notificationsService.enterAnimationDurationMs
        easing.type: Easing.OutCubic
        property: "x"
        target: __enterAnim.targetItem
        to: __enterAnim.toX
      }
    }
  }
  Component {
    id: __exitAnimationComponent

    SequentialAnimation {
      id: __exitAnim

      property Item targetItem
      property real toX

      onFinished: destroy()

      PropertyAnimation {
        duration: notificationsService.exitAnimationDurationMs
        easing.type: Easing.InCubic
        property: "x"
        target: __exitAnim.targetItem
        to: __exitAnim.toX
      }
    }
  }
}
