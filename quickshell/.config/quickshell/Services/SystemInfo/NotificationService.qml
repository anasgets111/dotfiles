pragma Singleton
pragma ComponentBehavior: Bound
import qs.Services.Utils
import qs.Config
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Services.Utils
import qs.Services.SystemInfo

Singleton {
  id: root
  // Hardcoded defaults and helpers (no SettingsData/Paths/etc needed)
  // Notification timeouts per urgency (ms)
  property int notificationTimeoutLow: 3000
  property int notificationTimeoutNormal: 5000
  property int notificationTimeoutCritical: 0  // 0 => persistent
  function getTimeoutForUrgency(urgency) {
    switch (urgency) {
    case NotificationUrgency.Low:
      return root.notificationTimeoutLow;
    case NotificationUrgency.Critical:
      return root.notificationTimeoutCritical;
    default:
      return root.notificationTimeoutNormal;
    }
  }
  function _accentColorForUrgency(urgency) {
    switch (urgency) {
    case NotificationUrgency.Critical:
      return "#ff4d4f";
    case NotificationUrgency.Low:
      return Qt.rgba(Theme.disabledColor.r, Theme.disabledColor.g, Theme.disabledColor.b, 0.9);
    default:
      return Theme.activeColor;
    }
  }
  function _normalizeActions(actions) {
    if (!actions)
      return [];
    const count = Array.isArray(actions) ? actions.length : (typeof actions.length === "number" ? actions.length : 0);
    if (!count)
      return [];
    const normalized = [];
    for (let i = 0; i < count; ++i) {
      const action = actions[i];
      if (!action)
        continue;
      const id = String(action.identifier || action.id || action.name || "");
      const titleSource = action.text || action.title || action.label || id;
      normalized.push({
        "id": id,
        "title": String(titleSource),
        "_obj": action
      });
    }
    return normalized;
  }
  function _sendInlineReply(notification, text) {
    if (!notification || typeof text === "undefined")
      return false;
    const reply = String(text || "");
    if (!reply.length)
      return false;
    try {
      if (notification.hasInlineReply && notification.sendInlineReply) {
        notification.sendInlineReply(reply);
        return true;
      }
    } catch (e) {
      try {
        Logger.log("NotificationService", `inline reply failed: ${e}`);
      } catch (e2) {}
    }
    return false;
  }
  function _hydrateWrapper(wrapper) {
    if (!wrapper || !wrapper.notification)
      return;
    wrapper.actions = root._normalizeActions(wrapper.notification.actions);
  }
  function safeUse24Hour() {
    try {
      return typeof TimeService !== "undefined" ? TimeService.use24Hour : true;
    } catch (e) {
      return true;
    }
  }
  function safeStripPath(p) {
    // No external Paths dependency; return as-is
    return p || "";
  }
  function safeMarkdownToHtml(text) {
    // Minimal fallback: no markdown conversion
    return text || "";
  }
  function safeDesktopLookup(key) {
    // Not available; return null
    return null;
  }
  function dndEnabled() {
    try {
      return typeof OSDService !== "undefined" && OSDService.doNotDisturb;
    } catch (e) {
      return false;
    }
  }
  property var notifications: []
  property var allWrappers: []
  // Popups derive from visibleNotifications; no need to scan allWrappers
  readonly property var popups: visibleNotifications
  property var notificationQueue: []
  property var visibleNotifications: []
  property int maxVisibleNotifications: 3
  property bool addGateBusy: false
  property int enterAnimMs: 400
  property int seqCounter: 0
  property bool bulkDismissing: false
  property int maxQueueSize: 32
  property int maxIngressPerSecond: 20
  property double _lastIngressSec: 0
  property int _ingressCountThisSec: 0
  property int maxStoredNotifications: 300
  property var _dismissQueue: []
  property int _dismissBatchSize: 8
  property int _dismissTickMs: 8
  property bool _suspendGrouping: false
  property var _groupCache: ({
      "notifications": [],
      "popups": []
    })
  property bool _groupsDirty: false
  Component.onCompleted: {
    root._recomputeGroups();
  }
  property bool timeUpdateTick: false
  property bool clockFormatChanged: false
  readonly property var groupedNotifications: _groupCache.notifications
  readonly property var groupedPopups: _groupCache.popups
  property var expandedGroups: ({})
  property var expandedMessages: ({})
  property bool popupsDisabled: false
  function _nowSec() {
    return Date.now() / 1000.0;
  }
  function _ingressAllowed(notif) {
    const t = root._nowSec();
    if (t - root._lastIngressSec >= 1.0) {
      root._lastIngressSec = t;
      root._ingressCountThisSec = 0;
    }
    root._ingressCountThisSec += 1;
    if (notif.urgency === NotificationUrgency.Critical)
      return true;
    return root._ingressCountThisSec <= root.maxIngressPerSecond;
  }
  function _enqueuePopup(wrapper) {
    if (root.notificationQueue.length >= root.maxQueueSize) {
      const gk = root.getGroupKey(wrapper);
      let idx = root.notificationQueue.findIndex(w => w && root.getGroupKey(w) === gk && w.urgency !== NotificationUrgency.Critical);
      if (idx === -1)
        idx = root.notificationQueue.findIndex(w => w && w.urgency !== NotificationUrgency.Critical);
      if (idx === -1)
        idx = 0;
      const victim = root.notificationQueue[idx];
      if (victim)
        victim.popup = false;
      root.notificationQueue.splice(idx, 1);
    }
    root.notificationQueue = [...root.notificationQueue, wrapper];
  }
  function _initWrapperPersistence(wrapper) {
    const timeoutMs = wrapper.timer ? wrapper.timer.interval : 5000;
    const isCritical = wrapper.notification && wrapper.notification.urgency === NotificationUrgency.Critical;
    wrapper.isPersistent = isCritical || (timeoutMs === 0);
  }
  function _trimStored() {
    if (root.notifications.length > root.maxStoredNotifications) {
      const overflow = root.notifications.length - root.maxStoredNotifications;
      const toDrop = [];
      for (let i = root.notifications.length - 1; i >= 0 && toDrop.length < overflow; --i) {
        const w = root.notifications[i];
        if (w && w.notification && w.urgency !== NotificationUrgency.Critical)
          toDrop.push(w);
      }
      for (let i = root.notifications.length - 1; i >= 0 && toDrop.length < overflow; --i) {
        const w = root.notifications[i];
        if (w && w.notification && toDrop.indexOf(w) === -1)
          toDrop.push(w);
      }
      for (const w of toDrop) {
        try {
          w.notification.dismiss();
        } catch (e) {}
      }
    }
  }
  function onOverlayOpen() {
    root.popupsDisabled = true;
    addGate.stop();
    root.addGateBusy = false;
    root.notificationQueue = [];
    for (const w of root.visibleNotifications)
      if (w)
        w.popup = false;
    root.visibleNotifications = [];
    root._recomputeGroupsLater();
  }
  function onOverlayClose() {
    root.popupsDisabled = false;
    root.processQueue();
  }
  Timer {
    id: addGate
    interval: root.enterAnimMs + 50
    running: false
    repeat: false
    onTriggered: {
      root.addGateBusy = false;
      root.processQueue();
    }
  }
  Timer {
    id: timeUpdateTimer
    interval: 30000
    repeat: true
    running: root.allWrappers.length > 0 || root.visibleNotifications.length > 0
    triggeredOnStart: false
    onTriggered: {
      root.timeUpdateTick = !root.timeUpdateTick;
    }
  }
  // Optional lightweight metrics to help track growth; enabled when OBELISK_DEBUG_METRICS=1
  Timer {
    id: metricsTimer
    interval: 60000
    repeat: true
    running: Quickshell.env("OBELISK_DEBUG_METRICS") === "1"
    triggeredOnStart: true
    onTriggered: {
      try {
        Logger.log("NotifMetrics", `wrappers=${root.allWrappers.length}, notifications=${root.notifications.length}, visible=${root.visibleNotifications.length}, queue=${root.notificationQueue.length}`);
      } catch (e) {}
    }
  }
  Timer {
    id: dismissPump
    interval: root._dismissTickMs
    repeat: true
    running: false
    onTriggered: {
      const n = Math.min(root._dismissBatchSize, root._dismissQueue.length);
      for (let i = 0; i < n; ++i) {
        const w = root._dismissQueue.pop();
        try {
          if (w && w.notification)
            w.notification.dismiss();
        } catch (e) {}
      }
      if (root._dismissQueue.length === 0) {
        dismissPump.stop();
        root._suspendGrouping = false;
        root.bulkDismissing = false;
        root.popupsDisabled = false;
        root._recomputeGroupsLater();
      }
    }
  }
  Timer {
    id: groupsDebounce
    interval: 16
    repeat: false
    onTriggered: root._recomputeGroups()
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
        Logger.log("NotificationService", `ingress: id=${notif.id}, app='${notif.appName}', summary='${notif.summary}'`);
      } catch (e) {}
      if (!root._ingressAllowed(notif)) {
        if (notif.urgency !== NotificationUrgency.Critical) {
          try {
            notif.dismiss();
          } catch (e) {}
          try {
            Logger.log("NotificationService", `rate-limited and dismissed: id=${notif.id}`);
          } catch (e) {}
          return;
        }
      }
      const shouldShowPopup = !root.popupsDisabled && !root.dndEnabled();
      const wrapper = notifComponent.createObject(root, {
        "popup": shouldShowPopup,
        "notification": notif
      });
      if (wrapper) {
        root._hydrateWrapper(wrapper);
        root.allWrappers.push(wrapper);
        root.notifications.push(wrapper);
        root._trimStored();
        Qt.callLater(() => {
          root._initWrapperPersistence(wrapper);
          root._hydrateWrapper(wrapper);
        });
        if (shouldShowPopup) {
          root._enqueuePopup(wrapper);
          try {
            Logger.log("NotificationService", `enqueued popup: id=${notif.id}`);
          } catch (e) {}
          root.processQueue();
        }
      }
      root._recomputeGroupsLater();
    }
  }
  component NotifWrapper: QtObject {
    id: wrapper
    property bool popup: false
    property bool removedByLimit: false
    property bool isPersistent: true
    property int seq: 0
    onPopupChanged: {
      if (!popup)
        root.removeFromVisibleNotifications(wrapper);
    }
    readonly property Timer timer: Timer {
      interval: {
        if (!wrapper.notification)
          return 5000;
        return root.getTimeoutForUrgency(wrapper.notification.urgency);
      }
      repeat: false
      running: false
      onTriggered: {
        if (interval > 0)
          wrapper.popup = false;
      }
    }
    readonly property date time: new Date()
    readonly property string timeStr: {
      root.timeUpdateTick;
      root.clockFormatChanged;
      const now = new Date();
      const diff = now.getTime() - time.getTime();
      const minutes = Math.floor(diff / 60000);
      const hours = Math.floor(minutes / 60);
      if (hours < 1) {
        if (minutes < 1)
          return "now";
        return `${minutes}m ago`;
      }
      const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const timeDate = new Date(time.getFullYear(), time.getMonth(), time.getDate());
      const daysDiff = Math.floor((nowDate - timeDate) / (1000 * 60 * 60 * 24));
      if (daysDiff === 0)
        return formatTime(time);
      if (daysDiff === 1)
        return `yesterday, ${formatTime(time)}`;
      return `${daysDiff} days ago`;
    }
    function formatTime(date) {
      const use24Hour = root.safeUse24Hour();
      return use24Hour ? date.toLocaleTimeString(Qt.locale(), "HH:mm") : date.toLocaleTimeString(Qt.locale(), "h:mm AP");
    }
    required property Notification notification
    readonly property string id: String(notification.id)
    readonly property string summary: notification.summary
    readonly property string body: notification.body
    readonly property string htmlBody: {
      if (body && (body.includes("<") && body.includes(">")))
        return body;
      return root.safeMarkdownToHtml(body);
    }
    readonly property string appIcon: notification.appIcon
    readonly property string appName: {
      if (notification.appName == "") {
        const entry = root.safeDesktopLookup(notification.desktopEntry);
        if (entry && entry.name)
          return entry.name.toLowerCase();
      }
      return notification.appName || "app";
    }
    readonly property string desktopEntry: notification.desktopEntry
    readonly property string image: notification.image
    readonly property string cleanImage: image ? root.safeStripPath(image) : ""
    readonly property int urgency: notification.urgency
    readonly property color accentColor: root._accentColorForUrgency(wrapper.urgency)
    readonly property string inlineReplyPlaceholder: notification.inlineReplyPlaceholder || "Reply"
    readonly property bool hasInlineReply: !!notification.hasInlineReply
    readonly property bool hasBody: {
      const bodyText = (wrapper.body || "").trim();
      if (!bodyText)
        return false;
      const summaryText = (wrapper.summary || "").trim();
      return bodyText !== summaryText;
    }
    readonly property bool canExpandBody: hasBody
    property var actions: []
    function sendInlineReply(text) {
      return root._sendInlineReply(wrapper.notification, text);
    }
    readonly property Connections conn: Connections {
      target: wrapper.notification.Retainable
      function onDropped(): void {
        // Ensure this wrapper is no longer displayed as a popup or stuck in the queue
        root.visibleNotifications = root.visibleNotifications.filter(w => w !== wrapper);
        root.notificationQueue = root.notificationQueue.filter(w => w !== wrapper);
        try {
          Logger.log("NotificationService", `dropped: id=${wrapper && wrapper.notification ? wrapper.notification.id : "?"}`);
        } catch (e) {}
        root.allWrappers = root.allWrappers.filter(w => w !== wrapper);
        root.notifications = root.notifications.filter(w => w !== wrapper);
        if (root.bulkDismissing)
          return;
        const gk = root.getGroupKey(wrapper);
        let remaining = 0;
        for (let k = 0; k < root.notifications.length; ++k)
          if (root.getGroupKey(root.notifications[k]) === gk)
            remaining++;
        if (remaining <= 1)
          root.clearGroupExpansionState(gk);
        root.cleanupExpansionStates();
        root._recomputeGroupsLater();
      }
      function onAboutToDestroy(): void {
        wrapper.destroy();
      }
    }
  }
  Component {
    id: notifComponent
    NotifWrapper {}
  }
  function clearAllNotifications() {
    root.bulkDismissing = true;
    root.popupsDisabled = true;
    addGate.stop();
    root.addGateBusy = false;
    root.notificationQueue = [];
    for (const w of root.allWrappers)
      w.popup = false;
    root.visibleNotifications = [];
    root._dismissQueue = root.notifications.slice();
    if (root.notifications.length)
      root.notifications = [];
    root.expandedGroups = {};
    root.expandedMessages = {};
    root._suspendGrouping = true;
    if (!dismissPump.running && root._dismissQueue.length)
      dismissPump.start();
  }
  function dismissNotification(wrapper) {
    if (!wrapper || !wrapper.notification)
      return;
    // Remove immediately from popup list and queue so UI updates even if backend is slow
    root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
    root.notificationQueue = root.notificationQueue.filter(n => n !== wrapper);
    wrapper.popup = false;
    wrapper.notification.dismiss();
    root._recomputeGroupsLater();
  }
  // Centralized action executor to avoid UI components touching notification objects directly
  function executeAction(wrapper, actionId, actionObj) {
    try {
      Logger.log("NotificationService", `executeAction: id=${actionId}`);
    } catch (e) {}
    const notif = wrapper && wrapper.notification ? wrapper.notification : null;
    function _call(obj, name, arg) {
      try {
        const fn = obj && obj[name];
        if (typeof fn === "function")
          return fn.call(obj, arg);
      } catch (e) {}
      return undefined;
    }
    // Prefer action object methods if present
    if (actionObj) {
      if (_call(actionObj, "trigger") !== undefined)
        return;
      if (_call(actionObj, "activate") !== undefined)
        return;
      if (_call(actionObj, "invoke") !== undefined)
        return;
      if (_call(actionObj, "click") !== undefined)
        return;
    }
    // Fallback to notification methods by action id
    if (notif) {
      if (_call(notif, "invokeAction", actionId) !== undefined)
        return;
      if (_call(notif, "activateAction", actionId) !== undefined)
        return;
      if (_call(notif, "triggerAction", actionId) !== undefined)
        return;
      if (_call(notif, "action", actionId) !== undefined)
        return;
      if (_call(notif, "runAction", actionId) !== undefined)
        return;
    }
  }
  function disablePopups(disable) {
    root.popupsDisabled = disable;
    if (disable) {
      root.notificationQueue = [];
      for (const notif of root.visibleNotifications)
        notif.popup = false;
      root.visibleNotifications = [];
    }
  }
  function processQueue() {
    if (root.addGateBusy)
      return;
    if (root.popupsDisabled)
      return;
    if (root.dndEnabled())
      return;
    if (root.notificationQueue.length === 0)
      return;
    const activePopupCount = root.visibleNotifications.filter(n => n && n.popup).length;
    if (activePopupCount >= root.maxVisibleNotifications)
      return;
    const next = root.notificationQueue.shift();
    next.seq = ++root.seqCounter;
    root.visibleNotifications = [...root.visibleNotifications, next];
    next.popup = true;
    if (next.timer.interval > 0)
      next.timer.start();
    try {
      Logger.log("NotificationService", `show popup: id=${next.notification.id}, summary='${next.summary}', timeout=${next.timer.interval}`);
    } catch (e) {}
    root.addGateBusy = true;
    addGate.restart();
    root._recomputeGroupsLater();
  }
  function removeFromVisibleNotifications(wrapper) {
    root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
    try {
      Logger.log("NotificationService", `hide popup: id=${wrapper && wrapper.notification ? wrapper.notification.id : "?"}`);
    } catch (e) {}
    root.processQueue();
    root._recomputeGroupsLater();
  }
  function releaseWrapper(w) {
    root.visibleNotifications = root.visibleNotifications.filter(n => n !== w);
    root.notificationQueue = root.notificationQueue.filter(n => n !== w);
    if (w && w.destroy && !w.isPersistent && root.notifications.indexOf(w) === -1) {
      Qt.callLater(() => {
        try {
          w.destroy();
        } catch (e) {}
      });
    }
  }
  function getGroupKey(wrapper) {
    const de = (wrapper && typeof wrapper.desktopEntry === "string") ? wrapper.desktopEntry : "";
    if (de && de !== "")
      return de.toLowerCase();
    const an = (wrapper && typeof wrapper.appName === "string") ? wrapper.appName : "app";
    return an ? an.toLowerCase() : "app";
  }
  function _recomputeGroups() {
    if (root._suspendGrouping) {
      root._groupsDirty = true;
      return;
    }
    // Prune any zombies left behind (wrapper without notification or summary)
    root.visibleNotifications = root.visibleNotifications.filter(w => w && w.notification && (w.summary !== undefined));
    root.notificationQueue = root.notificationQueue.filter(w => w && w.notification);
    root.allWrappers = root.allWrappers.filter(w => w && w.notification);
    root.notifications = root.notifications.filter(w => w && w.notification);
    root._groupCache = {
      "notifications": root._calcGroupedNotifications(),
      "popups": root._calcGroupedPopups()
    };
    root._groupsDirty = false;
  }
  function _recomputeGroupsLater() {
    root._groupsDirty = true;
    if (!groupsDebounce.running)
      groupsDebounce.start();
  }
  function _calcGroupedNotifications() {
    const groups = {};
    for (const notif of root.notifications) {
      const groupKey = root.getGroupKey(notif);
      if (!groups[groupKey]) {
        groups[groupKey] = {
          "key": groupKey,
          "appName": notif.appName,
          "notifications": [],
          "latestNotification": null,
          "count": 0,
          "hasInlineReply": false
        };
      }
      groups[groupKey].notifications.unshift(notif);
      groups[groupKey].latestNotification = groups[groupKey].notifications[0];
      groups[groupKey].count = groups[groupKey].notifications.length;
      if (notif && notif.notification && notif.notification.hasInlineReply)
        groups[groupKey].hasInlineReply = true;
    }
    return Object.values(groups).sort((a, b) => {
      const aLn = a && a.latestNotification ? a.latestNotification : null;
      const bLn = b && b.latestNotification ? b.latestNotification : null;
      const aUrgency = (aLn && aLn.urgency !== undefined) ? aLn.urgency : NotificationUrgency.Low;
      const bUrgency = (bLn && bLn.urgency !== undefined) ? bLn.urgency : NotificationUrgency.Low;
      if (aUrgency !== bUrgency)
        return bUrgency - aUrgency;
      const at = (aLn && aLn.time && aLn.time.getTime) ? aLn.time.getTime() : 0;
      const bt = (bLn && bLn.time && bLn.time.getTime) ? bLn.time.getTime() : 0;
      return bt - at;
    });
  }
  function _calcGroupedPopups() {
    const groups = {};
    for (const notif of root.visibleNotifications) {
      const groupKey = root.getGroupKey(notif);
      if (!groups[groupKey]) {
        groups[groupKey] = {
          "key": groupKey,
          "appName": notif.appName,
          "notifications": [],
          "latestNotification": null,
          "count": 0,
          "hasInlineReply": false
        };
      }
      groups[groupKey].notifications.unshift(notif);
      groups[groupKey].latestNotification = groups[groupKey].notifications[0];
      groups[groupKey].count = groups[groupKey].notifications.length;
      if (notif && notif.notification && notif.notification.hasInlineReply)
        groups[groupKey].hasInlineReply = true;
    }
    return Object.values(groups).sort((a, b) => {
      const aLn = a && a.latestNotification ? a.latestNotification : null;
      const bLn = b && b.latestNotification ? b.latestNotification : null;
      const at = (aLn && aLn.time && aLn.time.getTime) ? aLn.time.getTime() : 0;
      const bt = (bLn && bLn.time && bLn.time.getTime) ? bLn.time.getTime() : 0;
      return bt - at;
    });
  }
  function toggleGroupExpansion(groupKey) {
    const next = {};
    for (const key in root.expandedGroups)
      next[key] = root.expandedGroups[key];
    next[groupKey] = !next[groupKey];
    root.expandedGroups = next;
  }
  function dismissGroup(groupKey) {
    const group = root.groupedNotifications.find(g => g.key === groupKey);
    if (group) {
      for (const notif of group.notifications)
        if (notif && notif.notification) {
          // Hide popup immediately; onDropped will remove from arrays
          notif.popup = false;
          notif.notification.dismiss();
        }
    } else {
      for (const notif of root.allWrappers)
        if (notif && notif.notification && root.getGroupKey(notif) === groupKey) {
          notif.popup = false;
          notif.notification.dismiss();
        }
    }
  }
  function clearGroupExpansionState(groupKey) {
    const next = {};
    for (const key in root.expandedGroups)
      if (key !== groupKey && root.expandedGroups[key])
        next[key] = true;
    root.expandedGroups = next;
  }
  function cleanupExpansionStates() {
    const currentGroupKeys = new Set(root.groupedNotifications.map(g => g.key));
    const currentMessageIds = new Set();
    for (const group of root.groupedNotifications)
      for (const notif of group.notifications)
        currentMessageIds.add(notif.notification.id);
    const nextGroups = {};
    for (const key in root.expandedGroups)
      if (currentGroupKeys.has(key) && root.expandedGroups[key])
        nextGroups[key] = true;
    root.expandedGroups = nextGroups;
    const nextMessages = {};
    for (const messageId in root.expandedMessages)
      if (currentMessageIds.has(messageId) && root.expandedMessages[messageId])
        nextMessages[messageId] = true;
    root.expandedMessages = nextMessages;
  }
  function toggleMessageExpansion(messageId) {
    const next = {};
    for (const key in root.expandedMessages)
      next[key] = root.expandedMessages[key];
    next[messageId] = !next[messageId];
    root.expandedMessages = next;
  }
  Connections {
    target: typeof OSDService !== "undefined" ? OSDService : null
    function onDoNotDisturbChanged() {
      if (root.dndEnabled()) {
        for (const notif of root.visibleNotifications)
          notif.popup = false;
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
      root.clockFormatChanged = !root.clockFormatChanged;
    }
  }
}
