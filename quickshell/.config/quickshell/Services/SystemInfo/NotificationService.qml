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
    let skipped = 0;
    for (const notif of notificationList) {
      if (!notif) {
        skipped++;
        continue;
      }

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

    const result = Object.values(groups).sort((a, b) => {
      const aUrgency = a.latestNotification?.urgency || NotificationUrgency.Low;
      const bUrgency = b.latestNotification?.urgency || NotificationUrgency.Low;
      if (aUrgency !== bUrgency)
        return bUrgency - aUrgency;

      const aTime = a.latestNotification?.time?.getTime() || 0;
      const bTime = b.latestNotification?.time?.getTime() || 0;
      return bTime - aTime;
    });

    return result;
  }

  function _limitNotificationsPerApp() {
    const appCounts = {};
    const toRemove = [];

    for (let i = 0; i < root.notifications.length; i++) {
      const notif = root.notifications[i];
      if (!notif)
        continue;
      const appKey = root.getGroupKey(notif);
      appCounts[appKey] = (appCounts[appKey] || 0) + 1;

      // Only remove if over limit, not critical, and still has notification object to dismiss
      if (appCounts[appKey] > root.maxNotificationsPerApp && notif.urgency !== NotificationUrgency.Critical && notif.notification) {
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

    // Remove oldest non-critical first (only those with notification objects)
    for (let i = root.notifications.length - 1; i >= 0 && toDrop.length < overflow; i--) {
      const notif = root.notifications[i];
      if (notif && notif.notification && notif.urgency !== NotificationUrgency.Critical) {
        toDrop.push(notif);
      }
    }

    // Remove oldest critical if needed (only those with notification objects)
    for (let i = root.notifications.length - 1; i >= 0 && toDrop.length < overflow; i--) {
      const notif = root.notifications[i];
      if (notif && notif.notification && !toDrop.includes(notif)) {
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

      const shouldShowPopup = !root.popupsDisabled && !root.isDndEnabled();
      const wrapper = notifComponent.createObject(root, {
        popup: shouldShowPopup,
        notification: notif
      });

      if (wrapper) {
        root.notifications = [wrapper, ...root.notifications];
        root._trimStoredNotifications();

        if (shouldShowPopup) {
          root._enqueuePopup(wrapper);
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
    property bool isDismissing: false  // Flag to prevent onDropped() during explicit dismiss

    // Snapshot data so it persists after notification is dropped
    // Initialize directly from notification to avoid race conditions
    readonly property date time: new Date()
    property string id: String(notification?.id || "")
    property string summary: notification?.summary || ""
    property string body: notification?.body || ""
    property string appIcon: notification?.appIcon || ""
    property string appName: notification?.appName || "app"
    property string desktopEntry: notification?.desktopEntry || ""
    property string image: notification?.image || ""
    property int urgency: notification?.urgency || NotificationUrgency.Normal
    readonly property color accentColor: root.getAccentColor(wrapper.urgency)
    property string inlineReplyPlaceholder: notification?.inlineReplyPlaceholder || "Reply"
    property bool hasInlineReply: notification?.hasInlineReply || false
    readonly property bool hasBody: {
      const bodyText = (wrapper.body || "").trim();
      const summaryText = (wrapper.summary || "").trim();
      return bodyText && bodyText !== summaryText;
    }
    readonly property bool canExpandBody: hasBody
    property var actions: []

    Component.onCompleted: {
      // Normalize actions - can't be done in property initializer
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
        return false;
      }
      return false;
    }

    onPopupChanged: {
      if (!wrapper.popup) {
        root.removeFromVisibleNotifications(wrapper);
      }
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
      target: wrapper.notification?.Retainable || null
      enabled: !wrapper.isDismissing && !!target  // Disable during explicit dismiss or if no target
      function onDropped() {
        // Don't remove from storage - only remove from active popups
        // This allows notifications to persist in history even after being dropped by daemon
        root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
        root.notificationQueue = root.notificationQueue.filter(n => n !== wrapper);
        wrapper.popup = false;

        root.cleanupExpansionStates();
      }
      function onAboutToDestroy() {
      // Notification object is being destroyed
      // No need to set to null - wrapper will be destroyed anyway
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

    root.addGateBusy = true;
    addGate.restart();
  }

  function removeFromVisibleNotifications(wrapper) {
    root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
    Qt.callLater(() => root.processQueue());
  }

  function dismissNotification(wrapper) {
    if (!wrapper)
      return;

    // Set flag to prevent onDropped() from running during this dismiss
    wrapper.isDismissing = true;

    // Remove from all lists
    root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
    root.notificationQueue = root.notificationQueue.filter(n => n !== wrapper);
    root.notifications = root.notifications.filter(n => n !== wrapper);
    wrapper.popup = false;

    // Dismiss the notification if it still exists
    if (wrapper.notification) {
      try {
        wrapper.notification.dismiss();
      } catch (e) {}
    }

    // Destroy the wrapper since it's been removed from storage
    try {
      wrapper.destroy();
    } catch (e) {}
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

    // Dismiss and destroy all notifications
    for (const wrapper of root.notifications) {
      if (wrapper.notification) {
        try {
          wrapper.notification.dismiss();
        } catch (e) {}
      }
      try {
        wrapper.destroy();
      } catch (e) {}
    }
    root.notifications = [];

    root.expandedGroups = {};
    root.expandedMessages = {};

    Qt.callLater(() => root.popupsDisabled = false);
  }

  function executeAction(wrapper, actionId, actionObj) {
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

    tryCall(notif, "invokeAction", actionId) || tryCall(notif, "activateAction", actionId) || tryCall(notif, "triggerAction", actionId) || tryCall(notif, "action", actionId);
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
    if (!groupKey)
      return;

    // Try to find in both grouped lists (popups and stored notifications)
    let group = root.groupedPopups.find(g => g.key === groupKey);
    if (!group) {
      group = root.groupedNotifications.find(g => g.key === groupKey);
    }

    if (group) {
      for (const notif of group.notifications) {
        // Use dismissNotification to properly remove from storage
        root.dismissNotification(notif);
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
