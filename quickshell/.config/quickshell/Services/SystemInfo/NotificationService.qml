pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Services.SystemInfo

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

    // ----- Configuration -----
    property var logger: LoggerService
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
        property var historyStore: []
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
            // Track + wrap every notification
            notification.tracked = true;

            const wrapper = notifComp.createObject(root, {
                popup: !root.doNotDisturb,
                notification: notification
            });
            if (!wrapper)
                return;
            root.all = root.all.concat([wrapper]);
            root._addToHistory(notification);

            if (!root.doNotDisturb) {
                root.queue = root.queue.concat([wrapper]);
                root._processQueue();
            }
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

        // Bound to the underlying notification
        required property Notification notification
        readonly property string summary: notification.summary
        readonly property string body: notification.body
        readonly property string appIcon: notification.appIcon
        readonly property string appName: notification.appName
        readonly property string image: notification.image
        readonly property int urgency: notification.urgency
        // Access actions via w.notification.actions when needed

        // Auto-hide timer, urgency-aware, honors expireTimeout (> 0)
        readonly property Timer timer: Timer {
            interval: {
                // If server specified a positive expireTimeout, honor it
                const t = w.notification.expireTimeout;
                if (typeof t === "number" && t > 0)
                    return t;
                // Otherwise fallback to configured defaults by urgency
                switch (w.notification.urgency) {
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
        readonly property Connections conn: Connections {
            target: w.notification.Retainable
            function onDropped(): void {
                const idx = root.all.indexOf(w);
                if (idx !== -1) {
                    const newAll = root.all.slice();
                    newAll.splice(idx, 1);
                    root.all = newAll;
                }
                root._release(w);
            }
            function onAboutToDestroy(): void {
                w.destroy();
            }
        }

        onPopupChanged: if (!popup)
            root._onHidden(w)
    }

    Component {
        id: notifComp
        NotifWrapper {}
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
        try {
            historyModel.clear();
            const items = store.historyStore || [];
            for (let i = 0; i < items.length; i++) {
                const it = items[i];
                historyModel.append({
                    summary: it.summary || "",
                    body: it.body || "",
                    appName: it.appName || "",
                    urgency: it.urgency,
                    timestamp: it.timestamp ? new Date(it.timestamp) : new Date()
                });
            }
        } catch (e) {
            root.logger.warn("NotificationService", "Failed to load history:", e);
        }
    }

    function _saveHistory() {
        try {
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
            store.historyStore = arr;
        } catch (e) {
            root.logger.warn("NotificationService", "Failed to save history:", e);
        }
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
        // Hide all currently visible popups
        const vis = root.visible.slice();
        for (let i = 0; i < vis.length; i++)
            vis[i].popup = false;
        root.queue = [];
    }

    function dismissNotification(wrapper) {
        if (!wrapper || !wrapper.notification)
            return;
        wrapper.popup = false;
        try {
            wrapper.notification.dismiss();
        } catch (e) {}
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

    // ----- IPC -----
    IpcHandler {
        target: "notifs"

        function clear(): string {
            root.clearPopups();
            return "cleared";
        }

        function dnd(state: string): string {
            // Accept: "on"/"off"/boolean
            if (typeof state === "string")
                root.setDoNotDisturb(state.toLowerCase() === "on" || state.toLowerCase() === "true");
            else
                root.setDoNotDisturb(!!state);
            return "DND=" + root.doNotDisturb;
        }

        function clearhistory(): string {
            root.clearHistory();
            return "History cleared";
        }

        function status(): string {
            return `Notifications: total=${root.all.length}, visible=${root.visible.length}, queued=${root.queue.length}, DND=${root.doNotDisturb}`;
        }
    }
}
