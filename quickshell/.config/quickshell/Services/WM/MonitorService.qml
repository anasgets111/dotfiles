// MonitorService.qml
pragma Singleton
import Quickshell
import QtQml
import QtQuick
import qs.Services
import qs.Services.Utils
import qs.Services.WM.Impl.Hyprland as Hyprland
import qs.Services.WM.Impl.Niri as Niri

Singleton {
    id: monitorService
    // Preferred main monitor from MainService, may be empty
    property string preferredMain: MainService.mainMon || ""

    // Computed main monitor with fallback to first available monitor
    readonly property string activeMain: {
        if (preferredMain.length > 0)
            return preferredMain;
        return monitors.count > 0 ? monitors.get(0).name : "";
    }
    property ListModel monitors: ListModel {}
    // Select backend implementation declaratively based on current WM
    property var backend: (MainService.currentWM === "hyprland") ? Hyprland.MonitorImpl : (MainService.currentWM === "niri") ? Niri.MonitorImpl : null
    readonly property bool ready: backend !== null

    readonly property var monitorKeyFields: ["name", "width", "height", "scale", "fps", "bitDepth", "orientation"]

    signal monitorsUpdated

    Timer {
        id: changeDebounce
        interval: 0
        repeat: false
        onTriggered: monitorService.monitorsUpdated()
    }
    function emitChangedDebounced() {
        changeDebounce.restart();
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            const normalizedScreens = monitorService.normalizeScreens(Quickshell.screens);
            monitorService.updateMonitors(normalizedScreens);
            if (monitorService.backend)
                monitorService.refreshFeatures(normalizedScreens);
        }
    }

    Component.onCompleted: {
        const normalizedScreens = normalizeScreens(Quickshell.screens);
        updateMonitors(normalizedScreens);
        if (backend)
            refreshFeatures(normalizedScreens);
    }

    function toArray() {
        const result = [];
        for (let idx = 0; idx < monitors.count; idx++) {
            result.push(monitors.get(idx));
        }
        return result;
    }

    onBackendChanged: {
        if (backend) {
            refreshFeatures(toArray());
        }
    }

    Connections {
        target: (monitorService.backend && MainService.currentWM === "niri") ? monitorService.backend : null
        function onFeaturesChanged() {
            monitorService.refreshFeatures(monitorService.toArray());
        }
    }

    function normalizeScreens(screens) {
        return Array.prototype.slice.call(screens).map(screen => ({
                    name: screen.name,
                    width: screen.width,
                    height: screen.height,
                    scale: screen.devicePixelRatio || 1,
                    fps: screen.refreshRate || 60,
                    bitDepth: screen.colorDepth || 8,
                    orientation: screen.orientation,
                    vrr: "off" // legacy
                    ,
                    vrrSupported: false,
                    hdrSupported: false,
                    vrrActive: false,
                    hdrActive: false
                }));
    }

    function updateMonitors(newScreens) {
        const oldCount = monitors.count;
        const newCount = newScreens.length;
        let modelChanged = false;

        const minCount = Math.min(oldCount, newCount);
        for (let idx = 0; idx < minCount; idx++) {
            const existingMonitor = monitors.get(idx);
            const incomingMonitor = newScreens[idx];
            if (!monitorService.isSameMonitor(existingMonitor, incomingMonitor)) {
                const merged = Utils.mergeObjects(existingMonitor, incomingMonitor);
                monitors.set(idx, merged);
                modelChanged = true;
            }
        }

        if (oldCount > newCount) {
            modelChanged = true;
            for (let remIdx = oldCount - 1; remIdx >= newCount; remIdx--) {
                monitors.remove(remIdx);
            }
        }

        if (newCount > oldCount) {
            modelChanged = true;
            for (let addIdx = oldCount; addIdx < newCount; addIdx++) {
                monitors.append(newScreens[addIdx]);
            }
        }

        if (modelChanged) {
            emitChangedDebounced();
        }
    }

    function isSameMonitor(monA, monB) {
        if (!monA || !monB)
            return false;
        return monitorKeyFields.every(key => monA[key] === monB[key]);
    }

    function findMonitorIndexByName(name) {
        for (let idx = 0; idx < monitors.count; idx++) {
            if (monitors.get(idx).name === name)
                return idx;
        }
        return -1;
    }

    function readEdidCaps(connectorName, callback) {
        const defaultCaps = {
            vrr: {
                supported: false
            },
            hdr: {
                supported: false
            }
        };
        Utils.runCmd(["sh", "-c", "ls /sys/class/drm"], stdout => {
            const entries = stdout.split(/\r?\n/).filter(Boolean);
            const matchedEntry = entries.find(line => line.endsWith(`-${connectorName}`));
            if (!matchedEntry) {
                callback(defaultCaps);
                return;
            }

            const edidPath = `/sys/class/drm/${matchedEntry}/edid`;
            Utils.runCmd(["edid-decode", edidPath], text => {
                const vrrSupported = /Adaptive-Sync|FreeSync|Vendor-Specific Data Block \(AMD\)/i.test(text);
                const hdrSupported = /HDR Static Metadata|SMPTE ST2084|HLG|BT2020/i.test(text);
                callback({
                    vrr: {
                        supported: vrrSupported
                    },
                    hdr: {
                        supported: hdrSupported
                    }
                });
            }, monitorService);
        }, monitorService);
    }

    function refreshFeatures(monitorsList) {
        if (!backend || !backend.fetchFeatures && !backend.getAvailableFeatures)
            return;
        const fetchFn = backend.fetchFeatures || backend.getAvailableFeatures;

        for (const monitorObj of monitorsList) {
            readEdidCaps(monitorObj.name, caps => {
                const idx = monitorService.findMonitorIndexByName(monitorObj.name);
                if (idx < 0)
                    return;
                let metaDirty = false;
                const current = monitors.get(idx);
                const vrrSupported = !!(caps?.vrr?.supported);
                const hdrSupported = !!(caps?.hdr?.supported);
                if (current.vrrSupported !== vrrSupported) {
                    monitors.setProperty(idx, "vrrSupported", vrrSupported);
                    metaDirty = true;
                }
                if (current.hdrSupported !== hdrSupported) {
                    monitors.setProperty(idx, "hdrSupported", hdrSupported);
                    metaDirty = true;
                }
                if (metaDirty)
                    emitChangedDebounced();

                fetchFn(monitorObj.name, features => {
                    if (!features)
                        return;
                    let activeDirty = false;
                    const vrrActive = !!(features.vrr && (features.vrr.active || features.vrr.enabled));
                    const hdrActive = !!(features.hdr && (features.hdr.active || features.hdr.enabled));
                    if (current.vrrActive !== vrrActive) {
                        monitors.setProperty(idx, "vrrActive", vrrActive);
                        activeDirty = true;
                    }
                    if (current.hdrActive !== hdrActive) {
                        monitors.setProperty(idx, "hdrActive", hdrActive);
                        activeDirty = true;
                    }
                    const legacyVrr = vrrActive ? "on" : "off";
                    if (current.vrr !== legacyVrr) {
                        monitors.setProperty(idx, "vrr", legacyVrr);
                        activeDirty = true;
                    }
                    if (activeDirty)
                        emitChangedDebounced();
                });
            });
        }
    }

    function setMode(name, width, height, refreshRate) {
        backend?.setMode(name, width, height, refreshRate);
    }
    function setScale(name, scale) {
        backend?.setScale(name, scale);
    }
    function setTransform(name, transform) {
        backend?.setTransform(name, transform);
    }
    function setPosition(name, x, y) {
        backend?.setPosition(name, x, y);
    }
    function setVrr(name, mode) {
        backend?.setVrr(name, mode);
    }
    function applySettings(settings) {
        if (!backend)
            return;
        const {
            name,
            width,
            height,
            refreshRate,
            scale,
            transform,
            position,
            vrr
        } = settings;
        if (width !== undefined && height !== undefined && refreshRate !== undefined)
            backend.setMode(name, width, height, refreshRate);
        if (scale !== undefined)
            backend.setScale(name, scale);
        if (transform !== undefined)
            backend.setTransform(name, transform);
        if (position && position.x !== undefined && position.y !== undefined)
            backend.setPosition(name, position.x, position.y);
        if (vrr !== undefined)
            backend.setVrr(name, vrr);
    }
    function getAvailableFeatures(name, callback) {
        const fn = backend?.fetchFeatures || backend?.getAvailableFeatures;
        fn ? fn(name, callback) : callback(null);
    }

    onMonitorsUpdated: {
        Logger.log("MonitorService", "current monitors:", JSON.stringify(toArray()));
    }
}
