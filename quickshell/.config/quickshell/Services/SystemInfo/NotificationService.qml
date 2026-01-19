pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: root

  property var _dismissingGroupKeys: ({})
  property Timer _groupUpdateDebounce: Timer {
    interval: 16
    repeat: false

    onTriggered: root._updateGroupCaches()
  }
  property var _groupedNotificationsCache: []
  property var _groupedPopupsCache: []
  property bool _isDestroying: false
  property bool _popupGateBusy: false
  property var _popupQueue: []
  property int _popupQueueIndex: 0
  property var _popupQueueSet: new Set()
  property int _sequence: 0
  property var _shownPopupKeys: ({})
  property var _visibleSet: new Set()
  readonly property int animationDuration: Math.round((Theme.animationDuration || 200) * 1.4)
  property bool doNotDisturb: false
  property var expandedGroups: ({})
  readonly property var groupedNotifications: root._groupedNotificationsCache
  readonly property var groupedPopups: root._groupedPopupsCache
  readonly property var inlineReplyIds: ["inline-reply", "inline_reply", "inline reply", "quick_reply", "quick-reply", "reply", "reply_inline", "reply-inline"]
  readonly property int maxNotificationsPerApp: 10
  readonly property int maxStoredNotifications: 100
  readonly property int maxVisibleNotifications: 3
  property var notifications: []
  property bool popupsDisabled: false
  readonly property int timeoutCritical: 0
  readonly property int timeoutLow: 3000
  readonly property int timeoutNormal: 5000
  property var visibleNotifications: []

  function _clearGroupDismissing(groupKey, scopes) {
    const list = Array.isArray(scopes) && scopes.length ? scopes : ["history"];
    const next = Object.assign({}, root._dismissingGroupKeys);
    for (const scope of list) {
      const scopedKey = root._scopedGroupKey(groupKey, scope);
      if (scopedKey)
        delete next[scopedKey];
    }
    root._dismissingGroupKeys = next;
  }

  function _clearVisiblePopups() {
    if (!root.visibleNotifications.length)
      return;
    for (const wrapper of root.visibleNotifications) {
      if (wrapper) {
        wrapper.timer?.stop();
        wrapper.popup = false;
      }
    }
    root._setVisibleNotifications([]);
  }

  function _compareWrappers(a, b) {
    const timeDiff = (b?.time?.getTime() ?? 0) - (a?.time?.getTime() ?? 0);
    return timeDiff || ((b?.sequence ?? 0) - (a?.sequence ?? 0));
  }

  function _computeGroups(notificationList) {
    const groups = new Map();
    for (const wrapper of notificationList) {
      if (!wrapper)
        continue;
      const key = wrapper.groupKey;
      let group = groups.get(key);
      if (!group) {
        group = {
          key,
          appName: wrapper.appName,
          notifications: [],
          latestNotification: wrapper,
          count: 0,
          urgency: wrapper.urgency,
          _latestTime: wrapper.time?.getTime() ?? 0,
          _latestSeq: wrapper.sequence ?? 0
        };
        groups.set(key, group);
      }
      group.notifications.push(wrapper);
    }

    const result = [];
    for (const group of groups.values()) {
      group.notifications.sort(root._compareWrappers);
      group.count = group.notifications.length;
      group.latestNotification = group.notifications[0] || group.latestNotification;
      group.appName = group.latestNotification?.appName || group.appName;
      group.urgency = group.latestNotification?.urgency ?? NotificationUrgency.Normal;
      group._latestTime = group.latestNotification?.time?.getTime() ?? 0;
      group._latestSeq = group.latestNotification?.sequence ?? 0;
      result.push(group);
    }

    return result.sort((a, b) => {
      const urgDiff = (b.urgency ?? 0) - (a.urgency ?? 0);
      if (urgDiff)
        return urgDiff;
      const timeDiff = (b._latestTime ?? 0) - (a._latestTime ?? 0);
      if (timeDiff)
        return timeDiff;
      return (b._latestSeq ?? 0) - (a._latestSeq ?? 0);
    });
  }

  function _dequeuePopup() {
    while (root._popupQueueIndex < root._popupQueue.length) {
      const candidate = root._popupQueue[root._popupQueueIndex++];
      if (!candidate || !root._popupQueueSet.has(candidate))
        continue;
      root._popupQueueSet.delete(candidate);
      if (!candidate._removed && !candidate.isDismissing && !root._visibleSet.has(candidate))
        return candidate;
    }
    root._popupQueue = [];
    root._popupQueueIndex = 0;
    root._popupQueueSet.clear();
    return null;
  }

  function _enqueuePopup(wrapper) {
    if (!wrapper || wrapper._removed || wrapper.isDismissing)
      return;
    if (root._popupQueueSet.has(wrapper) || root._visibleSet.has(wrapper))
      return;
    root._popupQueueSet.add(wrapper);
    root._popupQueue.push(wrapper);
  }

  function _filterList(list, removeSet) {
    if (!removeSet?.size)
      return list;
    const next = [];
    for (const item of list) {
      if (item && !removeSet.has(item))
        next.push(item);
    }
    return next;
  }

  function _finishDismiss(groupKey, scopes, wrappers) {
    if (groupKey)
      root._clearGroupDismissing(groupKey, scopes);
    root._removeWrappers(wrappers, true);
  }

  function _isAnyGroupDismissing(groupKey) {
    const key = String(groupKey || "").trim();
    if (!key)
      return false;
    return !!(root._dismissingGroupKeys[`popup:${key}`] || root._dismissingGroupKeys[`history:${key}`]);
  }

  function _limitNotificationsPerApp() {
    const appCounts = {};
    const toRemove = [];
    for (const wrapper of root.notifications) {
      if (!wrapper)
        continue;
      const appKey = wrapper.groupKey;
      appCounts[appKey] = (appCounts[appKey] || 0) + 1;
      if (appCounts[appKey] > root.maxNotificationsPerApp && wrapper.urgency !== NotificationUrgency.Critical && wrapper.notification) {
        toRemove.push(wrapper);
      }
    }
    if (toRemove.length)
      root._removeWrappers(toRemove, true);
  }

  function _normalizeActions(notification) {
    const actions = notification?.actions;
    if (!actions)
      return [];

    const length = Array.isArray(actions) ? actions.length : Number(actions.length || actions.count || 0);
    if (!length || Number.isNaN(length))
      return [];

    const list = Array.from({
      length
    }, (_, i) => actions[i]).filter(Boolean);
    if (!list.length)
      return [];

    const seen = new Set();
    const hasInline = notification?.hasInlineReply === true;
    const placeholderKey = (notification?.inlineReplyPlaceholder || "").trim().toLowerCase();

    return list.reduce((result, action) => {
      const identifier = (action.identifier || action.id || action.name || "").trim();
      const label = (action.text || action.title || action.label || identifier).trim();
      const idKey = identifier.toLowerCase();
      const labelKey = label.toLowerCase();

      // Skip inline reply actions (strict check - external data may have truthy non-boolean values)
      if (action.isInlineReply === true || (hasInline && (root.inlineReplyIds.includes(idKey) || root.inlineReplyIds.includes(labelKey) || (placeholderKey && labelKey === placeholderKey))))
        return result;

      const id = identifier || label || `action-${result.length}`;
      if (seen.has(id.toLowerCase()))
        return result;

      seen.add(id.toLowerCase());
      result.push({
        id,
        title: label || id,
        _obj: action
      });
      return result;
    }, []);
  }

  function _pumpPopups() {
    if (root._popupGateBusy || root.popupsDisabled || root.doNotDisturb)
      return;
    if (root.visibleNotifications.length >= root.maxVisibleNotifications)
      return;
    const next = root._dequeuePopup();
    if (!next)
      return;
    root._showPopup(next);
  }

  function _removeWrappers(wrappers, dismissNotification = true) {
    const list = (wrappers || []).filter(Boolean);
    if (!list.length)
      return;
    const removeSet = new Set(list);
    for (const wrapper of removeSet) {
      root._popupQueueSet.delete(wrapper);
      root._visibleSet.delete(wrapper);
      wrapper.isDismissing = true;
      wrapper.timer?.stop();
      wrapper.popup = false;
      wrapper._removed = true;
    }
    root.notifications = root._filterList(root.notifications, removeSet);
    root._setVisibleNotifications(root._filterList(root.visibleNotifications, removeSet));
    for (const wrapper of removeSet) {
      if (dismissNotification) {
        if (wrapper.notification?.valid) {
          wrapper.notification.tracked = false;
          wrapper.notification.dismiss();
        } else if (wrapper.notification) {
          wrapper.notification.tracked = false;
        }
      }
      wrapper.destroy();
    }
    if (root && !root._isDestroying)
      root._pumpPopups();
  }

  function _resetPopupGate() {
    popupGate.stop();
    root._popupGateBusy = false;
  }

  function _scheduleGroupUpdate() {
    root._groupUpdateDebounce.restart();
  }

  function _scopedGroupKey(groupKey, scope) {
    const key = String(groupKey || "").trim();
    if (!key)
      return "";
    return `${scope || "history"}:${key}`;
  }

  function _setGroupDismissing(groupKey, scope, value) {
    const scopedKey = root._scopedGroupKey(groupKey, scope);
    if (!scopedKey)
      return;
    const next = Object.assign({}, root._dismissingGroupKeys);
    if (value)
      next[scopedKey] = true;
    else
      delete next[scopedKey];
    root._dismissingGroupKeys = next;
  }

  function _setVisibleNotifications(list) {
    root.visibleNotifications = list;
    const nextSet = new Set();
    for (const item of list) {
      if (item)
        nextSet.add(item);
    }
    root._visibleSet = nextSet;
  }

  function _showPopup(wrapper) {
    if (!wrapper || wrapper._removed || wrapper.isDismissing)
      return;
    if (root._visibleSet.has(wrapper))
      return;
    root._setVisibleNotifications(root.visibleNotifications.concat(wrapper));
    wrapper.popup = true;
    wrapper.timer?.stop();
    if (wrapper.timer.interval > 0)
      wrapper.timer.start();
    root._popupGateBusy = true;
    popupGate.restart();
  }

  function _trimStoredNotifications() {
    if (root.notifications.length <= root.maxStoredNotifications)
      return;

    const overflow = root.notifications.length - root.maxStoredNotifications;
    const toDrop = new Set();

    // First pass: non-critical from end
    for (let i = root.notifications.length - 1; i >= 0 && toDrop.size < overflow; i--) {
      const notif = root.notifications[i];
      if (notif?.notification && notif.urgency !== NotificationUrgency.Critical)
        toDrop.add(notif);
    }
    for (let i = root.notifications.length - 1; i >= 0 && toDrop.size < overflow; i--) {
      const notif = root.notifications[i];
      if (notif?.notification && !toDrop.has(notif))
        toDrop.add(notif);
    }
    if (toDrop.size)
      root._removeWrappers(Array.from(toDrop), true);
  }

  function _updateGroupCaches() {
    root._groupedNotificationsCache = root._computeGroups(root.notifications);
    root._groupedPopupsCache = root._computeGroups(root.visibleNotifications);

    // Clean up stale popup keys for groups no longer visible
    const activeKeys = new Set();
    for (const g of root._groupedPopupsCache)
      activeKeys.add(g.key);
    const nextShown = {};
    for (const key in root._shownPopupKeys) {
      if (activeKeys.has(key))
        nextShown[key] = true;
    }
    root._shownPopupKeys = nextShown;
  }

  function clearAllNotifications() {
    root.popupsDisabled = true;
    root._resetPopupGate();
    root._popupQueue = [];
    root._popupQueueIndex = 0;
    root._popupQueueSet.clear();
    root._clearVisiblePopups();
    const toDestroy = root.notifications.slice();
    root.notifications = [];
    root.expandedGroups = {};
    root._shownPopupKeys = {};
    root._dismissingGroupKeys = {};
    if (toDestroy.length)
      root._removeWrappers(toDestroy, true);

    Qt.callLater(() => {
      if (root && !root._isDestroying)
        root.popupsDisabled = false;
    });
  }

  function dismissGroup(groupKey) {
    const key = String(groupKey || "").trim();
    if (!key || root._isAnyGroupDismissing(key))
      return;

    const wrappers = [];
    for (const wrapper of root.notifications) {
      if (!wrapper)
        continue;
      const wrapperKey = wrapper.groupKey;
      if (wrapperKey !== key)
        continue;
      if (!wrapper.isDismissing) {
        wrapper.isDismissing = true;
        wrapper.timer?.stop();
      }
      root._popupQueueSet.delete(wrapper);
      wrappers.push(wrapper);
    }
    if (!wrappers.length)
      return;

    const scopes = ["history"];
    if (root.groupedPopups.some(g => g.key === key))
      scopes.push("popup");
    for (const scope of scopes)
      root._setGroupDismissing(key, scope, true);

    dismissAnimTimer.createObject(root, {
      groupKey: key,
      scopes,
      wrappers
    });
  }

  function dismissNotification(wrapper) {
    if (!wrapper || wrapper.isDismissing)
      return;

    const groupKey = wrapper.groupKey;
    if (root._isAnyGroupDismissing(groupKey))
      return;

    let remainingHistory = 0;
    for (const notif of root.notifications) {
      if (!notif || notif === wrapper || notif.isDismissing)
        continue;
      const notifKey = notif.groupKey;
      if (notifKey === groupKey)
        remainingHistory++;
    }

    const inPopup = root._visibleSet.has(wrapper);
    let remainingPopup = 0;
    if (inPopup) {
      for (const notif of root.visibleNotifications) {
        if (!notif || notif === wrapper || notif.isDismissing)
          continue;
        const notifKey = notif.groupKey;
        if (notifKey === groupKey)
          remainingPopup++;
      }
    }

    wrapper.isDismissing = true;
    wrapper.timer?.stop();
    root._popupQueueSet.delete(wrapper);

    const scopes = [];
    if (remainingHistory === 0)
      scopes.push("history");
    if (inPopup && remainingPopup === 0)
      scopes.push("popup");
    for (const scope of scopes)
      root._setGroupDismissing(groupKey, scope, true);

    dismissAnimTimer.createObject(root, {
      groupKey: scopes.length ? groupKey : "",
      scopes,
      wrappers: [wrapper]
    });
  }

  function dismissNotificationsByAppName(appName) {
    const target = String(appName).trim();
    if (!target)
      return;
    const toRemove = [];
    for (const wrapper of root.notifications) {
      if (wrapper?.appName === target)
        toRemove.push(wrapper);
    }
    if (toRemove.length)
      root._removeWrappers(toRemove, true);
  }

  function executeAction(wrapper, actionId, actionObj) {
    const notif = wrapper?.notification;
    if (!notif)
      return;

    const methods = actionObj ? [() => actionObj.trigger(), () => actionObj.activate(), () => actionObj.invoke(), () => actionObj.click()] : [];
    methods.push(() => notif.invokeAction(actionId), () => notif.activateAction(actionId), () => notif.triggerAction(actionId), () => notif.action(actionId));

    for (const method of methods) {
      try {
        if (method() !== undefined)
          return;
      } catch (e) {}
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

  function isGroupDismissing(key, scope = "history") {
    const scopedKey = root._scopedGroupKey(key, scope);
    return scopedKey ? !!root._dismissingGroupKeys[scopedKey] : false;
  }

  function isPopupNew(key) {
    return !root._shownPopupKeys[key];
  }

  function markPopupShown(key) {
    root._shownPopupKeys[key] = true;
  }

  function onOverlayClose() {
    Qt.callLater(() => {
      if (root && !root._isDestroying) {
        root.popupsDisabled = false;
        root._pumpPopups();
      }
    });
  }

  function onOverlayOpen() {
    root.popupsDisabled = true;
    root._resetPopupGate();
    root._clearVisiblePopups();
  }

  function prepareBody(raw) {
    if (typeof raw !== "string" || !raw)
      return {
        text: "",
        format: Qt.PlainText
      };

    // Try markdown conversion first (separate try-catch for fallback to URL linking)
    try {
      if (typeof Markdown2Html !== "undefined" && Markdown2Html.toDisplay) {
        const result = Markdown2Html.toDisplay(raw);
        if (result?.format === Qt.RichText)
          return result;
      }
    } catch (e) {}

    // Fallback: escape HTML and convert URLs to links
    try {
      const escaped = raw.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
      const urlRegex = /((?:https?|file):\/\/[^\s<>'\"]*)/gi;
      let hasUrl = false;
      const html = escaped.replace(urlRegex, m => {
        hasUrl = true;
        return `<a href="${m}">${m}</a>`;
      });
      return hasUrl ? {
        text: html,
        format: Qt.RichText
      } : {
        text: raw,
        format: Qt.PlainText
      };
    } catch (e) {
      return {
        text: raw,
        format: Qt.PlainText
      };
    }
  }

  function toggleDnd() {
    root.doNotDisturb = !root.doNotDisturb;
    if (root.doNotDisturb) {
      root._resetPopupGate();
      root._clearVisiblePopups();
    } else {
      root._pumpPopups();
    }
  }

  function toggleGroupExpansion(groupKey) {
    const next = Object.assign({}, root.expandedGroups);
    next[groupKey] = !next[groupKey];
    root.expandedGroups = next;
  }

  function use24Hour() {
    return typeof TimeService !== "undefined" ? TimeService.use24Hour : true;
  }

  Component.onDestruction: {
    root._isDestroying = true;
    updateTimer.stop();
    root._resetPopupGate();
    root._popupQueue = [];
    root._popupQueueIndex = 0;
    root._popupQueueSet.clear();
    root._visibleSet = new Set();
    for (const wrapper of root.notifications) {
      if (wrapper) {
        wrapper.timer?.stop();
        wrapper.destroy();
      }
    }
  }
  onNotificationsChanged: root._scheduleGroupUpdate()
  onVisibleNotificationsChanged: root._scheduleGroupUpdate()

  Timer {
    id: updateTimer

    interval: 30000
    repeat: true
    running: root.notifications.length > 0 || root.visibleNotifications.length > 0

    onTriggered: {
      root._scheduleGroupUpdate(); // Triggers time display updates via cache rebuild
      root._limitNotificationsPerApp();
      if (root.notifications.length > root.maxStoredNotifications) {
        root._trimStoredNotifications();
      }
    }
  }

  Timer {
    id: popupGate

    interval: root.animationDuration + 50
    repeat: false
    running: false

    onTriggered: {
      root._popupGateBusy = false;
      root._pumpPopups();
    }
  }

  NotificationServer {
    id: server

    actionIconsSupported: true
    actionsSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    bodyMarkupSupported: true
    imageSupported: true
    inlineReplySupported: true
    keepOnReload: false
    persistenceSupported: true

    Component.onCompleted: {
      root.notifications = root.notifications.filter(w => {
        if (w?.notification?.valid)
          return true;
        w?.destroy();
        return false;
      });
      for (const wrapper of root.notifications) {
        if (wrapper && !wrapper.sequence) {
          root._sequence += 1;
          wrapper.sequence = root._sequence;
        }
      }
      root._setVisibleNotifications(root.visibleNotifications.filter(w => w?.notification?.valid));
      const queued = root._popupQueue.filter(w => w?.notification?.valid);
      root._popupQueue = queued;
      root._popupQueueIndex = 0;
      root._popupQueueSet = new Set(queued);
    }
    onNotification: notif => {
      notif.tracked = true;
      root._sequence += 1;
      const wrapper = notifComponent.createObject(null, {
        notification: notif,
        sequence: root._sequence
      });
      if (!wrapper)
        return;
      root.notifications = [wrapper, ...root.notifications];
      root._trimStoredNotifications();
      if (!root.popupsDisabled && !root.doNotDisturb)
        root._enqueuePopup(wrapper);
      root._pumpPopups();
    }
  }

  Component {
    id: notifComponent

    NotifWrapper {
    }
  }

  Component {
    id: dismissAnimTimer

    Timer {
      required property string groupKey
      required property var scopes
      required property var wrappers

      interval: root.animationDuration
      running: true

      onTriggered: {
        root._finishDismiss(groupKey, scopes, wrappers);
        destroy();
      }
    }
  }

  Connections {
    function onUse24HourChanged() {
      root._scheduleGroupUpdate();
    }

    target: typeof TimeService !== "undefined" ? TimeService : null
  }

  component NotifWrapper: QtObject {
    id: wrapper

    property bool _removed: false
    readonly property color accentColor: root.getAccentColor(wrapper.urgency)
    readonly property var actions: root._normalizeActions(wrapper.notification)
    readonly property string appIcon: notification?.appIcon || ""
    readonly property string appName: notification?.appName || "app"
    readonly property string body: notification?.body || ""
    readonly property var bodyMeta: root.prepareBody(wrapper.body)
    readonly property url cleanImage: {
      const img = String(notification?.image || "");
      if (!img)
        return "";
      if (img.startsWith("file://"))
        return img;
      if (img.startsWith("/"))
        return "file://" + img;
      return img;
    }
    readonly property Connections closeConn: Connections {
      function onClosed(_) {
        if (root._isDestroying || wrapper._removed)
          return;
        root._removeWrappers([wrapper], false);
      }

      enabled: !wrapper._removed && !!target
      target: wrapper.notification || null
    }
    readonly property Connections conn: Connections {
      function onDropped() {
        if (root._isDestroying || wrapper.isDismissing || wrapper._removed)
          return;
        root._removeWrappers([wrapper], false);
      }

      enabled: !wrapper.isDismissing && !wrapper._removed && !!target
      target: wrapper.notification?.Retainable || null
    }
    readonly property string desktopEntry: notification?.desktopEntry || ""
    readonly property string groupKey: {
      const de = (wrapper.desktopEntry || "").trim().toLowerCase();
      return de ? de : (wrapper.appName || "app").toLowerCase();
    }
    readonly property bool hasBody: {
      const bodyText = (wrapper.body || "").trim();
      const summaryText = (wrapper.summary || "").trim();
      return bodyText && bodyText !== summaryText;
    }
    readonly property bool hasInlineReply: notification?.hasInlineReply || false
    readonly property string historyTimeStr: {
      root.groupedNotifications;
      const format = root.use24Hour() ? "ddd HH:mm" : "ddd h:mm AP";
      let formatted = Qt.formatDateTime(wrapper.time, format);
      if (!root.use24Hour())
        formatted = formatted.replace(" AM", "am").replace(" PM", "pm");
      return formatted;
    }
    readonly property string id: String(notification?.id || "")
    readonly property string inlineReplyPlaceholder: notification?.inlineReplyPlaceholder || "Reply"
    property bool isDismissing: false
    required property Notification notification
    property bool popup: false
    property int sequence: 0
    readonly property string summary: notification?.summary || ""
    readonly property date time: new Date()
    readonly property Timer timer: Timer {
      interval: root.getTimeoutForUrgency(wrapper.urgency)
      repeat: false
      running: false

      onTriggered: {
        if (wrapper.timer.interval > 0 && wrapper.popup && !wrapper.isDismissing)
          root.dismissNotification(wrapper);
      }
    }
    readonly property int urgency: notification?.urgency || NotificationUrgency.Normal

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
      if (!wrapper.popup && !wrapper.isDismissing && !wrapper._removed) {
        if (root._visibleSet.has(wrapper))
          root._setVisibleNotifications(root._filterList(root.visibleNotifications, new Set([wrapper])));
        Qt.callLater(() => {
          if (root && !root._isDestroying)
            root._pumpPopups();
        });
      }
    }
  }
}
