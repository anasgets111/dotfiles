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
        const optionsObj = options || {};
        const genId = "local-" + root._localIdSeq++;
        const urgency = (() => {
                const urgencyInput = optionsObj.urgency !== undefined ? optionsObj.urgency : NotificationUrgency.Normal;
                if (typeof urgencyInput === "string") {
                    switch (urgencyInput.toLowerCase()) {
                    case "low":
                        return NotificationUrgency.Low;
                    case "critical":
                        return NotificationUrgency.Critical;
                    default:
                        return NotificationUrgency.Normal;
                    }
                }
                return Number(urgencyInput);
            })();
        const reply = (() => {
                const replyOptions = optionsObj.reply || {};
                if (!replyOptions.enabled)
                    return null;
                return {
                    enabled: true,
                    placeholder: String(replyOptions.placeholder || ""),
                    minLength: Number(replyOptions.minLength || 0),
                    maxLength: Number(replyOptions.maxLength || 0),
                    submitted: null
                };
            })();
        const localNotification = localNotifComp.createObject(root, {
            id: genId,
            summary: String(summary || ""),
            body: String(body || ""),
            bodyFormat: String(optionsObj.bodyFormat || "plain"),
            appName: String(optionsObj.appName || "notify-send"),
            appIcon: String(optionsObj.appIcon || ""),
            image: String(optionsObj.image || ""),
            summaryKey: String(optionsObj.summaryKey || ""),
            urgency,
            expireTimeout: typeof optionsObj.expireTimeout === "number" ? optionsObj.expireTimeout : -1,
            actions: Array.isArray(optionsObj.actions) ? optionsObj.actions : [],
            reply
        });
        if (!localNotification)
            return "";
        _present(localNotification);
        return genId;
    }

    function _timeInRange(nowH, nowM, startStr, endStr) {
        const toHM = timeString => {
            const [hoursRaw, minutesRaw] = String(timeString || "0:0").split(":");
            const hours = Math.max(0, Math.min(23, Number(hoursRaw || 0)));
            const minutes = Math.max(0, Math.min(59, Number(minutesRaw || 0)));
            return [hours, minutes];
        };
        const [startHours, startMinutes] = toHM(startStr);
        const [endHours, endMinutes] = toHM(endStr);
        const startTotal = startHours * 60 + startMinutes;
        const endTotal = endHours * 60 + endMinutes;
        const nowTotal = nowH * 60 + nowM;
        if (startTotal === endTotal)
            return false;
        if (startTotal < endTotal)
            return nowTotal >= startTotal && nowTotal < endTotal;
        return nowTotal >= startTotal || nowTotal < endTotal; // overnight
    }

    function _evalDnd(notification) {
        const policy = root.dndPolicy || {};
        if (!policy.enabled)
            return "bypass";

        const urgency = notification && notification.urgency !== undefined ? Number(notification.urgency) : NotificationUrgency.Normal;

        if (policy.urgency?.bypassCritical && urgency === NotificationUrgency.Critical)
            return "bypass";

        if (policy.appRules) {
            const appName = String(notification?.appName || "");
            const allow = Array.isArray(policy.appRules.allow) ? policy.appRules.allow : [];
            const deny = Array.isArray(policy.appRules.deny) ? policy.appRules.deny : [];
            if (allow.length && !allow.includes(appName))
                return policy.behavior === "suppress" ? "suppress" : "queue";
            if (deny.includes(appName))
                return policy.behavior === "suppress" ? "suppress" : "queue";
        }

        if (Array.isArray(policy.schedule) && policy.schedule.length) {
            const nowDate = new Date();
            const dayOfWeek = nowDate.getDay();
            const currentHour = nowDate.getHours();
            const currentMinute = nowDate.getMinutes();
            for (let index = 0; index < policy.schedule.length; index++) {
                const scheduleItem = policy.schedule[index] || {};
                const days = Array.isArray(scheduleItem.days) ? scheduleItem.days : [];
                if (days.length && !days.includes(dayOfWeek))
                    continue;
                if (root._timeInRange(currentHour, currentMinute, scheduleItem.start, scheduleItem.end))
                    return policy.behavior === "suppress" ? "suppress" : "queue";
            }
        }

        if (policy.urgency?.suppressLow && urgency === NotificationUrgency.Low)
            return "suppress";

        if (!(Array.isArray(policy.schedule) && policy.schedule.length))
            return policy.behavior === "suppress" ? "suppress" : "queue";
        return "bypass";
    }

    function setDndPolicy(patch) {
        function merge(base, patchObj) {
            const merged = {};
            for (const key in base) {
                if (Object.prototype.hasOwnProperty.call(base, key))
                    merged[key] = base[key];
            }
            for (const key in patchObj) {
                if (!Object.prototype.hasOwnProperty.call(patchObj, key))
                    continue;
                const baseValue = base[key];
                const patchValue = patchObj[key];
                merged[key] = patchValue && typeof patchValue === "object" && !Array.isArray(patchValue) ? merge(baseValue || {}, patchValue) : patchValue;
            }
            return merged;
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
        const appName = String(notification?.appName || "");
        const summaryKey = String(notification?.summaryKey || notification?.summary || "");
        if (!appName || !summaryKey)
            return "";
        const groupId = appName + ":" + summaryKey;
        const nowTimestamp = Date.now();
        const notificationId = String(notification?.id || notification?.dbusId) || "gen-" + nowTimestamp + "-" + Math.floor(Math.random() * 100000);
        const groupEntry = root.groupsMap[groupId] || {
            id: groupId,
            title: summaryKey,
            children: [],
            expanded: false,
            updatedAt: nowTimestamp,
            appName: appName
        };
        groupEntry.children = [notificationId].concat(groupEntry.children || []);
        groupEntry.updatedAt = nowTimestamp;
        root.groupsMap[groupId] = groupEntry;
        _saveGroups();
        return groupId;
    }

    function groups() {
        const groupsArray = [];
        const groupsMapRef = root.groupsMap || {};
        for (const groupKey in groupsMapRef)
            groupsArray.push(groupsMapRef[groupKey]);
        groupsArray.sort((groupA, groupB) => (groupB.updatedAt || 0) - (groupA.updatedAt || 0));
        return groupsArray;
    }

    function toggleGroup(groupId, expanded) {
        const groupEntry = root.groupsMap[groupId];
        if (!groupEntry)
            return;
        groupEntry.expanded = expanded === undefined ? !groupEntry.expanded : !!expanded;
        groupEntry.updatedAt = Date.now();
        root.groupsMap[groupId] = groupEntry;
        _saveGroups();
    }

    // ----- Sanitizer -----
    function _sanitizeHtml(input) {
        try {
            let sanitized = String(input || "");
            sanitized = sanitized.replace(/<\/(?:script|style)>/gi, "");
            sanitized = sanitized.replace(/<(?:script|style)[\s\S]*?>[\s\S]*?<\/(?:script|style)>/gi, "");
            sanitized = sanitized.replace(/<([^>]+)>/g, function (match, tagContent) {
                const tag = String(tagContent).trim().split(/\s+/)[0].toLowerCase();
                const allowedTags = ["b", "strong", "i", "em", "u", "a", "br", "p", "span"];
                if (!allowedTags.includes(tag) && !allowedTags.includes(tag.replace(/^\//, "")))
                    return "";
                if (tag === "a" || tag === "/a")
                    return match.replace(/javascript:/gi, "");
                return match;
            });
            return sanitized;
        } catch (e) {
            return String(input || "");
        }
    }

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

        readonly property var actionsModel: {
            const rawActions = wrapper.notification?.actions || [];
            if (!rawActions.length)
                return [];
            if (typeof rawActions[0] === "string") {
                const actions = [];
                for (let index = 0; index + 1 < rawActions.length; index += 2)
                    actions.push(_mkActionEntry(wrapper.notification, String(rawActions[index]), String(rawActions[index + 1]), ""));
                return actions;
            }
            return rawActions.map(action => _mkActionEntry(wrapper.notification, String(action?.id || action?.action || action?.key || action?.name || ""), String(action?.title || action?.label || action?.text || ""), action ? action.icon || action.iconName || action.icon_id || "" : ""));
        }

        readonly property Timer timer: Timer {
            interval: {
                const configuredTimeout = wrapper.expireTimeout;
                if (typeof configuredTimeout === "number" && configuredTimeout > 0)
                    return configuredTimeout;
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
                const wrapperIndex = root.all.indexOf(wrapper);
                if (wrapperIndex !== -1) {
                    const allCopy = root.all.slice();
                    allCopy.splice(wrapperIndex, 1);
                    root.all = allCopy;
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
        const dndDecision = _evalDnd(notification); // "bypass" | "queue" | "suppress"
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
        const queueCopy = root.queue.slice();
        const nextWrapper = queueCopy.shift();
        root.queue = queueCopy;
        if (!nextWrapper)
            return;

        // Re-check DND at display time
        const effectiveDnd = _evalDnd(nextWrapper.notification);
        if (effectiveDnd === "queue" || effectiveDnd === "suppress") {
            root.queue = [nextWrapper].concat(root.queue);
            return;
        }

        root.visible = root.visible.concat([nextWrapper]);
        nextWrapper.popup = true;
        nextWrapper.status = "visible";

        if (nextWrapper.timer.interval > 0)
            nextWrapper.timer.start();

        root._addGateBusy = true;
        addGate.restart();
    }

    function _onHidden(notifWrapper) {
        const visibleIndex = root.visible.indexOf(notifWrapper);
        if (visibleIndex !== -1) {
            const visibleCopy = root.visible.slice();
            visibleCopy.splice(visibleIndex, 1);
            root.visible = visibleCopy;
        }
        if (notifWrapper.status === "visible")
            notifWrapper.status = "hidden";

        // Remove local notifications after hiding
        if (notifWrapper.notification?.__local === true) {
            const allIndex = root.all.indexOf(notifWrapper);
            if (allIndex !== -1) {
                const allCopy = root.all.slice();
                allCopy.splice(allIndex, 1);
                root.all = allCopy;
            }
        }
        _processQueue();
    }

    function _release(notifWrapper) {
        const visibleCopy = root.visible.slice();
        const visibleIndex = visibleCopy.indexOf(notifWrapper);
        if (visibleIndex !== -1) {
            visibleCopy.splice(visibleIndex, 1);
            root.visible = visibleCopy;
        }
        const queueCopy = root.queue.slice();
        const queueIndex = queueCopy.indexOf(notifWrapper);
        if (queueIndex !== -1) {
            queueCopy.splice(queueIndex, 1);
            root.queue = queueCopy;
        }
    }

    function list(filters) {
        const filtersObj = filters || {};
        const isInSet = (value, set) => !set ? true : Array.isArray(set) ? set.includes(value) : set === value;
        const results = [];
        for (let index = 0; index < root.all.length; index++) {
            const wrapper = root.all[index];
            if (!wrapper)
                continue;
            const notification = wrapper.notification;
            const appName = String(notification?.appName || "");
            const urgencyString = _urgencyToString(notification ? notification.urgency : NotificationUrgency.Normal);
            const timestamp = wrapper.time ? wrapper.time.getTime() : Date.now();
            if (filtersObj.status && !isInSet(String(wrapper.status || ""), filtersObj.status))
                continue;
            if (filtersObj.urgency && !isInSet(urgencyString, filtersObj.urgency))
                continue;
            if (filtersObj.app && !isInSet(appName, filtersObj.app))
                continue;
            if (filtersObj.from && timestamp < filtersObj.from)
                continue;
            if (filtersObj.to && timestamp > filtersObj.to)
                continue;
            results.push(wrapper);
        }
        return results;
    }

    function acknowledge(id) {
        const searchId = String(id || "");
        for (let index = 0; index < root.all.length; index++) {
            const wrapper = root.all[index];
            const wrapperId = String(wrapper?.id || wrapper?.notification?.id || "");
            if (wrapperId === searchId) {
                wrapper.popup = false;
                wrapper.status = "hidden";
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
        const visibleCopy = root.visible.slice();
        for (let index = 0; index < visibleCopy.length; index++)
            visibleCopy[index].popup = false;
        root.queue = [];
    }

    function clearAll() {
        const items = root.all.slice();
        for (let index = 0; index < items.length; index++) {
            const wrapper = items[index];
            if (!wrapper)
                continue;
            if (typeof wrapper.notification?.dismiss === "function")
                wrapper.notification.dismiss();
            if (wrapper.notification?.__local === true) {
                const allIndex = root.all.indexOf(wrapper);
                if (allIndex !== -1) {
                    const allCopy = root.all.slice();
                    allCopy.splice(allIndex, 1);
                    root.all = allCopy;
                }
            }
        }
        root.queue = [];
        const visibleCopy = root.visible.slice();
        for (let index = 0; index < visibleCopy.length; index++)
            visibleCopy[index].popup = false;
    }

    function executeAction(id, actionId) {
        const searchId = String(id || "");
        const searchActionId = String(actionId || "");
        for (let index = 0; index < root.all.length; index++) {
            const wrapper = root.all[index];
            const wrapperId = String(wrapper?.id || wrapper?.notification?.id || "");
            if (wrapperId === searchId) {
                const actions = wrapper.actionsModel || [];
                for (let actionIndex = 0; actionIndex < actions.length; actionIndex++) {
                    if (String(actions[actionIndex].id) === searchActionId) {
                        root._logAction(wrapperId, searchActionId);
                        actions[actionIndex].trigger();
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
        for (let index = 0; index < root.all.length; index++) {
            const wrapper = root.all[index];
            const wrapperId = String(wrapper?.id || wrapper?.notification?.id || "");
            if (wrapperId === searchId)
                return wrapper.submitReply(text);
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

        let appName = "";
        let summary = "";
        for (let index = 0; index < root.all.length; index++) {
            const wrapper = root.all[index];
            const wrapperId = String(wrapper?.id || wrapper?.notification?.id || "");
            if (wrapperId === String(id)) {
                appName = String(wrapper.notification?.appName || "");
                summary = String(wrapper.notification?.summary || "");
                break;
            }
        }
        root.replySubmitted(String(id), String(text), appName, summary);
    }

    function _loadLogs() {
        try {
            const actionArray = JSON.parse(store.actionLogJson || "[]");
            root.actionLog = Array.isArray(actionArray) ? actionArray : [];
        } catch (e) {
            root.actionLog = [];
        }
        try {
            const replyArray = JSON.parse(store.replyLogJson || "[]");
            root.replyLog = Array.isArray(replyArray) ? replyArray : [];
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
        for (let index = 0; index < items.length; index++) {
            const item = items[index];
            historyModel.append({
                id: String(item.id || ""),
                summary: String(item.summary || ""),
                body: String(item.body || ""),
                bodyFormat: String(item.bodyFormat || "plain"),
                image: String(item.image || ""),
                appName: String(item.appName || ""),
                urgency: Number(item.urgency),
                groupId: String(item.groupId || ""),
                timestamp: item.timestamp ? new Date(Number(item.timestamp)) : new Date()
            });
        }
    }

    function _saveHistory() {
        const arr = [];
        for (let index = 0; index < historyModel.count; index++) {
            const item = historyModel.get(index);
            arr.push({
                id: item.id || "",
                summary: item.summary,
                body: item.body,
                bodyFormat: item.bodyFormat || "plain",
                image: item.image || "",
                appName: item.appName,
                urgency: item.urgency,
                groupId: item.groupId || "",
                timestamp: item.timestamp instanceof Date ? item.timestamp.getTime() : item.timestamp
            });
        }
        store.historyStoreJson = JSON.stringify(arr);
    }

    function _addToHistory(obj) {
        const notification = obj?.notification ? obj.notification : obj;
        const idVal = obj?.id || notification?.id || "";
        historyModel.insert(0, {
            id: String(idVal || ""),
            summary: String(notification?.summary || ""),
            body: String(notification?.body || ""),
            bodyFormat: String(notification?.bodyFormat || "plain"),
            image: String(notification?.image || ""),
            appName: String(notification?.appName || ""),
            urgency: Number(notification?.urgency ?? NotificationUrgency.Normal),
            groupId: String(obj?.groupId || notification?.groupId || ""),
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
            const parsedGroups = JSON.parse(store.groupsJson || "{}");
            root.groupsMap = parsedGroups && typeof parsedGroups === "object" ? parsedGroups : {};
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
