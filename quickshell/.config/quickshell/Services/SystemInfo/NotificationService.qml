pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Config
import qs.Services.Core
import qs.Services.Utils

Singleton {
  id: root

  readonly property GroupState _groupState: GroupState {
  }
  property bool _isDestroying: false
  property var _popupOnlyWrappers: []
  property var _popupQueue: []
  property bool _popupsSuspended: false
  property var _removalQueue: []
  property int _sequence: 0
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
        color: Theme.critical
      }
    })
  readonly property int animationDuration: Math.round((Theme.animationDuration || 200) * 1.4)
  property bool doNotDisturb: false
  readonly property var expandedGroups: root._groupState.expanded
  readonly property var groupedNotifications: root._isDestroying ? [] : root._computeGroups(root.notifications)
  readonly property var groupedPopups: root._isDestroying ? [] : root._computeGroups(root.visibleNotifications)
  readonly property int maxNotificationsPerApp: 10
  readonly property int maxStoredNotifications: 100
  readonly property int maxVisibleNotifications: 3
  property var notifications: []
  readonly property bool _popupsBlocked: root._popupsSuspended || LockService.locked || IdleService.displaysPoweredOff
  property var visibleNotifications: []

  function _allWrappers(): var {
    return [...root.notifications, ...root._popupOnlyWrappers];
  }
  function _beginDismissAnimation(wrapper: var, hidePopup: bool): void {
    wrapper.isDismissing = true;
    wrapper.isHidingPopup = hidePopup;
    root._stopWrapperTimer(wrapper);
  }
  function _clearVisiblePopups(): void {
    root.visibleNotifications.forEach(wrapper => {
      if (!wrapper)
        return;
      root._stopWrapperTimer(wrapper);
      wrapper.isHidingPopup = false;
    });
    root.visibleNotifications = [];
  }
  function _closeNotification(wrapper: var, closeReason: string): void {
    const notification = wrapper?.notification;
    if (!notification)
      return;
    if (closeReason === "expire")
      notification.expire();
    else if (closeReason === "dismiss")
      notification.dismiss();
  }
  function _compareGroups(leftGroup: var, rightGroup: var): int {
    const urgencyDiff = (rightGroup.urgency ?? 0) - (leftGroup.urgency ?? 0);
    if (urgencyDiff)
      return urgencyDiff;
    const timeDiff = (rightGroup.latestTime ?? 0) - (leftGroup.latestTime ?? 0);
    return timeDiff || (rightGroup.latestSequence ?? 0) - (leftGroup.latestSequence ?? 0);
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
          notifications: []
        };
        groupsByKey.set(wrapper.groupKey, group);
      }
      group.notifications.push(wrapper);
    }

    return Array.from(groupsByKey.values()).map(group => {
      group.notifications.sort(root._compareWrappers);
      group.count = group.notifications.length;
      group.latestNotification = group.notifications[0];
      group.displayName = group.latestNotification?.displayName || "app";
      group.urgency = group.latestNotification?.notification?.urgency ?? NotificationUrgency.Normal;
      group.latestTime = group.latestNotification?.createdAt?.getTime() ?? 0;
      group.latestSequence = group.latestNotification?.sequence ?? 0;
      return group;
    }).sort(root._compareGroups);
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
    if (root._popupOnlyWrappers.length > root.maxStoredNotifications)
      root._removeWrappers(root._popupOnlyWrappers.slice(root.maxStoredNotifications), true, "expire");
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
    if (root._popupOnlyWrappers.length)
      root._removeWrappers(root._popupOnlyWrappers, true, "expire");
  }
  function _hidePopup(wrapper: var): void {
    if (!root._isLiveWrapper(wrapper) || !root.visibleNotifications.includes(wrapper))
      return;
    wrapper.isHidingPopup = true;
    root._stopWrapperTimer(wrapper);

    root._queueRemoval({
      wrappers: [wrapper],
      removeFromHistory: false,
      closeReason: wrapper.persistent ? "hide" : "expire"
    });
  }
  function _isCritical(wrapper: var): bool {
    return (wrapper?.notification?.urgency ?? NotificationUrgency.Normal) === NotificationUrgency.Critical;
  }
  function _isLiveWrapper(wrapper: var): bool {
    return !!wrapper && !wrapper._removed && !wrapper.isDismissing && !wrapper.isHidingPopup && !root._isDestroying;
  }
  function _limitNotificationsPerApp(): void {
    const appCounts = new Map();
    const wrappersToRemove = [];

    for (const wrapper of root.notifications) {
      if (!wrapper)
        continue;
      const appCount = (appCounts.get(wrapper.groupKey) ?? 0) + 1;
      appCounts.set(wrapper.groupKey, appCount);
      if (appCount > root.maxNotificationsPerApp && !root._isCritical(wrapper))
        wrappersToRemove.push(wrapper);
    }
    if (wrappersToRemove.length)
      root._removeWrappers(wrappersToRemove, true, "dismiss");
  }
  function _prepareForRemoval(wrapper: var, removeFromHistory: bool): void {
    wrapper.isDismissing = removeFromHistory || !wrapper.persistent;
    wrapper.isHidingPopup = false;
    root._stopWrapperTimer(wrapper);
    if (removeFromHistory || !wrapper.persistent)
      wrapper._removed = true;
  }
  function _pumpPopups(): void {
    if (root._popupsBlocked || root.doNotDisturb || root._isDestroying)
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
  function _removeWrappers(wrappers: var, removeFromHistory: bool, closeReason: string): void {
    const wrappersToRemove = new Set((wrappers || []).filter(Boolean));
    if (!wrappersToRemove.size)
      return;
    const uniqueWrappers = Array.from(wrappersToRemove);
    const wrappersToDestroy = new Set(uniqueWrappers.filter(wrapper => removeFromHistory || !wrapper.persistent));
    if (wrappersToDestroy.size) {
      root._removalQueue.forEach(item => item.wrappers = (item.wrappers || []).filter(wrapper => wrapper && !wrappersToDestroy.has(wrapper)));
      root._removalQueue = root._removalQueue.filter(item => item.wrappers.length > 0);
    }
    uniqueWrappers.forEach(wrapper => root._prepareForRemoval(wrapper, removeFromHistory));

    root.visibleNotifications = root.visibleNotifications.filter(wrapper => wrapper && !wrappersToRemove.has(wrapper));
    root._popupQueue = root._popupQueue.filter(wrapper => wrapper && !wrappersToRemove.has(wrapper));
    root._popupOnlyWrappers = root._popupOnlyWrappers.filter(wrapper => wrapper && !wrappersToRemove.has(wrapper));
    if (removeFromHistory)
      root.notifications = root.notifications.filter(wrapper => wrapper && !wrappersToRemove.has(wrapper));
    uniqueWrappers.forEach(wrapper => {
      if (!removeFromHistory && wrapper.persistent)
        return;
      root._closeNotification(wrapper, closeReason);
      wrapper.destroy();
    });
    if (!root._isDestroying)
      root._pumpPopups();
  }
  function _showPopup(wrapper: var): void {
    if (!root._isLiveWrapper(wrapper) || root.visibleNotifications.includes(wrapper))
      return;
    root.visibleNotifications = [...root.visibleNotifications, wrapper];
    AudioService.playNotificationSound(wrapper.notification);
    if (wrapper.timer?.interval > 0)
      wrapper.timer.start();
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
  function _visiblePopupCount(): int {
    return root.visibleNotifications.filter(wrapper => wrapper && !wrapper._removed && !wrapper.isHidingPopup && !wrapper.isDismissing).length;
  }
  function clearAllNotifications(): void {
    root._popupsSuspended = true;
    const wrappersToDestroy = root._allWrappers();
    root._popupQueue = [];
    root._removalQueue = [];
    removalTimer.stop();
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
    root._queueRemoval({
      wrappers: wrappers,
      removeFromHistory: true,
      closeReason: "dismiss"
    });
  }
  function dismissNotification(wrapper: var): void {
    if (!wrapper || wrapper.isDismissing || wrapper._removed)
      return;
    const isPopupVisible = root.visibleNotifications.includes(wrapper);
    root._beginDismissAnimation(wrapper, isPopupVisible);
    root._queueRemoval({
      wrappers: [wrapper],
      removeFromHistory: wrapper.persistent,
      closeReason: "dismiss"
    });
  }
  function dismissNotificationsByAppName(appName: string): void {
    const targetAppName = (appName || "").trim();
    if (!targetAppName)
      return;
    const groupKeys = new Set(root.notifications.filter(wrapper => wrapper && (wrapper.notification?.appName || "") === targetAppName).map(wrapper => wrapper.groupKey));
    groupKeys.forEach(groupKey => root.dismissGroup(groupKey));
  }
  function invokeAction(wrapper: var, identifier: string): void {
    const target = String(identifier || "").trim();
    const action = (wrapper?.notification?.actions || []).find(candidate => String(candidate?.identifier || "").trim() === target);
    action?.invoke();
  }
  function invokeDefaultAction(wrapper: var): void {
    root.invokeAction(wrapper, "default");
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
  function pauseTimers(wrappers: var): void {
    (wrappers || []).forEach(wrapper => root._stopWrapperTimer(wrapper));
  }
  function resumeTimers(wrappers: var): void {
    (wrappers || []).forEach(wrapper => {
      const timer = wrapper?.timer;
      if (root._isLiveWrapper(wrapper) && root.visibleNotifications.includes(wrapper) && timer && timer.interval > 0 && !timer.running)
        timer.start();
    });
  }
  function sendReply(wrapper: var, text: string): bool {
    const replyText = String(text || "");
    if (replyText.length === 0)
      return false;
    const notification = wrapper?.notification;
    if (notification?.hasInlineReply !== true)
      return false;
    try {
      notification.sendInlineReply(replyText);
      return true;
    } catch (error) {
      return false;
    }
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
    root._popupQueue = [];
    root._removalQueue = [];
    root._allWrappers().forEach(wrapper => {
      root._stopWrapperTimer(wrapper);
      wrapper.destroy();
    });
  }
  onGroupedPopupsChanged: {
    if (!root._isDestroying)
      root._groupState.pruneShown(new Set(root.groupedPopups.map(group => group.key)));
  }
  on_PopupsBlockedChanged: if (root._popupsBlocked) {
    root._popupQueue = [];
    root._clearVisiblePopups();
    root._expireTransientWrappers();
  }

  Timer {
    id: removalTimer

    interval: root.animationDuration
    repeat: false

    onTriggered: {
      if (root._isDestroying || root._removalQueue.length === 0)
        return;
      const item = root._removalQueue.shift();
      root._removeWrappers(item.wrappers, item.removeFromHistory, item.closeReason);
      if (root._removalQueue.length > 0)
        removalTimer.restart();
    }
  }
  NotificationServer {
    id: server

    actionIconsSupported: true
    actionsSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: false
    bodyMarkupSupported: true
    extraHints: ["sound"]
    imageSupported: true
    inlineReplySupported: true
    keepOnReload: false
    persistenceSupported: true

    onNotification: notification => {
      if (root._isDestroying)
        return;

      const persistent = !notification.transient;
      if (!persistent && (root._popupsBlocked || root.doNotDisturb))
        return;

      notification.tracked = true;
      const wrapper = root._createWrapper(notification, persistent);
      if (!wrapper)
        return;
      if (persistent) {
        root.notifications = [wrapper, ...root.notifications];
        root._trimStoredNotifications();
        root._limitNotificationsPerApp();
      }
      if (!root._popupsBlocked && !root.doNotDisturb)
        root._enqueuePopup(wrapper);
      root._pumpPopups();
    }
  }
  Component {
    id: notifComponent

    NotifWrapper {
    }
  }

  component GroupState: QtObject {
    property var expanded: ({})
    property var shownPopups: ({})

    function clearAll(): void {
      expanded = ({});
      shownPopups = ({});
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
    readonly property var actionList: wrapper.notification?.actions || []
    readonly property bool bodyHasMultipleLines: wrapper.bodyText.includes("\n")
    readonly property string bodyText: wrapper.notification?.body || ""
    readonly property Connections closeConnection: Connections {
      function onClosed(): void {
        if (!root._isDestroying && !wrapper._removed)
          root._removeWrappers([wrapper], true, "closed");
      }

      enabled: !wrapper._removed && !!target
      target: wrapper.notification || null
    }
    readonly property url contentImage: Utils.normalizeImageUrl(String(wrapper.notification?.image || ""))
    readonly property date createdAt: new Date()
    readonly property string displayName: {
      const entryId = String(wrapper.notification?.desktopEntry || wrapper.notification?.appName || "").trim();
      return Utils.lookupDesktopEntryName(entryId) || wrapper.notification?.appName || "app";
    }
    readonly property string groupKey: {
      const desktopEntry = String(wrapper.notification?.desktopEntry || "").trim().toLowerCase();
      return desktopEntry || String(wrapper.notification?.appName || "app").toLowerCase();
    }
    readonly property bool hasBody: !!(wrapper.renderedBody.plain.trim() && wrapper.renderedBody.plain.trim() !== wrapper.renderedSummary.plain.trim())
    readonly property bool hasDefaultAction: wrapper.actionList.some(action => String(action?.identifier || "").trim() === "default")
    readonly property bool hasInlineReply: wrapper.notification?.hasInlineReply === true
    readonly property string inlineReplyPlaceholder: wrapper.notification?.inlineReplyPlaceholder || "Reply"
    property bool isDismissing: false
    property bool isHidingPopup: false
    readonly property string messageId: String(wrapper.notification?.id ?? "")
    required property Notification notification
    property bool persistent: true
    readonly property var renderedBody: NotificationText.body(wrapper.bodyText)
    readonly property var renderedSummary: NotificationText.summary(wrapper.summaryText)
    readonly property Connections retainableConnection: Connections {
      function onDropped(): void {
        if (!root._isDestroying && !wrapper.isDismissing && !wrapper._removed)
          root._removeWrappers([wrapper], true, "closed");
      }

      enabled: !wrapper.isDismissing && !wrapper._removed && !!target
      target: wrapper.notification?.Retainable || null
    }
    property int sequence: 0
    readonly property string summaryText: String(wrapper.notification?.summary || "").trim() || "(No title)"
    readonly property Timer timer: Timer {
      interval: root._urgencyConfig[wrapper.notification?.urgency ?? NotificationUrgency.Normal]?.timeout ?? 5000
      repeat: false
      running: false

      onTriggered: {
        if (root._isLiveWrapper(wrapper) && root.visibleNotifications.includes(wrapper))
          root._hidePopup(wrapper);
      }
    }
    readonly property string timestampText: {
      const use24Hour = root.uses24HourClock();
      const formatted = Qt.formatDateTime(wrapper.createdAt, use24Hour ? "ddd HH:mm" : "ddd h:mm AP");
      return use24Hour ? formatted : formatted.replace(" AM", "am").replace(" PM", "pm");
    }
    readonly property bool useActionIcons: wrapper.notification?.hasActionIcons || false
    readonly property var visibleActions: wrapper.actionList.filter(action => {
      if (!action)
        return false;
      const identifier = String(action.identifier || "").trim();
      if (identifier === "default")
        return false;
      const text = String(action.text || "").trim();
      return text !== "" || (!wrapper.useActionIcons && identifier !== "");
    }).map(action => {
      const identifier = String(action.identifier || "");
      const text = String(action.text || "").trim();
      return {
        identifier: identifier,
        label: text !== "" ? text : (wrapper.useActionIcons ? "" : identifier.trim()),
        icon: wrapper.useActionIcons && identifier ? Utils.resolveIconSource(identifier, "", "") : ""
      };
    })
  }
}
