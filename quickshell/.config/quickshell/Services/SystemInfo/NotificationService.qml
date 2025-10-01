pragma Singleton
pragma ComponentBehavior: Bound
import qs.Services.Utils
import qs.Config
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Services.SystemInfo

Singleton {
  id: root

  // Configuration
  readonly property int timeoutLow: 3000
  readonly property int timeoutNormal: 5000
  readonly property int timeoutCritical: 0
  readonly property int maxVisibleNotifications: 3
  readonly property int maxStoredNotifications: 300
  readonly property int maxNotificationsPerApp: 10
  readonly property int animationDuration: 400

  // Core state
  property var notifications: []
  property var visibleNotifications: []
  property var notificationQueue: []
  property var expandedGroups: ({})
  property var expandedMessages: ({})
  property bool popupsDisabled: false
  property bool addGateBusy: false
  property int seqCounter: 0
  property bool timeUpdateTick: false

  // Readonly properties
  readonly property var popups: root.visibleNotifications
  readonly property var groupedNotifications: root._computeGroups(root.notifications)
  readonly property var groupedPopups: root._computeGroups(root.visibleNotifications)

  function getTimeoutForUrgency(urgency) {
    switch (urgency) {
    case NotificationUrgency.Low:
      return root.timeoutLow;
    case NotificationUrgency.Critical:
      return root.timeoutCritical;
    default:
      return root.timeoutNormal;
    }
  }

  function getAccentColor(urgency) {
    switch (urgency) {
    case NotificationUrgency.Critical:
      return "#ff4d4f";
    case NotificationUrgency.Low:
      return Qt.rgba(Theme.disabledColor.r, Theme.disabledColor.g, Theme.disabledColor.b, 0.9);
    default:
      return Theme.activeColor;
    }
  }

  function getGroupKey(wrapper) {
    const de = wrapper?.desktopEntry || "";
    if (de)
      return de.toLowerCase();
    return (wrapper?.appName || "app").toLowerCase();
  }

  function isDndEnabled() {
    try {
      return typeof OSDService !== "undefined" && OSDService.doNotDisturb;
    } catch (e) {
      return false;
    }
  }

  function use24Hour() {
    try {
      return typeof TimeService !== "undefined" ? TimeService.use24Hour : true;
    } catch (e) {
      return true;
    }
  }

  function _computeGroups(notificationList) {
    const groups = {};
    for (const notif of notificationList) {
      if (!notif?.notification)
        continue;
      const groupKey = root.getGroupKey(notif);
      if (!groups[groupKey]) {
        groups[groupKey] = {
          key: groupKey,
          appName: notif.appName,
          notifications: [],
          latestNotification: null,
          count: 0,
          hasInlineReply: false
        };
      }

      groups[groupKey].notifications.unshift(notif);
      groups[groupKey].latestNotification = groups[groupKey].notifications[0];
      groups[groupKey].count = groups[groupKey].notifications.length;

      if (notif.notification?.hasInlineReply) {
        groups[groupKey].hasInlineReply = true;
      }
    }

    return Object.values(groups).sort((a, b) => {
      const aUrgency = a.latestNotification?.urgency || NotificationUrgency.Low;
      const bUrgency = b.latestNotification?.urgency || NotificationUrgency.Low;
      if (aUrgency !== bUrgency)
        return bUrgency - aUrgency;

      const aTime = a.latestNotification?.time?.getTime() || 0;
      const bTime = b.latestNotification?.time?.getTime() || 0;
      return bTime - aTime;
    });
  }

  function _limitNotificationsPerApp() {
    const appCounts = {};
    const toRemove = [];

    for (let i = 0; i < root.notifications.length; i++) {
      const notif = root.notifications[i];
      if (!notif?.notification)
        continue;
      const appKey = root.getGroupKey(notif);
      appCounts[appKey] = (appCounts[appKey] || 0) + 1;

      if (appCounts[appKey] > root.maxNotificationsPerApp && notif.urgency !== NotificationUrgency.Critical) {
        toRemove.push(notif);
      }
    }

    for (const notif of toRemove) {
      try {
        notif.notification?.dismiss();
      } catch (e) {}
    }
  }

  function _trimStoredNotifications() {
    if (root.notifications.length <= root.maxStoredNotifications)
      return;
    const overflow = root.notifications.length - root.maxStoredNotifications;
    const toDrop = [];

    // Remove oldest non-critical first
    for (let i = root.notifications.length - 1; i >= 0 && toDrop.length < overflow; i--) {
      const notif = root.notifications[i];
      if (notif?.notification && notif.urgency !== NotificationUrgency.Critical) {
        toDrop.push(notif);
      }
    }

    // Remove oldest critical if needed
    for (let i = root.notifications.length - 1; i >= 0 && toDrop.length < overflow; i--) {
      const notif = root.notifications[i];
      if (notif?.notification && !toDrop.includes(notif)) {
        toDrop.push(notif);
      }
    }

    for (const notif of toDrop) {
      try {
        notif.notification?.dismiss();
      } catch (e) {}
    }
  }

  function _enqueuePopup(wrapper) {
    if (root.notificationQueue.length >= 10) {
      const oldest = root.notificationQueue.pop();
      if (oldest)
        oldest.popup = false;
    }

    root.notificationQueue.unshift(wrapper);
    root.processQueue();
  }

  function _normalizeActions(notification) {
    const actions = notification?.actions;
    if (!actions)
      return [];

    const count = Array.isArray(actions) ? actions.length : (actions.length || 0);
    if (!count)
      return [];

    const normalized = [];
    const seenIds = new Set();
    const inlineReplyIds = notification?.hasInlineReply ? ["inline-reply", "inline_reply", "reply"] : [];
    for (let i = 0; i < count; i++) {
      const action = actions[i];
      if (!action)
        continue;
      const id = String(action.identifier || action.id || action.name || "");
      if (!id)
        continue;
      const idKey = id.toLowerCase();
      if (seenIds.has(idKey))
        continue;
      if (inlineReplyIds.includes(idKey) || action.isInlineReply === true)
        continue;
      const title = String(action.text || action.title || action.label || id);

      normalized.push({
        id: id,
        title: title,
        _obj: action
      });
      seenIds.add(idKey);
    }
    return normalized;
  }

  Timer {
    id: updateTimer
    interval: 30000
    repeat: true
    running: root.notifications.length > 0 || root.visibleNotifications.length > 0
    onTriggered: {
      root.timeUpdateTick = !root.timeUpdateTick;
      root._limitNotificationsPerApp();
    }
  }

  Timer {
    id: addGate
    interval: root.animationDuration + 50
    running: false
    repeat: false
    onTriggered: {
      root.addGateBusy = false;
      root.processQueue();
    }
  }

  NotificationServer {
    id: server
    keepOnReload: false
    actionsSupported: true
    actionIconsSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    bodyMarkupSupported: true
    imageSupported: true
    inlineReplySupported: true
    persistenceSupported: true

    onNotification: notif => {
      notif.tracked = true;

      try {
        Logger.log("NotificationService", `received: id=${notif.id}, app='${notif.appName}', summary='${notif.summary}'`);
      } catch (e) {}

      const shouldShowPopup = !root.popupsDisabled && !root.isDndEnabled();
      const wrapper = notifComponent.createObject(root, {
        popup: shouldShowPopup,
        notification: notif
      });

      if (wrapper) {
        root.notifications.unshift(wrapper);
        root._trimStoredNotifications();

        if (shouldShowPopup) {
          root._enqueuePopup(wrapper);
          try {
            Logger.log("NotificationService", `enqueued popup: id=${notif.id}`);
          } catch (e) {}
        }
      }
    }
  }

  component NotifWrapper: QtObject {
    id: wrapper

    required property Notification notification
    property bool popup: false
    property bool isPersistent: notification?.urgency === NotificationUrgency.Critical || timer.interval === 0
    property int seq: 0

    readonly property date time: new Date()
    readonly property string id: String(notification?.id || "")
    readonly property string summary: notification?.summary || ""
    readonly property string body: notification?.body || ""
    readonly property string appIcon: notification?.appIcon || ""
    readonly property string appName: notification?.appName || "app"
    readonly property string desktopEntry: notification?.desktopEntry || ""
    readonly property string image: notification?.image || ""
    readonly property int urgency: notification?.urgency || NotificationUrgency.Normal
    readonly property color accentColor: root.getAccentColor(wrapper.urgency)
    readonly property string inlineReplyPlaceholder: notification?.inlineReplyPlaceholder || "Reply"
    readonly property bool hasInlineReply: notification?.hasInlineReply || false
    readonly property bool hasBody: {
      const bodyText = (wrapper.body || "").trim();
      const summaryText = (wrapper.summary || "").trim();
      return bodyText && bodyText !== summaryText;
    }
    readonly property bool canExpandBody: hasBody
    property var actions: []

    Component.onCompleted: {
      try {
        wrapper.actions = root._normalizeActions(wrapper.notification);
      } catch (e) {
        wrapper.actions = [];
      }
    }

    readonly property string timeStr: {
      root.timeUpdateTick;
      const now = new Date();
      const diff = now.getTime() - wrapper.time.getTime();
      const minutes = Math.floor(diff / 60000);
      const hours = Math.floor(minutes / 60);

      if (hours < 1) {
        return minutes < 1 ? "now" : `${minutes}m ago`;
      }

      const daysDiff = Math.floor((now - new Date(now.getFullYear(), now.getMonth(), now.getDate()) - (wrapper.time - new Date(wrapper.time.getFullYear(), wrapper.time.getMonth(), wrapper.time.getDate()))) / (1000 * 60 * 60 * 24));

      if (daysDiff === 0)
        return wrapper.formatTime(wrapper.time);
      if (daysDiff === 1)
        return `yesterday, ${wrapper.formatTime(wrapper.time)}`;
      return `${daysDiff} days ago`;
    }

    function formatTime(date) {
      const format = root.use24Hour() ? "HH:mm" : "h:mm AP";
      return date.toLocaleTimeString(Qt.locale(), format);
    }

    function sendInlineReply(text) {
      if (!wrapper.notification || !text)
        return false;
      try {
        if (wrapper.notification.hasInlineReply && wrapper.notification.sendInlineReply) {
          wrapper.notification.sendInlineReply(String(text));
          return true;
        }
      } catch (e) {
        try {
          Logger.log("NotificationService", `inline reply failed: ${e}`);
        } catch (e2) {}
      }
      return false;
    }

    onPopupChanged: {
      if (!wrapper.popup)
        root.removeFromVisibleNotifications(wrapper);
    }

    readonly property Timer timer: Timer {
      interval: root.getTimeoutForUrgency(wrapper.urgency)
      repeat: false
      running: false
      onTriggered: {
        if (wrapper.timer.interval > 0)
          wrapper.popup = false;
      }
    }

    readonly property Connections conn: Connections {
      target: wrapper.notification?.Retainable
      function onDropped() {
        root.notifications = root.notifications.filter(n => n !== wrapper);
        root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
        root.notificationQueue = root.notificationQueue.filter(n => n !== wrapper);

        try {
          Logger.log("NotificationService", `dropped: id=${wrapper.id}`);
        } catch (e) {}

        root.cleanupExpansionStates();
      }
      function onAboutToDestroy() {
        wrapper.destroy();
      }
    }
  }

  Component {
    id: notifComponent
    NotifWrapper {}
  }

  // API Functions
  function processQueue() {
    if (root.addGateBusy || root.popupsDisabled || root.isDndEnabled())
      return;
    if (root.notificationQueue.length === 0)
      return;
    const activeCount = root.visibleNotifications.filter(n => n?.popup).length;
    if (activeCount >= root.maxVisibleNotifications)
      return;
    const next = root.notificationQueue.shift();
    if (!next)
      return;
    next.seq = ++root.seqCounter;
    root.visibleNotifications = [...root.visibleNotifications, next];
    next.popup = true;

    if (next.timer.interval > 0) {
      next.timer.start();
    }

    try {
      Logger.log("NotificationService", `show popup: id=${next.id}, timeout=${next.timer.interval}`);
    } catch (e) {}

    root.addGateBusy = true;
    addGate.restart();
  }

  function removeFromVisibleNotifications(wrapper) {
    root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
    try {
      Logger.log("NotificationService", `hide popup: id=${wrapper?.id || "?"}`);
    } catch (e) {}
    Qt.callLater(() => root.processQueue());
  }

  function dismissNotification(wrapper) {
    if (!wrapper?.notification)
      return;
    root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
    root.notificationQueue = root.notificationQueue.filter(n => n !== wrapper);
    wrapper.popup = false;
    wrapper.notification.dismiss();
  }

  function clearAllNotifications() {
    root.popupsDisabled = true;
    addGate.stop();
    root.addGateBusy = false;
    root.notificationQueue = [];

    for (const wrapper of root.visibleNotifications) {
      if (wrapper)
        wrapper.popup = false;
    }
    root.visibleNotifications = [];

    for (const wrapper of root.notifications) {
      try {
        wrapper?.notification?.dismiss();
      } catch (e) {}
    }

    root.expandedGroups = {};
    root.expandedMessages = {};

    Qt.callLater(() => root.popupsDisabled = false);
  }

  function executeAction(wrapper, actionId, actionObj) {
    try {
      Logger.log("NotificationService", `executeAction: id=${actionId}`);
    } catch (e) {}

    const notif = wrapper?.notification;
    if (!notif)
      return;
    function tryCall(obj, method, arg) {
      try {
        const fn = obj[method];
        if (typeof fn === "function") {
          fn.call(obj, arg);
          return true;
        }
      } catch (e) {}
      return false;
    }

    if (actionObj) {
      if (tryCall(actionObj, "trigger"))
        return;
      if (tryCall(actionObj, "activate"))
        return;
      if (tryCall(actionObj, "invoke"))
        return;
      if (tryCall(actionObj, "click"))
        return;
    }

    if (tryCall(notif, "invokeAction", actionId))
      return;
    if (tryCall(notif, "activateAction", actionId))
      return;
    if (tryCall(notif, "triggerAction", actionId))
      return;
    if (tryCall(notif, "action", actionId))
      return;
  }

  function onOverlayOpen() {
    root.popupsDisabled = true;
    addGate.stop();
    root.addGateBusy = false;
    root.notificationQueue = [];

    for (const notif of root.visibleNotifications) {
      if (notif)
        notif.popup = false;
    }
    root.visibleNotifications = [];
  }

  function onOverlayClose() {
    root.popupsDisabled = false;
    root.processQueue();
  }

  function toggleGroupExpansion(groupKey) {
    const next = {};
    for (const key in root.expandedGroups) {
      next[key] = root.expandedGroups[key];
    }
    next[groupKey] = !next[groupKey];
    root.expandedGroups = next;
  }

  function dismissGroup(groupKey) {
    const group = root.groupedNotifications.find(g => g.key === groupKey);
    if (group) {
      for (const notif of group.notifications) {
        try {
          notif?.notification?.dismiss();
        } catch (e) {}
      }
    }
  }

  function toggleMessageExpansion(messageId) {
    const next = {};
    for (const key in root.expandedMessages) {
      next[key] = root.expandedMessages[key];
    }
    next[messageId] = !next[messageId];
    root.expandedMessages = next;
  }

  function cleanupExpansionStates() {
    const currentGroupKeys = new Set(root.groupedNotifications.map(g => g.key));
    const currentMessageIds = new Set();

    for (const group of root.groupedNotifications) {
      for (const notif of group.notifications) {
        currentMessageIds.add(notif.notification?.id);
      }
    }

    const nextGroups = {};
    for (const key in root.expandedGroups) {
      if (currentGroupKeys.has(key) && root.expandedGroups[key]) {
        nextGroups[key] = true;
      }
    }
    root.expandedGroups = nextGroups;

    const nextMessages = {};
    for (const messageId in root.expandedMessages) {
      if (currentMessageIds.has(messageId) && root.expandedMessages[messageId]) {
        nextMessages[messageId] = true;
      }
    }
    root.expandedMessages = nextMessages;
  }

  Connections {
    target: typeof OSDService !== "undefined" ? OSDService : null
    function onDoNotDisturbChanged() {
      if (root.isDndEnabled()) {
        for (const notif of root.visibleNotifications) {
          if (notif)
            notif.popup = false;
        }
        root.visibleNotifications = [];
        root.notificationQueue = [];
      } else {
        root.processQueue();
      }
    }
  }

  Connections {
    target: typeof TimeService !== "undefined" ? TimeService : null
    function onUse24HourChanged() {
      root.timeUpdateTick = !root.timeUpdateTick;
    }
  }
}
