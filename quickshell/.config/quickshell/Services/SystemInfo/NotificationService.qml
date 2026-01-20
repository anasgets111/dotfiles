pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Config
import qs.Services.SystemInfo
import qs.Services.Utils
import qs.Services.Core

Singleton {
  id: root

  // === Group State Management ===
  property QtObject _groupState: QtObject {
    property var dismissing: ({})
    property var expanded: ({})
    property var shownPopups: ({})

    function clearAll(): void {
      dismissing = ({});
      expanded = ({});
      shownPopups = ({});
    }

    function isDismissing(key: string, scope: string): bool {
      return !!dismissing[`${scope}:${key}`];
    }

    function isExpanded(key: string): bool {
      return !!expanded[key];
    }

    function isNew(key: string): bool {
      return !shownPopups[key];
    }

    function markShown(key: string): void {
      if (shownPopups[key])
        return;
      shownPopups = Object.assign({}, shownPopups, {
        [key]: true
      });
    }

    function pruneShown(activeKeys: var): void {
      const next = {};
      let changed = false;
      for (const key in shownPopups) {
        if (activeKeys.has(key))
          next[key] = true;
        else
          changed = true;
      }
      if (changed)
        shownPopups = next;
    }

    function setDismissing(key: string, scope: string, value: bool): void {
      const scopedKey = `${scope}:${key}`;
      if (!!dismissing[scopedKey] === value)
        return;
      const next = Object.assign({}, dismissing);
      if (value)
        next[scopedKey] = true;
      else
        delete next[scopedKey];
      dismissing = next;
    }

    function toggleExpanded(key: string): void {
      const next = Object.assign({}, expanded);
      next[key] = !next[key];
      expanded = next;
    }
  }
  property var _groupedNotificationsCache: []
  property var _groupedPopupsCache: []

  // === Hide Queue (for popup timeout/dismiss animations) ===
  property var _hideQueue: []

  // === Private State ===
  property bool _isDestroying: false
  property var _popupQueue: []
  property int _sequence: 0

  // === Urgency Configuration ===
  readonly property var _urgencyConfig: ({
      [NotificationUrgency.Low]: {
        timeout: 3000,
        color: Qt.rgba(Theme.disabledColor.r, Theme.disabledColor.g, Theme.disabledColor.b, 0.9)
      },
      [NotificationUrgency.Normal]: {
        timeout: 5000,
        color: Theme.activeColor
      },
      [NotificationUrgency.Critical]: {
        timeout: 0,
        color: "#ff4d4f"
      }
    })
  readonly property int animationDuration: Math.round((Theme.animationDuration || 200) * 1.4)

  // === Public Properties ===
  property bool doNotDisturb: false
  property var expandedGroups: root._groupState.expanded
  readonly property var groupedNotifications: root._groupedNotificationsCache
  readonly property var groupedPopups: root._groupedPopupsCache
  readonly property int maxNotificationsPerApp: 10
  readonly property int maxStoredNotifications: 100
  readonly property int maxVisibleNotifications: 3
  property var notifications: []
  property bool popupsDisabled: false
  property var visibleNotifications: []

  function _clearVisiblePopups(): void {
    if (!root.visibleNotifications.length)
      return;
    root.visibleNotifications.forEach(wrapper => {
      if (wrapper) {
        if (wrapper.timer)
          wrapper.timer.stop();
        wrapper.popup = false;
        wrapper.isHidingPopup = false;
      }
    });
    root.visibleNotifications = [];
  }

  function _compareWrappers(a: QtObject, b: QtObject): int {
    const timeDiff = (b?.createdAt?.getTime() ?? 0) - (a?.createdAt?.getTime() ?? 0);
    return timeDiff !== 0 ? timeDiff : (b?.sequence ?? 0) - (a?.sequence ?? 0);
  }

  function _computeGroups(notificationList: var): var {
    const groups = new Map();
    for (const wrapper of notificationList) {
      if (!wrapper)
        continue;
      const key = wrapper.groupKey;
      let group = groups.get(key);
      if (!group) {
        group = {
          key: key,
          appName: wrapper.appName,
          notifications: [],
          latestNotification: wrapper,
          count: 0,
          urgency: wrapper.urgency,
          _latestTime: wrapper.createdAt?.getTime() ?? 0,
          _latestSeq: wrapper.sequence ?? 0
        };
        groups.set(key, group);
      }
      group.notifications.push(wrapper);
    }

    const result = Array.from(groups.values());
    result.forEach(group => {
      group.notifications.sort(root._compareWrappers);
      group.count = group.notifications.length;
      group.latestNotification = group.notifications[0] || group.latestNotification;
      group.appName = group.latestNotification?.appName || group.appName;
      group.urgency = group.latestNotification?.urgency ?? NotificationUrgency.Normal;
      group._latestTime = group.latestNotification?.createdAt?.getTime() ?? 0;
      group._latestSeq = group.latestNotification?.sequence ?? 0;
    });

    return result.sort((a, b) => {
      const urgDiff = (b.urgency ?? 0) - (a.urgency ?? 0);
      if (urgDiff !== 0)
        return urgDiff;
      const timeDiff = (b._latestTime ?? 0) - (a._latestTime ?? 0);
      if (timeDiff !== 0)
        return timeDiff;
      return (b._latestSeq ?? 0) - (a._latestSeq ?? 0);
    });
  }

  function _enqueuePopup(wrapper: QtObject): void {
    if (!wrapper || wrapper._removed || wrapper.isDismissing || wrapper.isHidingPopup)
      return;
    if (root._popupQueue.includes(wrapper) || root.visibleNotifications.includes(wrapper))
      return;

    let newQueue = [...root._popupQueue];

    if (wrapper.urgency === NotificationUrgency.Critical) {
      const idx = newQueue.findIndex(w => w.urgency !== NotificationUrgency.Critical);
      if (idx === -1)
        newQueue.push(wrapper);
      else
        newQueue.splice(idx, 0, wrapper);

      const activeCount = root.visibleNotifications.filter(w => !w.isHidingPopup && !w.isDismissing).length;

      if (activeCount >= root.maxVisibleNotifications) {
        const victim = root.visibleNotifications.find(w => w.urgency !== NotificationUrgency.Critical && !w.isHidingPopup);
        if (victim) {
          root.hidePopup(victim);
        }
      }
    } else {
      newQueue.push(wrapper);
    }
    root._popupQueue = newQueue;
  }

  function _limitNotificationsPerApp(): void {
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

  function _normalizeActions(notification: var): var {
    const actions = notification?.actions;
    if (!actions?.length)
      return [];
    const seen = new Set();
    const result = [];
    for (let i = 0; i < actions.length; i++) {
      const action = actions[i];
      if (!action || action.isInlineReply)
        continue;
      const id = (action.identifier || "").trim();
      if (!id || seen.has(id))
        continue;
      seen.add(id);
      result.push({
        id,
        title: (action.text || "").trim() || id,
        _obj: action
      });
    }
    return result;
  }

  function _pumpPopups(): void {
    if (root.popupsDisabled || root.doNotDisturb || root._isDestroying)
      return;

    const activeGroups = new Set();
    let activeCount = 0;
    root.visibleNotifications.forEach(w => {
      if (!w || w.isHidingPopup)
        return;
      activeCount++;
      if (!w.isDismissing)
        activeGroups.add(w.groupKey);
    });

    const nextQueue = [];
    const toShow = [];

    for (let i = 0; i < root._popupQueue.length; i++) {
      const w = root._popupQueue[i];
      if (!w || w._removed || w.isDismissing || w.isHidingPopup || root.visibleNotifications.includes(w))
        continue;

      const key = w.groupKey;
      if (activeGroups.has(key)) {
        toShow.push(w);
      } else if (activeGroups.size < root.maxVisibleNotifications) {
        activeGroups.add(key);
        toShow.push(w);
      } else {
        nextQueue.push(w);
      }
    }

    if (toShow.length > 0) {
      root._popupQueue = nextQueue;
      toShow.forEach(w => root._showPopup(w));
    } else if (root._popupQueue.length !== nextQueue.length) {
      root._popupQueue = nextQueue;
    }
  }

  function _queueHide(item: var): void {
    root._hideQueue.push(item);
    if (!hideTimer.running)
      hideTimer.start();
  }

  function _removeWrappers(wrappers: var, removeFromHistory: bool): void {
    const list = (wrappers || []).filter(Boolean);
    if (!list.length)
      return;
    const removeSet = new Set(list);
    list.forEach(w => {
      w.isDismissing = removeFromHistory;
      w.isHidingPopup = false;
      if (w.timer)
        w.timer.stop();
      w.popup = false;
      if (removeFromHistory)
        w._removed = true;
    });

    // Always remove from visible notifications
    root.visibleNotifications = root.visibleNotifications.filter(w => w && !removeSet.has(w));

    // If removing from history, also filter main list and queue
    if (removeFromHistory) {
      root.notifications = root.notifications.filter(w => w && !removeSet.has(w));
      root._popupQueue = root._popupQueue.filter(w => w && !removeSet.has(w));
    }

    // Process specific actions for each wrapper
    list.forEach(w => {
      // If just hiding popup (not removing from history), check if group popup state needs clearing
      if (!removeFromHistory) {
        if (!root.visibleNotifications.some(n => n?.groupKey === w.groupKey && !n.isHidingPopup)) {
          root._groupState.setDismissing(w.groupKey, "popup", false);
        }
      } else {
        // Full removal logic
        if (!root.notifications.some(n => n?.groupKey === w.groupKey && !n.isDismissing)) {
          root._groupState.setDismissing(w.groupKey, "history", false);
        }
        root._groupState.setDismissing(w.groupKey, "popup", false);

        if (w.notification?.valid) {
          w.notification.tracked = false;
          w.notification.dismiss();
        } else if (w.notification) {
          w.notification.tracked = false;
        }
        w.destroy();
      }
    });

    if (root && !root._isDestroying)
      root._pumpPopups();
  }

  function _scheduleGroupUpdate(): void {
    if (!root._isDestroying)
      _groupUpdateDebounce.restart();
  }

  function _showPopup(wrapper: QtObject): void {
    if (!wrapper || wrapper._removed || wrapper.isDismissing || wrapper.isHidingPopup || root._isDestroying)
      return;
    if (root.visibleNotifications.includes(wrapper))
      return;
    root.visibleNotifications = [...root.visibleNotifications, wrapper];
    wrapper.popup = true;
    if (wrapper.timer) {
      wrapper.timer.stop();
      if (wrapper.timer.interval > 0)
        wrapper.timer.start();
    }
  }

  function _trimStoredNotifications(): void {
    if (root.notifications.length <= root.maxStoredNotifications)
      return;
    const overflow = root.notifications.length - root.maxStoredNotifications;
    const toDrop = new Set();
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

  function _updateGroupCaches(): void {
    if (root._isDestroying)
      return;
    root._groupedNotificationsCache = root._computeGroups(root.notifications);
    root._groupedPopupsCache = root._computeGroups(root.visibleNotifications);
    const activeKeys = new Set();
    root._groupedPopupsCache.forEach(g => activeKeys.add(g.key));
    root._groupState.pruneShown(activeKeys);
  }

  function clearAllNotifications(): void {
    root.popupsDisabled = true;
    root._popupQueue = [];
    root._hideQueue = [];
    root._clearVisiblePopups();
    const toDestroy = root.notifications.slice();
    root.notifications = [];
    root._groupState.clearAll();
    root._sequence = 0;
    if (toDestroy.length)
      root._removeWrappers(toDestroy, true);
    Qt.callLater(() => {
      if (root && !root._isDestroying)
        root.popupsDisabled = false;
    });
  }

  function dismissGroup(groupKey: string): void {
    const key = (groupKey || "").trim();
    if (!key)
      return;
    const wrappers = root.notifications.filter(w => w && !w._removed && w.groupKey === key);
    if (!wrappers.length)
      return;
    wrappers.forEach(w => {
      if (!w.isDismissing) {
        w.isDismissing = true;
        if (w.timer)
          w.timer.stop();
        w.popup = false;
        if (root.visibleNotifications.includes(w))
          w.isHidingPopup = true;
      }
    });
    const scopes = ["history"];
    if (root.groupedPopups.some(g => g.key === key))
      scopes.push("popup");
    scopes.forEach(scope => root._groupState.setDismissing(key, scope, true));
    root._queueHide({
      wrappers: wrappers,
      removeFromHistory: true,
      groupKey: key,
      scopes: scopes
    });
  }

  function dismissNotification(wrapper: QtObject): void {
    if (!wrapper || wrapper.isDismissing || wrapper._removed)
      return;
    const groupKey = wrapper.groupKey;
    const inPopup = root.visibleNotifications.includes(wrapper);
    const remainingHistory = root.notifications.filter(n => n && n !== wrapper && !n.isDismissing && !n._removed && n.groupKey === groupKey).length;
    const remainingPopup = inPopup ? root.visibleNotifications.filter(n => n && n !== wrapper && !n.isDismissing && !n.isHidingPopup && !n._removed && n.groupKey === groupKey).length : 0;
    wrapper.isDismissing = true;
    if (wrapper.timer)
      wrapper.timer.stop();
    wrapper.popup = false;
    const scopes = [];
    if (remainingHistory === 0)
      scopes.push("history");
    if (inPopup && remainingPopup === 0)
      scopes.push("popup");
    scopes.forEach(scope => root._groupState.setDismissing(groupKey, scope, true));
    if (inPopup)
      wrapper.isHidingPopup = true;
    root._queueHide({
      wrappers: [wrapper],
      removeFromHistory: true,
      groupKey: scopes.length ? groupKey : "",
      scopes: scopes
    });
  }

  function dismissNotificationsByAppName(appName: string): void {
    const target = (appName || "").trim();
    if (!target)
      return;
    const toRemove = root.notifications.filter(w => w && w.appName === target);
    if (toRemove.length)
      root._removeWrappers(toRemove, true);
  }

  function executeAction(wrapper: QtObject, actionId: string, actionObj: var): void {
    if (actionObj?.invoke) {
      actionObj.invoke();
      return;
    }
    wrapper?.notification?.invokeAction(actionId);
  }

  function getAccentColor(urgency: int): color {
    return root._urgencyConfig[urgency]?.color ?? Theme.activeColor;
  }

  function getTimeoutForUrgency(urgency: int): int {
    return root._urgencyConfig[urgency]?.timeout ?? 5000;
  }

  function hidePopup(wrapper: QtObject): void {
    if (!wrapper || wrapper._removed || wrapper.isHidingPopup || wrapper.isDismissing || root._isDestroying)
      return;
    if (!root.visibleNotifications.includes(wrapper))
      return;
    wrapper.isHidingPopup = true;
    if (wrapper.timer)
      wrapper.timer.stop();
    wrapper.popup = false;
    const groupKey = wrapper.groupKey;
    const remainingPopup = root.visibleNotifications.filter(n => n && n !== wrapper && !n.isDismissing && !n.isHidingPopup && !n._removed && n.groupKey === groupKey).length;
    if (remainingPopup === 0)
      root._groupState.setDismissing(groupKey, "popup", true);
    root._queueHide({
      wrappers: [wrapper],
      removeFromHistory: false,
      groupKey: remainingPopup === 0 ? groupKey : ""
    });
  }

  function isGroupDismissing(key: string, scope: string): bool {
    return root._groupState.isDismissing(key || "", scope || "history");
  }

  function isPopupNew(key: string): bool {
    return root._groupState.isNew(key || "");
  }

  function markPopupShown(key: string): void {
    root._groupState.markShown(key || "");
  }

  function onOverlayClose(): void {
    Qt.callLater(() => {
      if (root && !root._isDestroying) {
        root.popupsDisabled = false;
        root._pumpPopups();
      }
    });
  }

  function onOverlayOpen(): void {
    root.popupsDisabled = true;
    root._clearVisiblePopups();
  }

  function toggleDnd(): void {
    root.doNotDisturb = !root.doNotDisturb;
    if (root.doNotDisturb)
      root._clearVisiblePopups();
    else
      root._pumpPopups();
  }

  function toggleGroupExpansion(groupKey: string): void {
    root._groupState.toggleExpanded(groupKey || "");
  }

  function use24Hour(): bool {
    return typeof TimeService !== "undefined" ? TimeService.use24Hour : true;
  }

  Component.onDestruction: {
    root._isDestroying = true;
    hideTimer.stop();
    _groupUpdateDebounce.stop();
    root._popupQueue = [];
    root._hideQueue = [];
    root.notifications.forEach(wrapper => {
      if (wrapper) {
        if (wrapper.timer)
          wrapper.timer.stop();
        wrapper.destroy();
      }
    });
  }
  onNotificationsChanged: root._scheduleGroupUpdate()
  onVisibleNotificationsChanged: root._scheduleGroupUpdate()

  Timer {
    id: hideTimer

    interval: root.animationDuration
    repeat: false

    onTriggered: {
      if (root._isDestroying || root._hideQueue.length === 0)
        return;
      const item = root._hideQueue.shift();
      root._removeWrappers(item.wrappers, item.removeFromHistory);
      if (item.groupKey && item.scopes) {
        item.scopes.forEach(scope => root._groupState.setDismissing(item.groupKey, scope, false));
      }
      if (root._hideQueue.length > 0)
        hideTimer.restart();
    }
  }

  Timer {
    id: _groupUpdateDebounce

    interval: 16
    repeat: false

    onTriggered: {
      if (!root._isDestroying)
        root._updateGroupCaches();
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

    onNotification: notif => {
      if (root._isDestroying)
        return;

      if (notif.urgency === NotificationUrgency.Critical)
        AudioService.playCriticalNotificationSound();
      else
        AudioService.playNormalNotificationSound();

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
      root._limitNotificationsPerApp();
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
    readonly property var bodyMeta: Markdown2Html.toDisplay(wrapper.body)
    readonly property url cleanImage: Utils.normalizeImageUrl(String(notification?.image || ""))
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
    readonly property date createdAt: new Date()
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
    readonly property string id: String(notification?.id || "")
    readonly property string inlineReplyPlaceholder: notification?.inlineReplyPlaceholder || "Reply"
    property bool isDismissing: false
    property bool isHidingPopup: false
    required property Notification notification
    property bool popup: false
    property int sequence: 0
    readonly property string summary: notification?.summary || ""
    readonly property Timer timer: Timer {
      interval: root.getTimeoutForUrgency(wrapper.urgency)
      repeat: false
      running: false

      onTriggered: {
        if (wrapper.timer.interval > 0 && wrapper.popup && !wrapper.isDismissing && !wrapper.isHidingPopup && !wrapper._removed && !root._isDestroying)
          root.hidePopup(wrapper);
      }
    }
    readonly property int urgency: notification?.urgency || NotificationUrgency.Normal

    function sendInlineReply(text: string): bool {
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
      if (!wrapper.popup && !wrapper.isDismissing && !wrapper.isHidingPopup && !wrapper._removed && !root._isDestroying) {
        if (root.visibleNotifications.includes(wrapper))
          root.visibleNotifications = root.visibleNotifications.filter(w => w !== wrapper);
        Qt.callLater(() => {
          if (root && !root._isDestroying)
            root._pumpPopups();
        });
      }
    }
  }
}
