pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Config
import qs.Services.SystemInfo

Singleton {
  id: root

  // Configuration
  readonly property int timeoutLow: 3000
  readonly property int timeoutNormal: 5000
  readonly property int timeoutCritical: 0
  readonly property int maxVisibleNotifications: 3
  readonly property int maxStoredNotifications: 100
  readonly property int maxNotificationsPerApp: 10
  readonly property int animationDuration: 400

  // Core state
  property var notifications: []
  property var visibleNotifications: []
  property var notificationQueue: []
  property var expandedGroups: ({})
  property bool popupsDisabled: false
  property bool addGateBusy: false
  property int seqCounter: 0
  property bool timeUpdateTick: false

  // Readonly computed properties
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
    return de ? de.toLowerCase() : (wrapper?.appName || "app").toLowerCase();
  }

  function isDndEnabled() {
    return typeof OSDService !== "undefined" && OSDService.doNotDisturb;
  }

  function use24Hour() {
    return typeof TimeService !== "undefined" ? TimeService.use24Hour : true;
  }

  function _computeGroups(notificationList) {
    const groups = {};

    for (const notif of notificationList) {
      if (!notif)
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
      groups[groupKey].count++;

      if (notif.notification?.hasInlineReply)
        groups[groupKey].hasInlineReply = true;
    }

    // Update latestNotification after all notifications are added
    for (const key in groups) {
      groups[key].latestNotification = groups[key].notifications[0];
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

    for (const notif of root.notifications) {
      if (!notif)
        continue;

      const appKey = root.getGroupKey(notif);
      appCounts[appKey] = (appCounts[appKey] || 0) + 1;

      if (appCounts[appKey] > root.maxNotificationsPerApp && notif.urgency !== NotificationUrgency.Critical && notif.notification) {
        toRemove.push(notif);
      }
    }

    for (const notif of toRemove) {
      notif.notification?.dismiss();
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
      if (notif?.notification && notif.urgency !== NotificationUrgency.Critical)
        toDrop.push(notif);
    }

    // Remove oldest critical if still needed
    if (toDrop.length < overflow) {
      for (let i = root.notifications.length - 1; i >= 0 && toDrop.length < overflow; i--) {
        const notif = root.notifications[i];
        if (notif?.notification && !toDrop.includes(notif))
          toDrop.push(notif);
      }
    }

    for (const notif of toDrop) {
      notif.notification?.dismiss();
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
      if (seenIds.has(idKey) || inlineReplyIds.includes(idKey) || action.isInlineReply === true)
        continue;

      normalized.push({
        id: id,
        title: String(action.text || action.title || action.label || id),
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

      // Aggressive cleanup to prevent memory bloat
      if (root.notifications.length > root.maxStoredNotifications) {
        root._trimStoredNotifications();
      }
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

  Component.onDestruction: {
    updateTimer.stop();
    addGate.stop();
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

        if (shouldShowPopup)
          root._enqueuePopup(wrapper);
      }
    }
  }

  component NotifWrapper: QtObject {
    id: wrapper

    required property Notification notification
    property bool popup: false
    property bool isDismissing: false
    property int seq: 0

    readonly property bool isPersistent: notification?.urgency === NotificationUrgency.Critical || timer.interval === 0
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
    readonly property var actions: root._normalizeActions(wrapper.notification)

    readonly property string timeStr: {
      root.timeUpdateTick;
      const now = new Date();
      const diff = now.getTime() - wrapper.time.getTime();
      const minutes = Math.floor(diff / 60000);

      if (minutes < 1)
        return "now";
      if (minutes < 60)
        return `${minutes}m ago`;

      const hours = Math.floor(minutes / 60);
      const daysDiff = Math.floor((now - new Date(now.getFullYear(), now.getMonth(), now.getDate()) - (wrapper.time - new Date(wrapper.time.getFullYear(), wrapper.time.getMonth(), wrapper.time.getDate()))) / 86400000);

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
      if (!wrapper.notification?.hasInlineReply || !text)
        return false;
      try {
        wrapper.notification.sendInlineReply(String(text));
        return true;
      } catch (e) {
        return false;
      }
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
      target: wrapper.notification?.Retainable || null
      enabled: !wrapper.isDismissing && !!target

      function onDropped() {
        wrapper.isDismissing = true;
        root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
        root.notificationQueue = root.notificationQueue.filter(n => n !== wrapper);
        root.notifications = root.notifications.filter(n => n !== wrapper);
        wrapper.popup = false;
        root.cleanupExpansionStates();
        wrapper.destroy();
      }
    }
  }

  Component {
    id: notifComponent
    NotifWrapper {}
  }

  function processQueue() {
    if (root.addGateBusy || root.popupsDisabled || root.isDndEnabled() || root.notificationQueue.length === 0)
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

    if (next.timer.interval > 0)
      next.timer.start();

    root.addGateBusy = true;
    addGate.restart();
  }

  function removeFromVisibleNotifications(wrapper) {
    root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
    Qt.callLater(root.processQueue);
  }

  function dismissNotification(wrapper) {
    if (!wrapper)
      return;

    wrapper.isDismissing = true;

    root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
    root.notificationQueue = root.notificationQueue.filter(n => n !== wrapper);
    root.notifications = root.notifications.filter(n => n !== wrapper);
    wrapper.popup = false;

    if (wrapper.notification) {
      wrapper.notification.dismiss();
    }

    wrapper.destroy();
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
      wrapper.notification?.dismiss();
      wrapper.destroy();
    }
    root.notifications = [];

    root.expandedGroups = {};

    Qt.callLater(() => root.popupsDisabled = false);
  }

  function executeAction(wrapper, actionId, actionObj) {
    const notif = wrapper?.notification;
    if (!notif)
      return;

    const methods = actionObj ? [() => actionObj.trigger(), () => actionObj.activate(), () => actionObj.invoke(), () => actionObj.click()] : [];

    methods.push(() => notif.invokeAction(actionId), () => notif.activateAction(actionId), () => notif.triggerAction(actionId), () => notif.action(actionId));

    for (const method of methods) {
      try {
        const result = method();
        if (result !== undefined)
          return;
      } catch (e) {}
    }
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
    const next = Object.assign({}, root.expandedGroups);
    next[groupKey] = !next[groupKey];
    root.expandedGroups = next;
  }

  function dismissGroup(groupKey) {
    if (!groupKey)
      return;

    const group = root.groupedPopups.find(g => g.key === groupKey) || root.groupedNotifications.find(g => g.key === groupKey);

    if (group) {
      for (const notif of group.notifications)
        root.dismissNotification(notif);
    }
  }

  function cleanupExpansionStates() {
    const currentGroupKeys = new Set(root.groupedNotifications.map(g => g.key));

    const nextGroups = {};
    for (const key in root.expandedGroups) {
      if (currentGroupKeys.has(key) && root.expandedGroups[key])
        nextGroups[key] = true;
    }
    root.expandedGroups = nextGroups;
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
