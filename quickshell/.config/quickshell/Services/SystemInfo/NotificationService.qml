pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Minimal, robust notification service usable across the project.
// Features:
// - NotificationServer with common capabilities
// - Popup queue with max visible and per-notification auto-dismiss
// - Urgency-aware/default timeouts and honor expireTimeout when provided
// - Do Not Disturb (DND) toggle to suppress popups (still logs history)
// - Simple persistent history saved to cache file
// - IPC for basic controls (clear, dnd, clearhistory, status)
Singleton {
    id: root

    // Emitted when a user clicks an action on any notification handled by this server.
    // Consumers can listen and react (e.g., UpdateService running an updater).
    signal actionInvoked(string summary, string appName, string actionId, string body)

    // ----- Local notification support -----
    // Create an internal notification (no external DBus) and show it using the same pipeline
    // as remote notifications. Supports: summary, body (rich text links), appName, appIcon,
    // image (inline), urgency, expireTimeout, actions (flat pairs or objects with icon).
    // Returns a simple string id.
    property int _localIdSeq: 1
    component LocalNotification: QtObject {
        id: ln
        // Core fields
        property string summary: ""
        property string body: ""
        property string appIcon: ""
        property string appName: ""
        property string image: ""
        property int urgency: NotificationUrgency.Normal
        property int expireTimeout: -1
        // Actions: can be flat pair array or array of objects
        property var actions: []
        // Back-reference to wrapper to enable dismiss()
        property QtObject wrapperRef
        // Marker to identify locally-created notifications
        readonly property bool __local: true
        function invokeAction(actionId) {
            const id = String(actionId || "");
            try {
                root.actionInvoked(String(ln.summary || ""), String(ln.appName || ""), id, String(ln.body || ""));
            } catch (e) {}
        }
        function activateAction(actionId) {
            invokeAction(actionId);
        }
        function dismiss() {
            if (ln.wrapperRef) {
                try {
                    ln.wrapperRef.popup = false;
                } catch (e) {}
            }
        }
    }

    // Present a notification (remote or local) through wrappers/queues/history
    function _presentNotification(notification) {
        if (!notification)
            return null;
        const wrapper = notifComp.createObject(root, {
            popup: !root.doNotDisturb,
            notification: notification
        });
        if (!wrapper)
            return null;
        if (notification && notification.__local === true)
            notification.wrapperRef = wrapper;
        root.all = root.all.concat([wrapper]);
        root._addToHistory(notification);
        if (!root.doNotDisturb) {
            root.queue = root.queue.concat([wrapper]);
            root._processQueue();
        }
        return wrapper;
    }

    // Public API: create and show a local notification
    function send(summary, body, options) {
        const o = options || {};
        const n = localNotifComp.createObject(root, {
            summary: String(summary || ""),
            body: String(body || ""),
            appName: String(o.appName || "notify-send"),
            appIcon: String(o.appIcon || ""),
            image: String(o.image || ""),
            urgency: (function () {
                    const u = (o.urgency !== undefined) ? o.urgency : NotificationUrgency.Normal;
                    if (typeof u === 'string') {
                        const s = u.toLowerCase();
                        if (s === 'low')
                            return NotificationUrgency.Low;
                        if (s === 'critical')
                            return NotificationUrgency.Critical;
                        return NotificationUrgency.Normal;
                    }
                    return Number(u);
                })(),
            expireTimeout: (typeof o.expireTimeout === 'number') ? o.expireTimeout : -1,
            actions: (function () {
                    const a = o.actions;
                    if (!a)
                        return [];
                    // Accept flat pairs or array of objects; pass through
                    return a;
                })()
        });
        if (!n)
            return "";
        const w = _presentNotification(n);
        const id = "local-" + (root._localIdSeq++);
        return id;
    }

    // ----- Configuration -----
    // Maximum concurrent popups
    property int maxVisible: 3
    // Auto-dismiss behavior
    property bool expirePopups: true
    // Default timeouts (ms) by urgency when expireTimeout <= 0
    property int timeoutLow: 5000
    property int timeoutNormal: 8000
    // Critical defaults to sticky (0 = don't auto-dismiss)
    property int timeoutCritical: 0
    // Suppress showing popups (still logs to history)
    property bool doNotDisturb: false

    // ----- Live state -----
    // Use JS arrays for dynamic collections
    property var all: []
    // Convenience view (note: only updates when 'all' identity changes)
    readonly property var popups: all.filter(n => n.popup)
    property var visible: []
    property var queue: []

    // Gate to sequence popup enter animations
    property bool _addGateBusy: false
    readonly property int _enterAnimMs: 300

    Timer {
        id: addGate
        interval: root._enterAnimMs + 40
        running: false
        repeat: false
        onTriggered: {
            root._addGateBusy = false;
            root._processQueue();
        }
    }

    // Simple heartbeat to refresh relative time strings
    property bool _timePulse: false
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root._timePulse = !root._timePulse
    }

    // ----- History (persistent) -----
    readonly property ListModel historyModel: ListModel {}
    property int maxHistory: 100
    // Persistent store across reloads
    PersistentProperties {
        id: store
        reloadableId: "NotificationService"
        // Store as JSON string to avoid cross-engine JSValue reassignment
        property string historyStoreJson: "[]"
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
            root._presentNotification(notification);
        }
    }

    // ----- Wrapper component -----
    component NotifWrapper: QtObject {
        id: w

        // Whether a popup is currently visible for this notification
        property bool popup: false
        // Creation time
        readonly property date time: new Date()
        // Human-friendly relative time string
        readonly property string timeStr: {
            root._timePulse; // dependency
            const now = Date.now();
            const diff = now - time.getTime();
            const m = Math.floor(diff / 60000);
            const h = Math.floor(m / 60);
            if (h < 1 && m < 1)
                return "now";
            if (h < 1)
                return `${m}m`;
            return `${h}h`;
        }

        // Bound to the underlying notification (remote or local)
        required property var notification
        readonly property string summary: (notification && notification.summary) ? String(notification.summary) : ""
        readonly property string body: (notification && notification.body) ? String(notification.body) : ""
        readonly property string appIcon: (notification && notification.appIcon) ? String(notification.appIcon) : ""
        readonly property string appName: (notification && notification.appName) ? String(notification.appName) : ""
        readonly property string image: (notification && notification.image) ? String(notification.image) : ""
        readonly property int urgency: (notification && notification.urgency !== undefined) ? Number(notification.urgency) : NotificationUrgency.Normal
        readonly property int expireTimeout: (notification && typeof notification.expireTimeout === 'number') ? notification.expireTimeout : -1
        // Access actions via w.notification.actions when needed

        // ----- Backend normalization for UI consumption -----
        // Resolve an icon source for the app using desktop entries when possible,
        // then fall back to the notification-provided icon name/path, and finally a generic icon.
        readonly property string iconSource: {
            let src = "";
            try {
                if (typeof DesktopEntries !== "undefined" && w.appName) {
                    const entry = DesktopEntries.heuristicLookup(String(w.appName));
                    if (entry && entry.icon)
                        src = Quickshell.iconPath(entry.icon, true);
                }
            } catch (e)
            // ignore
            {}
            if (!src && w.appIcon) {
                const s = String(w.appIcon);
                if (s.startsWith("file:") || s.startsWith("/") || s.startsWith("data:"))
                    src = s;
                else
                    src = Quickshell.iconPath(s, true);
            }
            if (!src)
                src = Quickshell.iconPath("dialog-information", true);
            return src;
        }

        // Inline/body image source if provided by the server
        readonly property string imageSource: (w.image || "")

        function _mkActionEntry(n, id, title, iconName) {
            const iconSource = iconName ? Quickshell.iconPath(String(iconName), true) : "";
            return {
                id: id,
                title: title,
                iconName: iconName || "",
                iconSource: iconSource,
                trigger: function () {
                    if (!n)
                        return;
                    try {
                        Logger.log("NotificationService", "action trigger:", String(id), "for", String(n.summary || ""));
                    } catch (e) {}
                    if (n && n.__local === true) {
                        // For local notifications, emit our signal and dismiss; don't reinvoke, to avoid double emit.
                        try {
                            root.actionInvoked(String(n.summary || ""), String(n.appName || ""), String(id), String(n.body || ""));
                        } catch (e) {}
                        if (typeof n.dismiss === 'function')
                            n.dismiss();
                        else
                            w.popup = false;
                    } else {
                        // Remote/DBus notifications: invoke backend action
                        if (typeof n.invokeAction === 'function')
                            n.invokeAction(String(id));
                        else if (typeof n.activateAction === 'function')
                            n.activateAction(String(id));
                        // Try to dismiss if supported
                        if (typeof n.dismiss === 'function')
                            n.dismiss();
                        else
                            w.popup = false;
                    }
                }
            };
        }

        // Normalized actions list suitable for direct binding in UI
        readonly property var actionsModel: {
            const n = w.notification;
            const a = (n && n.actions) ? n.actions : [];
            if (!a || a.length === 0)
                return [];
            // Flat pair array: [id, title, id, title, ...]
            if (typeof a[0] === 'string') {
                const out = [];
                for (var i = 0; i + 1 < a.length; i += 2) {
                    const _id = String(a[i]);
                    const _title = String(a[i + 1]);
                    out.push(_mkActionEntry(n, _id, _title, ""));
                }
                return out;
            }
            // Object array; attempt to read common fields and optional icon
            return a.map(function (x) {
                const _id = String((x && (x.id || x.action || x.key || x.name)) || "");
                const _title = String((x && (x.title || x.label || x.text)) || _id);
                const _iconName = x ? (x.icon || x.iconName || x.icon_id || "") : "";
                return _mkActionEntry(n, _id, _title, _iconName);
            });
        }

        // Auto-hide timer, urgency-aware, honors expireTimeout (> 0)
        readonly property Timer timer: Timer {
            interval: {
                // If server specified a positive expireTimeout, honor it
                const t = w.expireTimeout;
                if (typeof t === "number" && t > 0)
                    return t;
                // Otherwise fallback to configured defaults by urgency
                switch (w.urgency) {
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
                    w.popup = false;
            }
        }

        // Cleanup when the underlying notification is dropped/destroyed
        // Use RetainableLock to receive rebroadcasted signals instead of
        // targeting the attached Retainable object directly, which can cause
        // cross-engine JSValue warnings during reloads.
        readonly property RetainableLock retainLock: RetainableLock {
            // Local notifications are plain QtObjects; skip locking for them
            object: (w.notification && w.notification.__local === true) ? null : w.notification
            onDropped: {
                const idx = root.all.indexOf(w);
                if (idx !== -1) {
                    const newAll = root.all.slice();
                    newAll.splice(idx, 1);
                    root.all = newAll;
                }
                root._release(w);
            }
            onAboutToDestroy: w.destroy()
        }

        onPopupChanged: if (!popup)
            root._onHidden(w)
    }

    Component {
        id: notifComp
        NotifWrapper {}
    }
    Component {
        id: localNotifComp
        LocalNotification {}
    }

    // ----- Queue management -----
    function _processQueue() {
        if (root._addGateBusy)
            return;
        if (root.doNotDisturb)
            return;
        if (root.queue.length === 0)
            return;

        // Respect maxVisible concurrent popups
        if (root.visible.length >= root.maxVisible)
            return;
        const q = root.queue.slice();
        const next = q.shift();
        root.queue = q;
        if (!next)
            return;
        root.visible = [...root.visible, next];
        next.popup = true;
        if (next.timer.interval > 0)
            next.timer.start();

        root._addGateBusy = true;
        addGate.restart();
    }

    function _onHidden(w) {
        // Remove from visible and continue queue
        const i = root.visible.indexOf(w);
        if (i !== -1) {
            const v = root.visible.slice();
            v.splice(i, 1);
            root.visible = v;
        }
        // For local notifications, also remove from 'all' when no longer visible
        if (w && w.notification && w.notification.__local === true) {
            const ai = root.all.indexOf(w);
            if (ai !== -1) {
                const a = root.all.slice();
                a.splice(ai, 1);
                root.all = a;
            }
        }
        root._processQueue();
    }

    function _release(w) {
        // Remove from visible and queue
        let v = root.visible.slice();
        const vi = v.indexOf(w);
        if (vi !== -1) {
            v.splice(vi, 1);
            root.visible = v;
        }
        let q = root.queue.slice();
        const qi = q.indexOf(w);
        if (qi !== -1) {
            q.splice(qi, 1);
            root.queue = q;
        }
    }

    // ----- History helpers -----
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
                summary: String(it.summary || ""),
                body: String(it.body || ""),
                appName: String(it.appName || ""),
                urgency: Number(it.urgency),
                timestamp: it.timestamp ? new Date(Number(it.timestamp)) : new Date()
            });
        }
        root._historyHydrated = true;
    }

    function _saveHistory() {
        const arr = [];
        for (let i = 0; i < historyModel.count; i++) {
            const n = historyModel.get(i);
            arr.push({
                summary: n.summary,
                body: n.body,
                appName: n.appName,
                urgency: n.urgency,
                timestamp: (n.timestamp instanceof Date) ? n.timestamp.getTime() : n.timestamp
            });
        }
        store.historyStoreJson = JSON.stringify(arr);
    }

    function _addToHistory(notification) {
        historyModel.insert(0, {
            summary: notification.summary,
            body: notification.body,
            appName: notification.appName,
            urgency: notification.urgency,
            timestamp: new Date()
        });
        while (historyModel.count > maxHistory)
            historyModel.remove(historyModel.count - 1);
        _saveHistory();
    }

    // Public history APIs
    function clearHistory() {
        historyModel.clear();
        _saveHistory();
    }

    // ----- Public convenience APIs -----
    function clearPopups() {
        // Hide all currently visible popups (legacy behavior)
        const vis = root.visible.slice();
        for (let i = 0; i < vis.length; i++)
            vis[i].popup = false;
        root.queue = [];
    }

    function clearAll() {
        // Dismiss and remove all active notifications
        const items = root.all.slice();
        for (let i = 0; i < items.length; i++) {
            const w = items[i];
            if (!w)
                continue;
            try {
                if (w.notification && typeof w.notification.dismiss === 'function')
                    w.notification.dismiss();
            } catch (e) {}
            // For locals, remove immediately; remote ones will drop via RetainableLock
            if (w.notification && w.notification.__local === true) {
                const ai = root.all.indexOf(w);
                if (ai !== -1) {
                    const a = root.all.slice();
                    a.splice(ai, 1);
                    root.all = a;
                }
            }
        }
        root.queue = [];
        // Also hide any remaining popups
        const vis = root.visible.slice();
        for (let i = 0; i < vis.length; i++)
            vis[i].popup = false;
    }

    function dismissNotification(wrapper) {
        if (!wrapper || !wrapper.notification)
            return;
        wrapper.popup = false;
        wrapper.notification.dismiss();
    }

    function setDoNotDisturb(enabled) {
        if (root.doNotDisturb === !!enabled)
            return;
        root.doNotDisturb = !!enabled;
        if (root.doNotDisturb) {
            // Immediately hide popups and stop queue
            clearPopups();
        } else {
            _processQueue();
        }
    }
}
