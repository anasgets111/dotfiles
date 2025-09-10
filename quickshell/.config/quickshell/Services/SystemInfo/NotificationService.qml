pragma Singleton
pragma ComponentBehavior: Bound
import qs.Services.Utils

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
  id: root

  property bool _addGateBusy: false
  readonly property int _enterAnimMs: 300
  property int _localIdSeq: 1
  property bool _timePulse: false

  property var all: []               // wrappers (active + hidden locals)
  property var visible: []           // wrappers shown as popups
  property var queue: []             // wrappers waiting to show
  property var groupsMap: ({})       // groupId -> { id, title, children, ... }

  property bool expirePopups: true
  property int maxVisible: 3

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

  property var actionLog: [] // [{notificationId, actionId, at}]
  property var replyLog: []  // [{notificationId, text, at}]

  property int maxHistory: 100
  readonly property ListModel historyModel: ListModel {}

  // ----- Server -----
  readonly property NotificationServer server: NotificationServer {
    id: notificationServer

    actionIconsSupported: true
    actionsSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    bodyMarkupSupported: true
    bodySupported: true
    imageSupported: true
    inlineReplySupported: true
    keepOnReload: false
    persistenceSupported: true

    onNotification: function (notification) {
      root._present(notification);
    }
  }

  property int timeoutCritical: 0
  property int timeoutLow: 5000
  property int timeoutNormal: 8000

  signal actionInvoked(string summary, string appName, string actionId, string body)
  signal dndChanged(bool enabled, var policy)
  signal replySubmitted(string id, string text, string appName, string summary)

  // ----- Utils -----
  function _parseJson(s, fb) {
    try {
      const v = JSON.parse(s);
      return v === undefined ? fb : v;
    } catch (_) {
      return fb;
    }
  }

  // ----- History / logs -----
  function _addToHistory(obj) {
    const n = obj?.notification ? obj.notification : obj;
    const idVal = obj?.id || n?.id || "";
    historyModel.insert(0, {
      id: String(idVal || ""),
      summary: String(n?.summary || ""),
      body: String(n?.body || ""),
      bodyFormat: String(n?.bodyFormat || "plain"),
      image: String(n?.image || ""),
      appName: String(n?.appName || ""),
      urgency: Number(n?.urgency ?? NotificationUrgency.Normal),
      groupId: String(obj?.groupId || n?.groupId || ""),
      timestamp: new Date()
    });
    while (historyModel.count > maxHistory)
      historyModel.remove(historyModel.count - 1);
    _saveHistory();
  }

  function _saveHistory() {
    const out = [];
    for (let i = 0; i < historyModel.count; i++) {
      const it = historyModel.get(i);
      out.push({
        id: it.id || "",
        summary: it.summary,
        body: it.body,
        bodyFormat: it.bodyFormat || "plain",
        image: it.image || "",
        appName: it.appName,
        urgency: it.urgency,
        groupId: it.groupId || "",
        timestamp: it.timestamp instanceof Date ? it.timestamp.getTime() : it.timestamp
      });
    }
    store.historyStoreJson = JSON.stringify(out);
  }

  function _loadHistory() {
    historyModel.clear();
    const items = _parseJson(store.historyStoreJson || "[]", []);
    for (let i = 0; i < items.length; i++) {
      const it = items[i] || {};
      historyModel.append({
        id: String(it.id || ""),
        summary: String(it.summary || ""),
        body: String(it.body || ""),
        bodyFormat: String(it.bodyFormat || "plain"),
        image: String(it.image || ""),
        appName: String(it.appName || ""),
        urgency: Number(it.urgency),
        groupId: String(it.groupId || ""),
        timestamp: it.timestamp ? new Date(Number(it.timestamp)) : new Date()
      });
    }
  }

  function _saveLogs() {
    try {
      store.actionLogJson = JSON.stringify(root.actionLog || []);
    } catch (e) {}
    try {
      store.replyLogJson = JSON.stringify(root.replyLog || []);
    } catch (e) {}
  }

  function _loadLogs() {
    const a = _parseJson(store.actionLogJson || "[]", []);
    const r = _parseJson(store.replyLogJson || "[]", []);
    root.actionLog = Array.isArray(a) ? a : [];
    root.replyLog = Array.isArray(r) ? r : [];
  }

  // ----- DND -----
  function _timeInRange(nowH, nowM, startStr, endStr) {
    const toHM = s => {
      const [hr, mn] = String(s || "0:0").split(":");
      const h = Math.max(0, Math.min(23, Number(hr || 0)));
      const m = Math.max(0, Math.min(59, Number(mn || 0)));
      return [h, m];
    };
    const [sh, sm] = toHM(startStr);
    const [eh, em] = toHM(endStr);
    const sTot = sh * 60 + sm;
    const eTot = eh * 60 + em;
    const nTot = nowH * 60 + nowM;
    if (sTot === eTot)
      return false;
    if (sTot < eTot)
      return nTot >= sTot && nTot < eTot;
    return nTot >= sTot || nTot < eTot; // overnight
  }

  function _evalDnd(notification) {
    const p = root.dndPolicy || {};
    if (!p.enabled)
      return "bypass";
    const behavior = p.behavior === "suppress" ? "suppress" : "queue";
    const urg = notification && notification.urgency !== undefined ? Number(notification.urgency) : NotificationUrgency.Normal;
    if (p.urgency?.bypassCritical && urg === NotificationUrgency.Critical)
      return "bypass";

    const appName = String(notification?.appName || "");
    const allow = Array.isArray(p.appRules?.allow) ? p.appRules.allow : [];
    const deny = Array.isArray(p.appRules?.deny) ? p.appRules.deny : [];
    if (allow.length && !allow.includes(appName))
      return behavior;
    if (deny.includes(appName))
      return behavior;

    if (Array.isArray(p.schedule) && p.schedule.length) {
      const now = new Date();
      const dow = now.getDay();
      const h = now.getHours();
      const m = now.getMinutes();
      for (let i = 0; i < p.schedule.length; i++) {
        const s = p.schedule[i] || {};
        const days = Array.isArray(s.days) ? s.days : [];
        if (days.length && !days.includes(dow))
          continue;
        if (root._timeInRange(h, m, s.start, s.end))
          return behavior;
      }
    }

    if (p.urgency?.suppressLow && urg === NotificationUrgency.Low)
      return "suppress";
    if (!Array.isArray(p.schedule) || !p.schedule.length)
      return behavior;
    return "bypass";
  }

  // ----- Groups -----
  function _saveGroups() {
    try {
      store.groupsJson = JSON.stringify(root.groupsMap || {});
    } catch (e) {}
  }

  function _loadGroups() {
    const parsed = _parseJson(store.groupsJson || "{}", {});
    root.groupsMap = parsed && typeof parsed === "object" ? parsed : {};
  }

  function _touchGroup(notification) {
    const appName = String(notification?.appName || "");
    const summaryKey = String(notification?.summaryKey || notification?.summary || "");
    if (!appName || !summaryKey)
      return "";
    const groupId = appName + ":" + summaryKey;
    const nowTs = Date.now();
    const nId = String(notification?.id || notification?.dbusId) || "gen-" + nowTs + "-" + Math.floor(Math.random() * 100000);

    const entry = root.groupsMap[groupId] || {
      id: groupId,
      title: summaryKey,
      children: [],
      expanded: false,
      updatedAt: nowTs,
      appName: appName
    };
    entry.children = [nId].concat(entry.children || []);
    entry.updatedAt = nowTs;
    root.groupsMap[groupId] = entry;
    _saveGroups();
    return groupId;
  }

  function groups() {
    const arr = Object.values(root.groupsMap || {});
    arr.sort((a, b) => (b?.updatedAt || 0) - (a?.updatedAt || 0));
    return arr;
  }

  // ----- Lifecycle / presentation -----
  function _present(notification) {
    if (!notification)
      return null;

    // DND at arrival
    const dndDecision = _evalDnd(notification);
    const showNow = dndDecision === "bypass";
    const allowQueue = dndDecision !== "suppress";

    const wrapper = notifComp.createObject(root, {
      popup: showNow,
      notification
    });
    if (!wrapper)
      return null;

    if (notification.__local === true)
      notification.wrapperRef = wrapper;

    wrapper.groupId = _touchGroup(notification);
    root.all = root.all.concat([wrapper]);
    _addToHistory(wrapper);

    if (allowQueue) {
      root.queue = root.queue.concat([wrapper]);
      _processQueue();
    }
    return wrapper;
  }

  function _processQueue() {
    if (root._addGateBusy || root.queue.length === 0)
      return;
    if (root.visible.length >= root.maxVisible)
      return;

    const q = root.queue.slice();
    const next = q.shift();
    root.queue = q;
    if (!next)
      return;

    // Re-check DND at display time
    const effective = _evalDnd(next.notification);
    if (effective === "queue" || effective === "suppress") {
      root.queue = [next].concat(root.queue);
      return;
    }

    root.visible = root.visible.concat([next]);
    next.popup = true;
    next.status = "visible";

    if (next.timer.interval > 0)
      next.timer.start();

    root._addGateBusy = true;
    addGate.restart();
  }

  function _onHidden(w) {
    const vIdx = root.visible.indexOf(w);
    if (vIdx !== -1) {
      const vis = root.visible.slice();
      vis.splice(vIdx, 1);
      root.visible = vis;
    }
    if (w.status === "visible")
      w.status = "hidden";

    // Remove local notifications after hiding
    if (w.notification?.__local === true) {
      const aIdx = root.all.indexOf(w);
      if (aIdx !== -1) {
        const a = root.all.slice();
        a.splice(aIdx, 1);
        root.all = a;
      }
    }
    _processQueue();
  }

  function _release(w) {
    const vis = root.visible.slice();
    const vi = vis.indexOf(w);
    if (vi !== -1) {
      vis.splice(vi, 1);
      root.visible = vis;
    }
    const q = root.queue.slice();
    const qi = q.indexOf(w);
    if (qi !== -1) {
      q.splice(qi, 1);
      root.queue = q;
    }
  }

  // ----- Public API -----
  function _urgencyToString(urgency) {
    switch (Number(urgency)) {
    case NotificationUrgency.Low:
      return "low";
    case NotificationUrgency.Critical:
      return "critical";
    default:
      return "normal";
    }
  }

  function acknowledge(id) {
    const searchId = String(id || "");
    for (let i = 0; i < root.all.length; i++) {
      const w = root.all[i];
      const wid = String(w?.id || w?.notification?.id || "");
      if (wid === searchId) {
        w.popup = false;
        w.status = "hidden";
        return {
          ok: true
        };
      }
    }
    return {
      ok: false,
      error: "not-found"
    };
  }

  function dismissNotification(wrapper) {
    if (!wrapper?.notification)
      return;
    wrapper.popup = false;
    if (typeof wrapper.notification.dismiss === "function")
      wrapper.notification.dismiss();
  }

  function executeAction(id, actionId) {
    const searchId = String(id || "");
    const searchActionId = String(actionId || "");
    for (let i = 0; i < root.all.length; i++) {
      const w = root.all[i];
      const wid = String(w?.id || w?.notification?.id || "");
      if (wid === searchId) {
        const actions = w.actionsModel || [];
        for (let ai = 0; ai < actions.length; ai++) {
          if (String(actions[ai].id) === searchActionId) {
            // _logAction happens inside trigger()
            actions[ai].trigger();
            return {
              ok: true
            };
          }
        }
        return {
          ok: false,
          error: "action-not-found"
        };
      }
    }
    return {
      ok: false,
      error: "not-found"
    };
  }

  function reply(id, text) {
    const searchId = String(id || "");
    for (let i = 0; i < root.all.length; i++) {
      const w = root.all[i];
      const wid = String(w?.id || w?.notification?.id || "");
      if (wid === searchId)
        return w.submitReply(text);
    }
    return {
      ok: false,
      error: "not-found"
    };
  }

  function clearPopups() {
    const vis = root.visible.slice();
    for (let i = 0; i < vis.length; i++)
      vis[i].popup = false;
    root.queue = [];
  }

  function clearAll() {
    const items = root.all.slice();
    for (let i = 0; i < items.length; i++) {
      const w = items[i];
      if (!w)
        continue;
      if (typeof w.notification?.dismiss === "function")
        w.notification.dismiss();
      if (w.notification?.__local === true) {
        const idx = root.all.indexOf(w);
        if (idx !== -1) {
          const a = root.all.slice();
          a.splice(idx, 1);
          root.all = a;
        }
      }
    }
    root.queue = [];
    const vis = root.visible.slice();
    for (let i = 0; i < vis.length; i++)
      vis[i].popup = false;
  }

  function clearHistory() {
    historyModel.clear();
    _saveHistory();
  }

  function list(filters) {
    const f = filters || {};
    const inSet = (v, s) => !s ? true : Array.isArray(s) ? s.includes(v) : s === v;
    return root.all.filter(w => {
      if (!w)
        return false;
      const n = w.notification;
      const app = String(n?.appName || "");
      const urg = _urgencyToString(n ? n.urgency : NotificationUrgency.Normal);
      const ts = w.time ? w.time.getTime() : Date.now();
      if (f.status && !inSet(String(w.status || ""), f.status))
        return false;
      if (f.urgency && !inSet(urg, f.urgency))
        return false;
      if (f.app && !inSet(app, f.app))
        return false;
      if (f.from && ts < f.from)
        return false;
      if (f.to && ts > f.to)
        return false;
      return true;
    });
  }

  function send(summary, body, options) {
    const opt = options || {};
    const genId = "local-" + root._localIdSeq++;

    const urgency = (() => {
        const u = opt.urgency !== undefined ? opt.urgency : NotificationUrgency.Normal;
        if (typeof u === "string") {
          switch (u.toLowerCase()) {
          case "low":
            return NotificationUrgency.Low;
          case "critical":
            return NotificationUrgency.Critical;
          default:
            return NotificationUrgency.Normal;
          }
        }
        return Number(u);
      })();

    const reply = (() => {
        const ro = opt.reply || {};
        if (!ro.enabled)
          return null;
        return {
          enabled: true,
          placeholder: String(ro.placeholder || ""),
          minLength: Number(ro.minLength || 0),
          maxLength: Number(ro.maxLength || 0),
          submitted: null
        };
      })();

    const localNotification = localNotifComp.createObject(root, {
      id: genId,
      summary: String(summary || ""),
      body: String(body || ""),
      bodyFormat: String(opt.bodyFormat || "plain"),
      appName: String(opt.appName || "notify-send"),
      appIcon: String(opt.appIcon || ""),
      image: String(opt.image || ""),
      summaryKey: String(opt.summaryKey || ""),
      urgency,
      expireTimeout: typeof opt.expireTimeout === "number" ? opt.expireTimeout : -1,
      actions: Array.isArray(opt.actions) ? opt.actions : [],
      reply
    });
    if (!localNotification)
      return "";
    _present(localNotification);
    return genId;
  }

  function setDndPolicy(patch) {
    function merge(base, p) {
      const m = {};
      for (const k in base) {
        if (Object.prototype.hasOwnProperty.call(base, k))
          m[k] = base[k];
      }
      for (const k in p) {
        if (!Object.prototype.hasOwnProperty.call(p, k))
          continue;
        const bv = base[k];
        const pv = p[k];
        m[k] = pv && typeof pv === "object" && !Array.isArray(pv) ? merge(bv || {}, pv) : pv;
      }
      return m;
    }
    root.dndPolicy = merge({
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
    root.dndChanged(!!root.dndPolicy.enabled, root.dndPolicy);
    if (!root.dndPolicy.enabled)
      _processQueue();
  }

  // ----- Logging -----
  function _logAction(id, actionId) {
    const rec = {
      notificationId: String(id || ""),
      actionId: String(actionId || ""),
      at: Date.now()
    };
    root.actionLog = (root.actionLog || []).concat([rec]);
    _saveLogs();
  }

  function _logReply(id, text) {
    const rec = {
      notificationId: String(id || ""),
      text: String(text || ""),
      at: Date.now()
    };
    root.replyLog = (root.replyLog || []).concat([rec]);
    _saveLogs();

    let appName = "";
    let summary = "";
    for (let i = 0; i < root.all.length; i++) {
      const w = root.all[i];
      const wid = String(w?.id || w?.notification?.id || "");
      if (wid === String(id)) {
        appName = String(w.notification?.appName || "");
        summary = String(w.notification?.summary || "");
        break;
      }
    }
    root.replySubmitted(String(id), String(text), appName, summary);
  }

  // ----- Persistence -----
  PersistentProperties {
    id: store
    property string actionLogJson: "[]"
    property string groupsJson: "{}"
    property string historyStoreJson: "[]"
    property string replyLogJson: "[]"
    reloadableId: "NotificationService"
  }

  // ----- Timers -----
  Timer {
    id: addGate
    interval: root._enterAnimMs + 40
    repeat: false
    onTriggered: {
      root._addGateBusy = false;
      root._processQueue();
    }
  }

  Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: root._timePulse = !root._timePulse
  }

  // ----- Components -----
  Component {
    id: notifComp
    NotifWrapper {}
  }

  Component {
    id: localNotifComp
    LocalNotification {}
  }

  component LocalNotification: QtObject {
    id: ln

    readonly property bool __local: true
    property var actions: []
    property string appIcon: ""
    property string appName: ""
    property string body: ""
    property string bodyFormat: "plain" // "plain" | "markup"
    property int expireTimeout: -1
    property string id: ""
    property string image: ""
    property var reply: null
    property string summary: ""
    property string summaryKey: ""
    property int urgency: NotificationUrgency.Normal
    property QtObject wrapperRef

    function activateAction(actionId) {
      invokeAction(actionId);
    }
    function dismiss() {
      if (ln.wrapperRef)
        ln.wrapperRef.popup = false;
    }
    function invokeAction(actionId) {
      root.actionInvoked(String(ln.summary || ""), String(ln.appName || ""), String(actionId || ""), String(ln.body || ""));
    }
  }

  component NotifWrapper: QtObject {
    id: wrapper

    required property var notification
    property bool popup: false
    property string status: "queued"
    property string groupId: ""

    readonly property string id: String(wrapper.notification?.id || wrapper.notification?.dbusId || "")
    readonly property string appIcon: String(wrapper.notification?.appIcon || "")
    readonly property string appName: String(wrapper.notification?.appName || "")
    readonly property string summary: String(wrapper.notification?.summary || "")
    readonly property string body: String(wrapper.notification?.body || "")
    readonly property string bodyFormat: String(wrapper.notification?.bodyFormat || "plain")
    readonly property string bodySafe: {
      const fmt = String(wrapper.bodyFormat || "plain");
      return fmt === "markup" ? root._sanitizeHtml(String(wrapper.body || "")) : wrapper.body;
    }
    readonly property string image: String(wrapper.notification?.image || "")
    readonly property string imageSource: wrapper.image || ""
    readonly property string iconSource: Utils.resolveIconSource(String(wrapper.appName || ""), String(wrapper.appIcon || ""), "dialog-information")
    readonly property int urgency: Number(wrapper.notification?.urgency ?? NotificationUrgency.Normal)
    readonly property int expireTimeout: Number(typeof wrapper.notification?.expireTimeout === "number" ? wrapper.notification?.expireTimeout : -1)

    readonly property var replyModel: wrapper.notification?.reply || null

    readonly property date time: new Date()
    readonly property string timeStr: {
      root._timePulse;
      const diff = Date.now() - time.getTime();
      const m = Math.floor(diff / 60000);
      const h = Math.floor(m / 60);
      if (h < 1 && m < 1)
        return "now";
      if (h < 1)
        return `${m}m`;
      return `${h}h`;
    }

    readonly property var actionsModel: {
      const raw = wrapper.notification?.actions || [];
      if (!raw.length)
        return [];
      if (typeof raw[0] === "string") {
        const out = [];
        for (let i = 0; i + 1 < raw.length; i += 2)
          out.push(_mkActionEntry(wrapper.notification, String(raw[i]), String(raw[i + 1]), ""));
        return out;
      }
      return raw.map(a => _mkActionEntry(wrapper.notification, String(a?.id || a?.action || a?.key || a?.name || ""), String(a?.title || a?.label || a?.text || ""), a ? a.icon || a.iconName || a.icon_id || "" : ""));
    }

    readonly property RetainableLock retainLock: RetainableLock {
      object: wrapper.notification?.__local === true ? null : wrapper.notification

      onAboutToDestroy: wrapper.destroy()
      onDropped: {
        const idx = root.all.indexOf(wrapper);
        if (idx !== -1) {
          const a = root.all.slice();
          a.splice(idx, 1);
          root.all = a;
        }
        root._release(wrapper);
      }
    }

    readonly property Timer timer: Timer {
      interval: {
        const cfg = wrapper.expireTimeout;
        if (typeof cfg === "number" && cfg > 0)
          return cfg;
        switch (wrapper.urgency) {
        case NotificationUrgency.Critical:
          return root.timeoutCritical;
        case NotificationUrgency.Low:
          return root.timeoutLow;
        default:
          return root.timeoutNormal;
        }
      }
      repeat: false
      running: false

      onTriggered: {
        if (root.expirePopups && interval > 0)
          wrapper.popup = false;
      }
    }

    function _mkActionEntry(notification, id, title, iconName) {
      const iconSource = iconName ? Quickshell.iconPath(String(iconName), true) : "";
      return {
        id,
        title,
        iconName: iconName || "",
        iconSource,
        trigger: function () {
          if (!notification)
            return;
          root._logAction(wrapper.id || notification.id || "", String(id));
          if (notification.__local === true) {
            root.actionInvoked(String(notification.summary || ""), String(notification.appName || ""), String(id), String(notification.body || ""));
            if (typeof notification.dismiss === "function")
              notification.dismiss();
            else
              wrapper.popup = false;
          } else {
            if (typeof notification.invokeAction === "function")
              notification.invokeAction(String(id));
            else if (typeof notification.activateAction === "function")
              notification.activateAction(String(id));
            if (typeof notification.dismiss === "function")
              notification.dismiss();
            else
              wrapper.popup = false;
          }
        }
      };
    }

    function submitReply(text) {
      const r = replyModel;
      if (!r?.enabled)
        return {
          ok: false,
          error: "reply-not-enabled"
        };
      const t = String(text || "");
      if (r.minLength > 0 && t.length < r.minLength)
        return {
          ok: false,
          error: "too-short"
        };
      if (r.maxLength > 0 && t.length > r.maxLength)
        return {
          ok: false,
          error: "too-long"
        };
      r.submitted = {
        text: t,
        at: Date.now()
      };
      root._logReply(wrapper.id, t);
      return {
        ok: true
      };
    }

    onPopupChanged: if (!popup)
      root._onHidden(wrapper)
  }

  // ----- Sanitizer -----
  function _sanitizeHtml(input) {
    try {
      let s = String(input || "");
      s = s.replace(/<\/(?:script|style)>/gi, "");
      s = s.replace(/<(?:script|style)[\s\S]*?>[\s\S]*?<\/(?:script|style)>/gi, "");
      s = s.replace(/<([^>]+)>/g, function (m, tagContent) {
        const tag = String(tagContent).trim().split(/\s+/)[0].toLowerCase();
        const allowed = ["b", "strong", "i", "em", "u", "a", "br", "p", "span"];
        if (!allowed.includes(tag) && !allowed.includes(tag.replace(/^\//, "")))
          return "";
        if (tag === "a" || tag === "/a")
          return m.replace(/javascript:/gi, "");
        return m;
      });
      return s;
    } catch (e) {
      return String(input || "");
    }
  }

  Component.onCompleted: {
    _loadHistory();
    _loadLogs();
    _loadGroups();
  }
}
