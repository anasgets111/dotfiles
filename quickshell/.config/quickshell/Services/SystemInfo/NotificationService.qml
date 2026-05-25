pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Config
import qs.Services.Core
import qs.Services.SystemInfo
import qs.Services.Utils

Singleton {
  id: root

  readonly property GroupState _groupState: GroupState {}
  property var _groupedNotificationsCache: []
  property var _groupedPopupsCache: []
  property bool _isDestroying: false
  property bool _popupsSuspended: false
  property var _popupOnlyWrappers: []
  property var _popupQueue: []
  property var _removalQueue: []
  property int _sequence: 0

  readonly property int animationDuration: Math.round((Theme.animationDuration || 200) * 1.4)
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

  property bool doNotDisturb: false
  readonly property var expandedGroups: root._groupState.expanded
  readonly property var groupedNotifications: root._groupedNotificationsCache
  readonly property var groupedPopups: root._groupedPopupsCache
  readonly property int maxNotificationsPerApp: 10
  readonly property int maxStoredNotifications: 100
  readonly property int maxVisibleNotifications: 3
  property var notifications: []
  property var visibleNotifications: []

  function _visiblePopupCount(): int {
    return root.visibleNotifications.filter(wrapper => wrapper && !wrapper._removed && !wrapper.isHidingPopup && !wrapper.isDismissing).length;
  }

  function _allWrappers(): var {
    return root._uniqueWrappers([root.notifications, root.visibleNotifications, root._popupQueue, root._popupOnlyWrappers]);
  }

  function _clearVisiblePopups(): void {
    root.visibleNotifications.forEach(wrapper => {
      if (!wrapper)
        return;
      root._stopWrapperTimer(wrapper);
      wrapper.popup = false;
      wrapper.isHidingPopup = false;
    });
    root.visibleNotifications = [];
  }

  function _closeNotification(wrapper: var, closeReason: string): void {
    const notification = wrapper?.notification;
    if (!notification?.valid)
      return;
    if (closeReason === "expire")
      notification.expire();
    else if (closeReason === "dismiss")
      notification.dismiss();
  }

  function _compareWrappers(leftWrapper: var, rightWrapper: var): int {
    const timeDiff = (rightWrapper?.createdAt?.getTime() ?? 0) - (leftWrapper?.createdAt?.getTime() ?? 0);
    return timeDiff || (rightWrapper?.sequence ?? 0) - (leftWrapper?.sequence ?? 0);
  }

  function _computeGroups(notificationList: var): var {
    const groupsByKey = new Map();

    for (const wrapper of notificationList) {
      if (!wrapper)
        continue;
      let group = groupsByKey.get(wrapper.groupKey);
      if (!group) {
        group = {
          key: wrapper.groupKey,
          displayName: wrapper.displayName,
          notifications: [],
          latestNotification: wrapper,
          count: 0,
          urgency: NotificationUrgency.Normal,
          latestTime: 0,
          latestSequence: 0
        };
        groupsByKey.set(wrapper.groupKey, group);
      }
      group.notifications.push(wrapper);
    }

    return Array.from(groupsByKey.values()).map(group => {
      group.notifications.sort(root._compareWrappers);
      group.count = group.notifications.length;
      group.latestNotification = group.notifications[0] || group.latestNotification;
      group.displayName = group.latestNotification?.displayName || group.displayName;
      group.urgency = group.latestNotification?.notification?.urgency ?? NotificationUrgency.Normal;
      group.latestTime = group.latestNotification?.createdAt?.getTime() ?? 0;
      group.latestSequence = group.latestNotification?.sequence ?? 0;
      return group;
    }).sort(root._compareGroups);
  }

  function _compareGroups(leftGroup: var, rightGroup: var): int {
    const urgencyDiff = (rightGroup.urgency ?? 0) - (leftGroup.urgency ?? 0);
    if (urgencyDiff)
      return urgencyDiff;
    const timeDiff = (rightGroup.latestTime ?? 0) - (leftGroup.latestTime ?? 0);
    return timeDiff || (rightGroup.latestSequence ?? 0) - (leftGroup.latestSequence ?? 0);
  }

  function _createWrapper(notification: Notification, persistent: bool): var {
    root._sequence += 1;
    const wrapper = notifComponent.createObject(null, {
      notification: notification,
      persistent: persistent,
      sequence: root._sequence
    });
    if (!wrapper)
      return null;
    if (!persistent)
      root._popupOnlyWrappers = [wrapper, ...root._popupOnlyWrappers];
    return wrapper;
  }

  function _enqueuePopup(wrapper: var): void {
    if (!root._isLiveWrapper(wrapper) || root._popupQueue.includes(wrapper) || root.visibleNotifications.includes(wrapper))
      return;
    const nextQueue = [...root._popupQueue];
    if (!root._isCritical(wrapper)) {
      nextQueue.push(wrapper);
      root._popupQueue = nextQueue;
      return;
    }

    const firstNonCriticalIndex = nextQueue.findIndex(queuedWrapper => !root._isCritical(queuedWrapper));
    if (firstNonCriticalIndex === -1)
      nextQueue.push(wrapper);
    else
      nextQueue.splice(firstNonCriticalIndex, 0, wrapper);
    if (root._visiblePopupCount() >= root.maxVisibleNotifications) {
      const victim = root.visibleNotifications.find(visibleWrapper => visibleWrapper && !root._isCritical(visibleWrapper) && !visibleWrapper.isHidingPopup);
      if (victim)
        root._hidePopup(victim);
    }
    root._popupQueue = nextQueue;
  }

  function _expireTransientWrappers(): void {
    const transientWrappers = root._uniqueWrappers([root.visibleNotifications, root._popupQueue, root._popupOnlyWrappers]).filter(wrapper => !wrapper.persistent);
    if (transientWrappers.length)
      root._removeWrappers(transientWrappers, true, "expire");
  }

  function _hidePopup(wrapper: var): void {
    if (!root._isLiveWrapper(wrapper) || !root.visibleNotifications.includes(wrapper))
      return;
    wrapper.isHidingPopup = true;
    root._stopWrapperTimer(wrapper);
    wrapper.popup = false;

    const groupKey = wrapper.groupKey;
    const remainingPopupCount = root._remainingGroupCount(root.visibleNotifications, wrapper, groupKey, false);
    if (remainingPopupCount === 0)
      root._groupState.setDismissing(groupKey, "popup", true);
    root._queueRemoval({
      wrappers: [wrapper],
      removeFromHistory: false,
      closeReason: wrapper.persistent ? "hide" : "expire",
      groupKey: remainingPopupCount === 0 ? groupKey : ""
    });
  }

  function _isCritical(wrapper: var): bool {
    return (wrapper?.notification?.urgency ?? NotificationUrgency.Normal) === NotificationUrgency.Critical;
  }

  function _limitNotificationsPerApp(): void {
    const appCounts = {};
    const wrappersToRemove = [];

    for (const wrapper of root.notifications) {
      if (!wrapper)
        continue;
      appCounts[wrapper.groupKey] = (appCounts[wrapper.groupKey] || 0) + 1;
      if (appCounts[wrapper.groupKey] > root.maxNotificationsPerApp && !root._isCritical(wrapper))
        wrappersToRemove.push(wrapper);
    }
    if (wrappersToRemove.length)
      root._removeWrappers(wrappersToRemove, true, "dismiss");
  }

  function _prepareForRemoval(wrapper: var, hidePopup: bool, removeFromHistory: bool): void {
    wrapper.isDismissing = removeFromHistory || !wrapper.persistent;
    wrapper.isHidingPopup = hidePopup;
    root._stopWrapperTimer(wrapper);
    wrapper.popup = false;
    if (removeFromHistory || !wrapper.persistent)
      wrapper._removed = true;
  }

  function _beginDismissAnimation(wrapper: var, hidePopup: bool): void {
    wrapper.isDismissing = true;
    wrapper.isHidingPopup = hidePopup;
    root._stopWrapperTimer(wrapper);
    wrapper.popup = false;
  }

  function _pumpPopups(): void {
    if (root._popupsSuspended || root.doNotDisturb || root._isDestroying)
      return;
    let visiblePopupCount = root._visiblePopupCount();
    const nextQueue = [];
    const wrappersToShow = [];

    for (const wrapper of root._popupQueue) {
      if (!root._isLiveWrapper(wrapper) || root.visibleNotifications.includes(wrapper))
        continue;

      if (visiblePopupCount < root.maxVisibleNotifications) {
        visiblePopupCount++;
        wrappersToShow.push(wrapper);
      } else {
        nextQueue.push(wrapper);
      }
    }
    if (wrappersToShow.length) {
      root._popupQueue = nextQueue;
      wrappersToShow.forEach(wrapper => root._showPopup(wrapper));
    } else if (root._popupQueue.length !== nextQueue.length) {
      root._popupQueue = nextQueue;
    }
  }

  function _queueRemoval(item: var): void {
    root._removalQueue.push(item);
    if (!removalTimer.running)
      removalTimer.start();
  }

  function _remainingGroupCount(wrappers: var, ignoredWrapper: var, groupKey: string, includeHidingPopups: bool): int {
    return wrappers.filter(wrapper => {
      if (!wrapper || wrapper === ignoredWrapper || wrapper.isDismissing || wrapper._removed || wrapper.groupKey !== groupKey)
        return false;
      return includeHidingPopups || !wrapper.isHidingPopup;
    }).length;
  }

  function _removeWrappers(wrappers: var, removeFromHistory: bool, closeReason: string): void {
    const uniqueWrappers = root._uniqueWrappers([wrappers]);
    if (!uniqueWrappers.length)
      return;
    const wrappersToRemove = new Set(uniqueWrappers);
    uniqueWrappers.forEach(wrapper => root._prepareForRemoval(wrapper, false, removeFromHistory));

    root.visibleNotifications = root.visibleNotifications.filter(wrapper => wrapper && !wrappersToRemove.has(wrapper));
    root._popupQueue = root._popupQueue.filter(wrapper => wrapper && !wrappersToRemove.has(wrapper));
    root._popupOnlyWrappers = root._popupOnlyWrappers.filter(wrapper => wrapper && !wrappersToRemove.has(wrapper));
    if (removeFromHistory)
      root.notifications = root.notifications.filter(wrapper => wrapper && !wrappersToRemove.has(wrapper));
    uniqueWrappers.forEach(wrapper => {
      if (!removeFromHistory && wrapper.persistent) {
        if (!root.visibleNotifications.some(visibleWrapper => visibleWrapper?.groupKey === wrapper.groupKey && !visibleWrapper.isHidingPopup))
          root._groupState.setDismissing(wrapper.groupKey, "popup", false);
        return;
      }
      if (wrapper.persistent && !root.notifications.some(notificationWrapper => notificationWrapper?.groupKey === wrapper.groupKey && !notificationWrapper.isDismissing))
        root._groupState.setDismissing(wrapper.groupKey, "history", false);
      root._groupState.setDismissing(wrapper.groupKey, "popup", false);
      root._closeNotification(wrapper, closeReason || "dismiss");
      wrapper.destroy();
    });
    if (!root._isDestroying)
      root._pumpPopups();
  }

  function _scheduleGroupUpdate(): void {
    if (!root._isDestroying)
      _groupUpdateDebounce.restart();
  }

  function _showPopup(wrapper: var): void {
    if (!root._isLiveWrapper(wrapper) || root.visibleNotifications.includes(wrapper))
      return;
    root.visibleNotifications = [...root.visibleNotifications, wrapper];
    wrapper.popup = true;
    if (!wrapper.soundPlayed) {
      wrapper.soundPlayed = true;
      AudioService.playNotificationSound(wrapper.notification);
    }
    root._stopWrapperTimer(wrapper);
    if (wrapper.timer?.interval > 0)
      wrapper.timer.start();
  }

  function _isLiveWrapper(wrapper: var): bool {
    return !!wrapper && !wrapper._removed && !wrapper.isDismissing && !wrapper.isHidingPopup && !root._isDestroying;
  }

  function _stopWrapperTimer(wrapper: var): void {
    if (wrapper?.timer)
      wrapper.timer.stop();
  }

  function _trimStoredNotifications(): void {
    if (root.notifications.length <= root.maxStoredNotifications)
      return;
    const overflow = root.notifications.length - root.maxStoredNotifications;
    const wrappersToDrop = new Set();
    for (let index = root.notifications.length - 1; index >= 0 && wrappersToDrop.size < overflow; index--) {
      const wrapper = root.notifications[index];
      if (wrapper?.notification && !root._isCritical(wrapper))
        wrappersToDrop.add(wrapper);
    }
    for (let index = root.notifications.length - 1; index >= 0 && wrappersToDrop.size < overflow; index--) {
      const wrapper = root.notifications[index];
      if (wrapper?.notification && !wrappersToDrop.has(wrapper))
        wrappersToDrop.add(wrapper);
    }
    if (wrappersToDrop.size)
      root._removeWrappers(Array.from(wrappersToDrop), true, "dismiss");
  }

  function _uniqueWrappers(wrapperLists: var): var {
    const seenWrappers = new Set();
    const uniqueWrappers = [];
    for (const wrapperList of wrapperLists) {
      for (const wrapper of (wrapperList || [])) {
        if (!wrapper || seenWrappers.has(wrapper))
          continue;
        seenWrappers.add(wrapper);
        uniqueWrappers.push(wrapper);
      }
    }
    return uniqueWrappers;
  }

  function _updateGroupCaches(): void {
    if (root._isDestroying)
      return;
    root._groupedNotificationsCache = root._computeGroups(root.notifications);
    root._groupedPopupsCache = root._computeGroups(root.visibleNotifications);
    const activeKeys = new Set();
    root._groupedPopupsCache.forEach(group => activeKeys.add(group.key));
    root._groupState.pruneShown(activeKeys);
  }

  function clearAllNotifications(): void {
    root._popupsSuspended = true;
    const wrappersToDestroy = root._allWrappers();
    root._popupQueue = [];
    root._removalQueue = [];
    root._clearVisiblePopups();
    root.notifications = [];
    root._popupOnlyWrappers = [];
    root._groupState.clearAll();
    root._sequence = 0;
    if (wrappersToDestroy.length)
      root._removeWrappers(wrappersToDestroy, true, "dismiss");
    Qt.callLater(() => {
      if (root && !root._isDestroying)
        root._popupsSuspended = false;
    });
  }

  function dismissGroup(groupKey: string): void {
    const normalizedKey = (groupKey || "").trim();
    if (!normalizedKey)
      return;
    const wrappers = root._allWrappers().filter(wrapper => wrapper && !wrapper._removed && !wrapper.isDismissing && wrapper.groupKey === normalizedKey);
    if (!wrappers.length)
      return;
    wrappers.forEach(wrapper => root._beginDismissAnimation(wrapper, root.visibleNotifications.includes(wrapper)));
    const scopes = [];
    if (wrappers.some(wrapper => wrapper.persistent))
      scopes.push("history");
    if (root.groupedPopups.some(group => group.key === normalizedKey))
      scopes.push("popup");
    scopes.forEach(scope => root._groupState.setDismissing(normalizedKey, scope, true));
    root._queueRemoval({
      wrappers: wrappers,
      removeFromHistory: true,
      closeReason: "dismiss",
      groupKey: normalizedKey,
      scopes: scopes
    });
  }

  function dismissNotification(wrapper: var): void {
    if (!wrapper || wrapper.isDismissing || wrapper._removed)
      return;
    const groupKey = wrapper.groupKey;
    const isPopupVisible = root.visibleNotifications.includes(wrapper);
    const remainingHistoryCount = root._remainingGroupCount(root.notifications, wrapper, groupKey, true);
    const remainingPopupCount = isPopupVisible ? root._remainingGroupCount(root.visibleNotifications, wrapper, groupKey, false) : 0;
    const scopes = [];
    root._beginDismissAnimation(wrapper, isPopupVisible);
    if (wrapper.persistent && remainingHistoryCount === 0)
      scopes.push("history");
    if (isPopupVisible && remainingPopupCount === 0)
      scopes.push("popup");
    scopes.forEach(scope => root._groupState.setDismissing(groupKey, scope, true));
    root._queueRemoval({
      wrappers: [wrapper],
      removeFromHistory: wrapper.persistent,
      closeReason: "dismiss",
      groupKey: scopes.length ? groupKey : "",
      scopes: scopes
    });
  }

  function dismissNotificationsByAppName(appName: string): void {
    const targetAppName = (appName || "").trim();
    if (!targetAppName)
      return;
    const groupKeys = new Set(root.notifications.filter(wrapper => wrapper && (wrapper.notification?.appName || "") === targetAppName).map(wrapper => wrapper.groupKey));
    groupKeys.forEach(groupKey => root.dismissGroup(groupKey));
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
        root._popupsSuspended = false;
        root._pumpPopups();
      }
    });
  }

  function onOverlayOpen(): void {
    root._popupsSuspended = true;
    root._clearVisiblePopups();
    root._expireTransientWrappers();
  }

  function toggleDoNotDisturb(): void {
    root.doNotDisturb = !root.doNotDisturb;
    AudioService.dndActive = root.doNotDisturb;
    if (root.doNotDisturb) {
      root._clearVisiblePopups();
      root._expireTransientWrappers();
    } else {
      root._pumpPopups();
    }
  }

  function toggleGroupExpansion(groupKey: string): void {
    root._groupState.toggleExpanded(groupKey || "");
  }

  function uses24HourClock(): bool {
    return typeof TimeService !== "undefined" ? TimeService.use24Hour : true;
  }

  Component.onDestruction: {
    root._isDestroying = true;
    removalTimer.stop();
    _groupUpdateDebounce.stop();
    root._popupQueue = [];
    root._removalQueue = [];
    root._allWrappers().forEach(wrapper => {
      root._stopWrapperTimer(wrapper);
      wrapper.destroy();
    });
  }
  onNotificationsChanged: root._scheduleGroupUpdate()
  onVisibleNotificationsChanged: root._scheduleGroupUpdate()

  Timer {
    id: removalTimer

    interval: root.animationDuration
    repeat: false

    onTriggered: {
      if (root._isDestroying || root._removalQueue.length === 0)
        return;
      const item = root._removalQueue.shift();
      root._removeWrappers(item.wrappers, item.removeFromHistory, item.closeReason || "dismiss");
      if (item.groupKey && item.scopes)
        item.scopes.forEach(scope => root._groupState.setDismissing(item.groupKey, scope, false));
      if (root._removalQueue.length > 0)
        removalTimer.restart();
    }
  }

  Timer {
    id: _groupUpdateDebounce

    interval: 16
    repeat: false

    onTriggered: root._updateGroupCaches()
  }

  NotificationServer {
    id: server

    actionIconsSupported: true
    actionsSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    bodyMarkupSupported: true
    extraHints: ["sound"]
    imageSupported: true
    inlineReplySupported: true
    keepOnReload: false
    persistenceSupported: true

    onNotification: notification => {
      if (root._isDestroying)
        return;

      if (notification.transient) {
        if (root._popupsSuspended || root.doNotDisturb)
          return;
        notification.tracked = true;
        const popupWrapper = root._createWrapper(notification, false);
        if (popupWrapper) {
          root._enqueuePopup(popupWrapper);
          root._pumpPopups();
        }
        return;
      }

      notification.tracked = true;
      const wrapper = root._createWrapper(notification, true);
      if (!wrapper)
        return;
      root.notifications = [wrapper, ...root.notifications];
      root._trimStoredNotifications();
      root._limitNotificationsPerApp();
      if (!root._popupsSuspended && !root.doNotDisturb)
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
    function onUse24HourChanged(): void {
      root._scheduleGroupUpdate();
    }

    target: typeof TimeService !== "undefined" ? TimeService : null
  }

  component GroupState: QtObject {
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

    function isNew(key: string): bool {
      return !shownPopups[key];
    }

    function markShown(key: string): void {
      if (!key || shownPopups[key])
        return;
      shownPopups = Object.assign({}, shownPopups, {
        [key]: true
      });
    }

    function pruneShown(activeKeys: var): void {
      const nextShownPopups = {};
      let changed = false;

      for (const key in shownPopups) {
        if (activeKeys.has(key))
          nextShownPopups[key] = true;
        else
          changed = true;
      }
      if (changed)
        shownPopups = nextShownPopups;
    }

    function setDismissing(key: string, scope: string, value: bool): void {
      const scopedKey = `${scope}:${key}`;
      if (!!dismissing[scopedKey] === value)
        return;
      const nextDismissing = Object.assign({}, dismissing);
      if (value)
        nextDismissing[scopedKey] = true;
      else
        delete nextDismissing[scopedKey];
      dismissing = nextDismissing;
    }

    function toggleExpanded(key: string): void {
      if (!key)
        return;
      const nextExpanded = Object.assign({}, expanded);
      nextExpanded[key] = !nextExpanded[key];
      expanded = nextExpanded;
    }
  }

  component NotifWrapper: QtObject {
    id: wrapper

    property bool _removed: false
    readonly property color accentColor: root._urgencyConfig[wrapper.notification?.urgency ?? NotificationUrgency.Normal]?.color ?? Theme.activeColor
    readonly property Connections closeConnection: Connections {
      function onClosed(): void {
        if (!root._isDestroying && !wrapper._removed)
          root._removeWrappers([wrapper], true, "closed");
      }

      enabled: !wrapper._removed && !!target
      target: wrapper.notification || null
    }
    readonly property Connections retainableConnection: Connections {
      function onDropped(): void {
        if (!root._isDestroying && !wrapper.isDismissing && !wrapper._removed)
          root._removeWrappers([wrapper], true, "closed");
      }

      enabled: !wrapper.isDismissing && !wrapper._removed && !!target
      target: wrapper.notification?.Retainable || null
    }
    readonly property date createdAt: new Date()
    readonly property string displayName: {
      const entryId = String(wrapper.notification?.desktopEntry || wrapper.notification?.appName || "").trim();
      return Utils.lookupDesktopEntryName(entryId) || wrapper.notification?.appName || "app";
    }
    readonly property string groupKey: {
      const desktopEntry = String(wrapper.notification?.desktopEntry || "").trim().toLowerCase();
      return desktopEntry || String(wrapper.notification?.appName || "app").toLowerCase();
    }
    property bool isDismissing: false
    property bool isHidingPopup: false
    required property Notification notification
    property bool persistent: true
    property bool popup: false
    property int sequence: 0
    property bool soundPlayed: false
    readonly property Timer timer: Timer {
      interval: root._urgencyConfig[wrapper.notification?.urgency ?? NotificationUrgency.Normal]?.timeout ?? 5000
      repeat: false
      running: false

      onTriggered: {
        if (wrapper.timer.interval > 0 && wrapper.popup && !wrapper.isDismissing && !wrapper.isHidingPopup && !wrapper._removed && !root._isDestroying)
          root._hidePopup(wrapper);
      }
    }

    onPopupChanged: {
      if (wrapper.popup || wrapper.isDismissing || wrapper.isHidingPopup || wrapper._removed || root._isDestroying)
        return;
      if (root.visibleNotifications.includes(wrapper))
        root.visibleNotifications = root.visibleNotifications.filter(visibleWrapper => visibleWrapper !== wrapper);
      Qt.callLater(() => {
        if (root && !root._isDestroying)
          root._pumpPopups();
      });
    }
  }
}
