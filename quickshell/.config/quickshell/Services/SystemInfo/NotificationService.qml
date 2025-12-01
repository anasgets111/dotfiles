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

  property Timer _groupUpdateDebounce: Timer {
    interval: 16
    repeat: false

    onTriggered: root._updateGroupCaches()
  }
  property var _groupedNotificationsCache: []
  property var _groupedPopupsCache: []
  property bool _isDestroying: false
  property bool _popupGateBusy: false
  readonly property int animationDuration: 400
  property bool doNotDisturb: false
  property var expandedGroups: ({})
  readonly property var groupedNotifications: root._groupedNotificationsCache
  readonly property var groupedPopups: root._groupedPopupsCache
  readonly property var inlineReplyIdSet: new Set(["inline-reply", "inline_reply", "inline reply", "quick_reply", "quick-reply", "reply", "reply_inline", "reply-inline"])
  readonly property int maxNotificationsPerApp: 10
  readonly property int maxStoredNotifications: 100
  readonly property int maxVisibleNotifications: 3
  property var notifications: []
  property bool popupsDisabled: false
  readonly property int timeoutCritical: 0
  readonly property int timeoutLow: 3000
  readonly property int timeoutNormal: 5000
  property var visibleNotifications: []

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
          latestNotification: notif,
          hasInlineReply: false,
          count: 0
        };
      }
      groups[groupKey].notifications.unshift(notif);
      groups[groupKey].count = groups[groupKey].notifications.length;
      if (notif.notification?.hasInlineReply)
        groups[groupKey].hasInlineReply = true;
    }
    return Object.values(groups).sort((a, b) => {
      const aUrgency = a.latestNotification?.urgency ?? 0;
      const bUrgency = b.latestNotification?.urgency ?? 0;
      if (aUrgency !== bUrgency)
        return bUrgency - aUrgency;
      return (b.latestNotification?.time?.getTime() ?? 0) - (a.latestNotification?.time?.getTime() ?? 0);
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

  function _normalizeActions(notification) {
    const actions = notification?.actions;
    if (!actions)
      return [];

    const length = Array.isArray(actions) ? actions.length : Number(actions.length || actions.count || 0);
    if (!length || Number.isNaN(length))
      return [];

    const list = [];
    for (let i = 0; i < length; i++) {
      if (actions[i])
        list.push(actions[i]);
    }
    if (!list.length)
      return [];

    const seen = new Set();
    const hasInline = notification?.hasInlineReply === true;
    const placeholderKey = String(notification?.inlineReplyPlaceholder || "").trim().toLowerCase();
    const result = [];

    for (const action of list) {
      const identifier = String(action.identifier || action.id || action.name || "").trim();
      const label = String(action.text || action.title || action.label || identifier).trim();
      const idKey = identifier.toLowerCase();
      const labelKey = label.toLowerCase();

      // Skip inline reply actions
      const isInline = action.isInlineReply === true || (hasInline && (root.inlineReplyIdSet.has(idKey) || root.inlineReplyIdSet.has(labelKey) || (placeholderKey && labelKey === placeholderKey)));
      if (isInline)
        continue;

      const id = identifier || label || `action-${result.length}`;
      const key = id.toLowerCase();
      if (seen.has(key))
        continue;

      seen.add(key);
      result.push({
        id,
        title: label || id,
        _obj: action
      });
    }
    return result;
  }

  function _scheduleGroupUpdate() {
    root._groupUpdateDebounce.restart();
  }

  function _showNextPopup() {
    if (root._popupGateBusy || root.popupsDisabled || root.doNotDisturb)
      return;

    // Find notifications waiting to be shown as popups
    const activeCount = root.visibleNotifications.length;
    if (activeCount >= root.maxVisibleNotifications)
      return;

    // Find first notification not in visibleNotifications
    const next = root.notifications.find(n => n && !n.isDismissing && !root.visibleNotifications.includes(n) && n._pendingPopup);
    if (!next)
      return;

    next._pendingPopup = false;
    root.visibleNotifications = [...root.visibleNotifications, next];
    next.popup = true;
    if (next.timer.interval > 0)
      next.timer.start();

    root._popupGateBusy = true;
    popupGate.restart();
  }

  function _trimStoredNotifications() {
    if (root.notifications.length <= root.maxStoredNotifications)
      return;

    const overflow = root.notifications.length - root.maxStoredNotifications;
    const toDrop = [];

    // First pass: non-critical from end
    for (let i = root.notifications.length - 1; i >= 0 && toDrop.length < overflow; i--) {
      const notif = root.notifications[i];
      if (notif?.notification && notif.urgency !== NotificationUrgency.Critical)
        toDrop.push(notif);
    }
    for (let i = root.notifications.length - 1; i >= 0 && toDrop.length < overflow; i--) {
      const notif = root.notifications[i];
      if (notif?.notification && !toDrop.includes(notif))
        toDrop.push(notif);
    }
    for (const notif of toDrop) {
      notif.notification?.dismiss();
    }
  }

  function _updateGroupCaches() {
    root._groupedNotificationsCache = root._computeGroups(root.notifications);
    root._groupedPopupsCache = root._computeGroups(root.visibleNotifications);
  }

  function clearAllNotifications() {
    root.popupsDisabled = true;
    popupGate.stop();
    root._popupGateBusy = false;
    for (const wrapper of root.visibleNotifications) {
      if (wrapper)
        wrapper.popup = false;
    }
    root.visibleNotifications = [];
    const toDestroy = [...root.notifications];
    root.notifications = [];
    root.expandedGroups = {};

    for (const wrapper of toDestroy) {
      if (wrapper && !wrapper.isDismissing) {
        wrapper.isDismissing = true;
        wrapper.timer?.stop();
        wrapper.notification?.dismiss();
        wrapper.destroy();
      }
    }

    Qt.callLater(() => {
      if (root && !root._isDestroying)
        root.popupsDisabled = false;
    });
  }

  function dismissGroup(groupKey) {
    if (!groupKey)
      return;
    const group = root.groupedPopups.find(g => g.key === groupKey) || root.groupedNotifications.find(g => g.key === groupKey);
    if (group) {
      // Copy array to avoid mutation during iteration
      const items = [...group.notifications];
      for (const notif of items)
        root.dismissNotification(notif);
    }
  }

  function dismissNotification(wrapper) {
    if (!wrapper || wrapper.isDismissing)
      return;
    wrapper.isDismissing = true;
    wrapper.timer?.stop();
    wrapper.popup = false;

    root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
    root.notifications = root.notifications.filter(n => n !== wrapper);

    wrapper.notification?.dismiss();
    Qt.callLater(() => {
      wrapper.destroy();
      if (root && !root._isDestroying)
        root._showNextPopup();
    });
  }

  function dismissNotificationsByAppName(appName) {
    const target = String(appName).trim();
    if (!target)
      return;
    for (const wrapper of [...root.notifications]) {
      if (wrapper?.appName === target)
        wrapper.notification?.dismiss();
    }
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

  function getGroupKey(wrapper) {
    const de = wrapper?.desktopEntry || "";
    return de ? de.toLowerCase() : (wrapper?.appName || "app").toLowerCase();
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

  function onOverlayClose() {
    Qt.callLater(() => {
      if (root && !root._isDestroying) {
        root.popupsDisabled = false;
        root._showNextPopup();
      }
    });
  }

  function onOverlayOpen() {
    root.popupsDisabled = true;
    popupGate.stop();
    root._popupGateBusy = false;
    for (const notif of root.visibleNotifications) {
      if (notif)
        notif.popup = false;
    }
    root.visibleNotifications = [];
  }

  function prepareBody(raw) {
    if (typeof raw !== "string" || !raw)
      return {
        text: "",
        format: Qt.PlainText
      };

    try {
      if (typeof Markdown2Html !== "undefined" && typeof Markdown2Html.toDisplay === "function") {
        const result = Markdown2Html.toDisplay(raw);
        if (result?.format === Qt.RichText)
          return result;
      }
    } catch (e) {}

    try {
      const escapeHtml = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
      const escaped = escapeHtml(raw);
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
      for (const notif of root.visibleNotifications) {
        if (notif)
          notif.popup = false;
      }
      root.visibleNotifications = [];
    } else {
      root._showNextPopup();
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
    popupGate.stop();
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
      root._showNextPopup();
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
      root.visibleNotifications = root.visibleNotifications.filter(w => w?.notification?.valid);
    }
    onNotification: notif => {
      notif.tracked = true;
      const wrapper = notifComponent.createObject(null, {
        notification: notif
      });
      if (!wrapper)
        return;

      wrapper._pendingPopup = !root.popupsDisabled && !root.doNotDisturb;
      root.notifications = [wrapper, ...root.notifications];
      root._trimStoredNotifications();
      root._showNextPopup();
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

    property bool _pendingPopup: false
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
    readonly property Connections conn: Connections {
      function onDropped() {
        if (root._isDestroying || wrapper.isDismissing)
          return;
        wrapper.isDismissing = true;
        wrapper.popup = false;
        root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
        root.notifications = root.notifications.filter(n => n !== wrapper);
        Qt.callLater(() => {
          wrapper.destroy();
          if (root && !root._isDestroying)
            root._showNextPopup();
        });
      }

      enabled: !wrapper.isDismissing && !!target
      target: wrapper.notification?.Retainable || null
    }
    readonly property string desktopEntry: notification?.desktopEntry || ""
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
    readonly property bool isPersistent: wrapper.urgency === NotificationUrgency.Critical || timer.interval === 0
    required property Notification notification
    property bool popup: false
    readonly property string summary: notification?.summary || ""
    readonly property date time: new Date()
    readonly property string timeStr: {
      root.groupedNotifications;
      const now = new Date();
      const diff = now.getTime() - wrapper.time.getTime();
      const minutes = Math.floor(diff / 60000);
      if (minutes < 1)
        return "now";
      if (minutes < 60)
        return `${minutes}m ago`;
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const notifDay = new Date(wrapper.time.getFullYear(), wrapper.time.getMonth(), wrapper.time.getDate());
      const daysDiff = Math.floor((today - notifDay) / 86400000);

      const timeFormat = root.use24Hour() ? "HH:mm" : "h:mm AP";
      if (daysDiff === 0)
        return wrapper.time.toLocaleTimeString(Qt.locale(), timeFormat);
      if (daysDiff === 1)
        return `yesterday, ${wrapper.time.toLocaleTimeString(Qt.locale(), timeFormat)}`;
      return `${daysDiff} days ago`;
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
      if (!wrapper.popup && !wrapper.isDismissing) {
        root.visibleNotifications = root.visibleNotifications.filter(n => n !== wrapper);
        Qt.callLater(() => {
          if (root && !root._isDestroying)
            root._showNextPopup();
        });
      }
    }
  }
}
