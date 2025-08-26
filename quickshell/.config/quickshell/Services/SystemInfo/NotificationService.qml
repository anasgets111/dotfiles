pragma Singleton
pragma ComponentBehavior: Bound
import qs.Services.Utils

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    signal actionInvoked(string summary, string appName, string actionId, string body)
    signal replySubmitted(string id, string text, string appName, string summary)
    signal dndChanged(bool enabled, var policy)

    property int maxVisible: 3
    property bool expirePopups: true
    property int timeoutLow: 5000
    property int timeoutNormal: 8000
    property int timeoutCritical: 0

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

    property var all: [] // wrappers (active + hidden locals)
    property var visible: [] // wrappers shown as popups
    property var queue: [] // wrappers waiting to show

    readonly property int _enterAnimMs: 300
    property bool _addGateBusy: false
    property bool _timePulse: false
    property int _localIdSeq: 1
    readonly property ListModel historyModel: ListModel {}
    property int maxHistory: 100
    property var actionLog: [] // [{notificationId, actionId, at}]
    property var replyLog: [] // [{notificationId, text, at}]
    property var groupsMap: ({}) // groupId -> { id, title, children, expanded, updatedAt }

    PersistentProperties {
        id: store
        reloadableId: "NotificationService"
        property string historyStoreJson: "[]"
        property string actionLogJson: "[]"
        property string replyLogJson: "[]"
        property string groupsJson: "{}"
    }

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

    Component.onCompleted: {
        _loadHistory();
        _loadLogs();
        _loadGroups();
    }

    component LocalNotification: QtObject {
        id: ln
        property string id: ""
        property string summary: ""
        property string body: ""
        property string bodyFormat: "plain" // "plain" | "markup" (sanitized)
        property string appIcon: ""
        property string appName: ""
        property string image: ""
        property string summaryKey: ""
        property int urgency: NotificationUrgency.Normal
        property int expireTimeout: -1
        property var actions: []
        property var reply: null
        property QtObject wrapperRef
        readonly property bool __local: true

        function invokeAction(actionId) {
            root.actionInvoked(String(ln.summary || ""), String(ln.appName || ""), String(actionId || ""), String(ln.body || ""));
        }
        function activateAction(actionId) {
            invokeAction(actionId);
        }
        function dismiss() {
            if (ln.wrapperRef)
                ln.wrapperRef.popup = false;
        }
    }

    function send(summary, body, options) {
        const o = options || {};
        const genId = "local-" + root._localIdSeq++;
        const urgency = (() => {
                const u = o.urgency !== undefined ? o.urgency : NotificationUrgency.Normal;
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
                const r = o.reply || {};
                if (!r.enabled)
                    return null;
                return {
                    enabled: true,
                    placeholder: String(r.placeholder || ""),
                    minLength: Number(r.minLength || 0),
                    maxLength: Number(r.maxLength || 0),
                    submitted: null
                };
            })();
        const n = localNotifComp.createObject(root, {
            id: genId,
            summary: String(summary || ""),
            body: String(body || ""),
            bodyFormat: String(o.bodyFormat || "plain"),
            appName: String(o.appName || "notify-send"),
            appIcon: String(o.appIcon || ""),
            image: String(o.image || ""),
            summaryKey: String(o.summaryKey || ""),
            urgency,
            expireTimeout: typeof o.expireTimeout === "number" ? o.expireTimeout : -1,
            actions: Array.isArray(o.actions) ? o.actions : [],
            reply
        });
        if (!n)
            return "";
        _present(n);
        return genId;
    }

    function _timeInRange(nowH, nowM, startStr, endStr) {
        const toHM = s => {
            const [h, m] = String(s || "0:0").split(":");
            const hh = Math.max(0, Math.min(23, Number(h || 0)));
            const mm = Math.max(0, Math.min(59, Number(m || 0)));
            return [hh, mm];
        };
        const [sh, sm] = toHM(startStr);
        const [eh, em] = toHM(endStr);
        const start = sh * 60 + sm;
        const end = eh * 60 + em;
        const now = nowH * 60 + nowM;
        if (start === end)
            return false;
        if (start < end)
            return now >= start && now < end;
        return now >= start || now < end; // overnight
    }

    function _evalDnd(notification) {
        const p = root.dndPolicy || {};
        if (!p.enabled)
            return "bypass";

        const urg = notification && notification.urgency !== undefined ? Number(notification.urgency) : NotificationUrgency.Normal;

        if (p.urgency?.bypassCritical && urg === NotificationUrgency.Critical)
            return "bypass";

        if (p.appRules) {
            const name = String(notification?.appName || "");
            const allow = Array.isArray(p.appRules.allow) ? p.appRules.allow : [];
            const deny = Array.isArray(p.appRules.deny) ? p.appRules.deny : [];
            if (allow.length && !allow.includes(name))
                return p.behavior === "suppress" ? "suppress" : "queue";
            if (deny.includes(name))
                return p.behavior === "suppress" ? "suppress" : "queue";
        }

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
                    return p.behavior === "suppress" ? "suppress" : "queue";
            }
        }

        if (p.urgency?.suppressLow && urg === NotificationUrgency.Low)
            return "suppress";

        if (!(Array.isArray(p.schedule) && p.schedule.length))
            return p.behavior === "suppress" ? "suppress" : "queue";
        return "bypass";
    }

    function setDndPolicy(patch) {
        function merge(a, b) {
            const out = {};
            for (const k in a) {
                if (Object.prototype.hasOwnProperty.call(a, k))
                    out[k] = a[k];
            }
            for (const k in b) {
                if (!Object.prototype.hasOwnProperty.call(b, k))
                    continue;
                const va = a[k];
                const vb = b[k];
                out[k] = vb && typeof vb === "object" && !Array.isArray(vb) ? merge(va || {}, vb) : vb;
            }
            return out;
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

    // ----- Groups -----
    function _touchGroup(notification) {
        const app = String(notification?.appName || "");
        const key = String(notification?.summaryKey || notification?.summary || "");
        if (!app || !key)
            return "";
        const gid = app + ":" + key;
        const now = Date.now();
        const nid = String(notification?.id || notification?.dbusId) || "gen-" + now + "-" + Math.floor(Math.random() * 100000);
        const g = root.groupsMap[gid] || {
            id: gid,
            title: key,
            children: [],
            expanded: false,
            updatedAt: now,
            appName: app
        };
        g.children = [nid].concat(g.children || []);
        g.updatedAt = now;
        root.groupsMap[gid] = g;
        _saveGroups();
        return gid;
    }

    function groups() {
        const arr = [];
        const m = root.groupsMap || {};
        for (const k in m)
            arr.push(m[k]);
        arr.sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0));
        return arr;
    }

    function toggleGroup(groupId, expanded) {
        const g = root.groupsMap[groupId];
        if (!g)
            return;
        g.expanded = expanded === undefined ? !g.expanded : !!expanded;
        g.updatedAt = Date.now();
        root.groupsMap[groupId] = g;
        _saveGroups();
    }

    // ----- Sanitizer -----
    function _sanitizeHtml(input) {
        try {
            let s = String(input || "");
            s = s.replace(/<\/(?:script|style)>/gi, "");
            s = s.replace(/<(?:script|style)[\s\S]*?>[\s\S]*?<\/(?:script|style)>/gi, "");
            s = s.replace(/<([^>]+)>/g, function (m, p1) {
                const tag = String(p1).trim().split(/\s+/)[0].toLowerCase();
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

    // ----- Server -----
    readonly property NotificationServer server: NotificationServer {
        id: notificationServer
        keepOnReload: false
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        persistenceSupported: true
        inlineReplySupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        onNotification: function (notification) {
            root._present(notification);
        }
    }

    component NotifWrapper: QtObject {
        id: wrapper

        property bool popup: false
        property string status: "queued"
        // grouping id for this notification (app:summaryKey)
        property string groupId: ""

        required property var notification

        readonly property string id: String(wrapper.notification?.id || wrapper.notification?.dbusId || "")
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

        readonly property string summary: String(wrapper.notification?.summary || "")
        readonly property string body: String(wrapper.notification?.body || "")
        readonly property string bodyFormat: String(wrapper.notification?.bodyFormat || "plain")
        readonly property string appIcon: String(wrapper.notification?.appIcon || "")
        readonly property string appName: String(wrapper.notification?.appName || "")
        readonly property string image: String(wrapper.notification?.image || "")
        readonly property int urgency: Number(wrapper.notification?.urgency ?? NotificationUrgency.Normal)
        readonly property int expireTimeout: Number(typeof wrapper.notification?.expireTimeout === "number" ? wrapper.notification?.expireTimeout : -1)
        readonly property var replyModel: wrapper.notification?.reply || null

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

        readonly property string iconSource: Utils.resolveIconSource(String(wrapper.appName || ""), String(wrapper.appIcon || ""), "dialog-information")

        readonly property string imageSource: wrapper.image || ""

        readonly property string bodySafe: {
            const fmt = String(wrapper.bodyFormat || "plain");
            return fmt === "markup" ? root._sanitizeHtml(String(wrapper.body || "")) : wrapper.body;
        }

        function _mkActionEntry(n, id, title, iconName) {
            const iconSource = iconName ? Quickshell.iconPath(String(iconName), true) : "";
            return {
                id,
                title,
                iconName: iconName || "",
                iconSource,
                trigger: function () {
                    if (!n)
                        return;
                    root._logAction(wrapper.id || n.id || "", String(id));
                    if (n.__local === true) {
                        root.actionInvoked(String(n.summary || ""), String(n.appName || ""), String(id), String(n.body || ""));
                        if (typeof n.dismiss === "function")
                            n.dismiss();
                        else
                            wrapper.popup = false;
                    } else {
                        if (typeof n.invokeAction === "function")
                            n.invokeAction(String(id));
                        else if (typeof n.activateAction === "function")
                            n.activateAction(String(id));
                        if (typeof n.dismiss === "function")
                            n.dismiss();
                        else
                            wrapper.popup = false;
                    }
                }
            };
        }

        readonly property var actionsModel: {
            const a = wrapper.notification?.actions || [];
            if (!a.length)
                return [];
            if (typeof a[0] === "string") {
                const out = [];
                for (let i = 0; i + 1 < a.length; i += 2)
                    out.push(_mkActionEntry(wrapper.notification, String(a[i]), String(a[i + 1]), ""));
                return out;
            }
            return a.map(x => _mkActionEntry(wrapper.notification, String(x?.id || x?.action || x?.key || x?.name || ""), String(x?.title || x?.label || x?.text || ""), x ? x.icon || x.iconName || x.icon_id || "" : ""));
        }

        readonly property Timer timer: Timer {
            interval: {
                const t = wrapper.expireTimeout;
                if (typeof t === "number" && t > 0)
                    return t;
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

        readonly property RetainableLock retainLock: RetainableLock {
            object: wrapper.notification?.__local === true ? null : wrapper.notification
            onDropped: {
                const idx = root.all.indexOf(wrapper);
                if (idx !== -1) {
                    const arr = root.all.slice();
                    arr.splice(idx, 1);
                    root.all = arr;
                }
                root._release(wrapper);
            }
            onAboutToDestroy: wrapper.destroy()
        }

        onPopupChanged: if (!popup)
            root._onHidden(wrapper)
    }

    Component {
        id: notifComp
        NotifWrapper {}
    }
    Component {
        id: localNotifComp
        LocalNotification {}
    }

    function _present(notification) {
        if (!notification)
            return null;

        // DND at arrival
        const dnd = _evalDnd(notification); // "bypass" | "queue" | "suppress"
        const showNow = dnd === "bypass";
        const allowQueue = dnd !== "suppress";

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
        const eff = _evalDnd(next.notification);
        if (eff === "queue" || eff === "suppress") {
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
        const i = root.visible.indexOf(w);
        if (i !== -1) {
            const v = root.visible.slice();
            v.splice(i, 1);
            root.visible = v;
        }
        if (w.status === "visible")
            w.status = "hidden";

        // Remove local notifications after hiding
        if (w.notification?.__local === true) {
            const ai = root.all.indexOf(w);
            if (ai !== -1) {
                const a = root.all.slice();
                a.splice(ai, 1);
                root.all = a;
            }
        }
        _processQueue();
    }

    function _release(w) {
        const v = root.visible.slice();
        const vi = v.indexOf(w);
        if (vi !== -1) {
            v.splice(vi, 1);
            root.visible = v;
        }
        const q = root.queue.slice();
        const qi = q.indexOf(w);
        if (qi !== -1) {
            q.splice(qi, 1);
            root.queue = q;
        }
    }

    function list(filters) {
        const f = filters || {};
        const inSet = (val, set) => !set ? true : Array.isArray(set) ? set.includes(val) : set === val;
        const urgStr = u => {
            switch (Number(u)) {
            case NotificationUrgency.Low:
                return "low";
            case NotificationUrgency.Critical:
                return "critical";
            default:
                return "normal";
            }
        };
        const out = [];
        for (let i = 0; i < root.all.length; i++) {
            const w = root.all[i];
            if (!w)
                continue;
            const n = w.notification;
            const app = String(n?.appName || "");
            const us = urgStr(n ? n.urgency : NotificationUrgency.Normal);
            const ts = w.time ? w.time.getTime() : Date.now();
            if (f.status && !inSet(String(w.status || ""), f.status))
                continue;
            if (f.urgency && !inSet(us, f.urgency))
                continue;
            if (f.app && !inSet(app, f.app))
                continue;
            if (f.from && ts < f.from)
                continue;
            if (f.to && ts > f.to)
                continue;
            out.push(w);
        }
        return out;
    }

    function acknowledge(id) {
        const s = String(id || "");
        for (let i = 0; i < root.all.length; i++) {
            const w = root.all[i];
            const wid = String(w?.id || w?.notification?.id || "");
            if (wid === s) {
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
                const ai = root.all.indexOf(w);
                if (ai !== -1) {
                    const a = root.all.slice();
                    a.splice(ai, 1);
                    root.all = a;
                }
            }
        }
        root.queue = [];
        const vis = root.visible.slice();
        for (let i = 0; i < vis.length; i++)
            vis[i].popup = false;
    }

    function executeAction(id, actionId) {
        const s = String(id || "");
        const a = String(actionId || "");
        for (let i = 0; i < root.all.length; i++) {
            const w = root.all[i];
            const wid = String(w?.id || w?.notification?.id || "");
            if (wid === s) {
                const actions = w.actionsModel || [];
                for (let j = 0; j < actions.length; j++) {
                    if (String(actions[j].id) === a) {
                        root._logAction(wid, a);
                        actions[j].trigger();
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
        const s = String(id || "");
        for (let i = 0; i < root.all.length; i++) {
            const w = root.all[i];
            const wid = String(w?.id || w?.notification?.id || "");
            if (wid === s)
                return w.submitReply(text);
        }
        return {
            ok: false,
            error: "not-found"
        };
    }

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

        let app = "";
        let sum = "";
        for (let i = 0; i < root.all.length; i++) {
            const w = root.all[i];
            const wid = String(w?.id || w?.notification?.id || "");
            if (wid === String(id)) {
                app = String(w.notification?.appName || "");
                sum = String(w.notification?.summary || "");
                break;
            }
        }
        root.replySubmitted(String(id), String(text), app, sum);
    }

    function _loadLogs() {
        try {
            const a = JSON.parse(store.actionLogJson || "[]");
            root.actionLog = Array.isArray(a) ? a : [];
        } catch (e) {
            root.actionLog = [];
        }
        try {
            const r = JSON.parse(store.replyLogJson || "[]");
            root.replyLog = Array.isArray(r) ? r : [];
        } catch (e) {
            root.replyLog = [];
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

    function _loadHistory() {
        historyModel.clear();
        let items = [];
        try {
            items = JSON.parse(store.historyStoreJson || "[]");
            if (!Array.isArray(items))
                items = [];
        } catch (e) {
            items = [];
        }
        for (let i = 0; i < items.length; i++) {
            const it = items[i];
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

    function _saveHistory() {
        const arr = [];
        for (let i = 0; i < historyModel.count; i++) {
            const n = historyModel.get(i);
            arr.push({
                id: n.id || "",
                summary: n.summary,
                body: n.body,
                bodyFormat: n.bodyFormat || "plain",
                image: n.image || "",
                appName: n.appName,
                urgency: n.urgency,
                groupId: n.groupId || "",
                timestamp: n.timestamp instanceof Date ? n.timestamp.getTime() : n.timestamp
            });
        }
        store.historyStoreJson = JSON.stringify(arr);
    }

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

    function clearHistory() {
        historyModel.clear();
        _saveHistory();
    }

    function _loadGroups() {
        try {
            const g = JSON.parse(store.groupsJson || "{}");
            root.groupsMap = g && typeof g === "object" ? g : {};
        } catch (e) {
            root.groupsMap = {};
        }
    }
    function _saveGroups() {
        try {
            store.groupsJson = JSON.stringify(root.groupsMap || {});
        } catch (e) {}
    }
}
