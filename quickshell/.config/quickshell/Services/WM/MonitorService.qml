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
    property string configuredMainMonitor: MainService.mainMon || ""

    // Computed main monitor with fallback to first available monitor
    readonly property string mainMonitor: {
        if (configuredMainMonitor.length > 0)
            return configuredMainMonitor;
        return monitorsModel.count > 0 ? monitorsModel.get(0).name : "";
    }
    property ListModel monitorsModel: ListModel {}
    // Select backend implementation declaratively based on current WM
    property var impl: (MainService.currentWM === "hyprland") ? Hyprland.MonitorImpl : (MainService.currentWM === "niri") ? Niri.MonitorImpl : null
    readonly property bool ready: impl !== null

    signal monitorsChanged

    Connections {
        target: Quickshell
        function onScreensChanged() {
            const normalizedScreens = monitorService.normalizeScreens(Quickshell.screens);
            monitorService.updateMonitors(normalizedScreens);
            if (monitorService.impl)
                monitorService.logMonitorFeatures(normalizedScreens);
        }
    }

    Component.onCompleted: {
        const normalizedScreens = normalizeScreens(Quickshell.screens);
        updateMonitors(normalizedScreens);
        if (impl)
            logMonitorFeatures(normalizedScreens);
    }

    function monitorsModelToArray() {
        const result = [];
        for (let i = 0; i < monitorsModel.count; i++) {
            result.push(monitorsModel.get(i));
        }
        return result;
    }

    onImplChanged: {
        if (impl) {
            logMonitorFeatures(monitorsModelToArray());
        }
    }

    Connections {
        target: (monitorService.impl && MainService.currentWM === "niri") ? monitorService.impl : null
        function onFeaturesMayHaveChanged() {
            monitorService.logMonitorFeatures(monitorService.monitorsModelToArray());
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
        const oldCount = monitorsModel.count;
        const newCount = newScreens.length;
        let modelChanged = false;

        const minCount = Math.min(oldCount, newCount);
        for (let i = 0; i < minCount; i++) {
            const oldMonitor = monitorsModel.get(i);
            const newMonitor = newScreens[i];
            if (!monitorService.sameMonitor(oldMonitor, newMonitor)) {
                const merged = Utils.mergeObjects(oldMonitor, newMonitor);
                monitorsModel.set(i, merged);
                modelChanged = true;
            }
        }

        if (oldCount > newCount) {
            modelChanged = true;
            for (let i = oldCount - 1; i >= newCount; i--) {
                monitorsModel.remove(i);
            }
        }

        if (newCount > oldCount) {
            modelChanged = true;
            for (let i = oldCount; i < newCount; i++) {
                monitorsModel.append(newScreens[i]);
            }
        }

        if (modelChanged) {
            monitorsChanged();
        }
    }

    function sameMonitor(monitorA, monitorB) {
        if (!monitorA || !monitorB)
            return false;
        const keys = ["name", "width", "height", "scale", "fps", "bitDepth", "orientation"];
        return keys.every(key => monitorA[key] === monitorB[key]);
    }

    function findMonitorIndexByName(name) {
        for (let i = 0; i < monitorsModel.count; i++) {
            if (monitorsModel.get(i).name === name)
                return i;
        }
        return -1;
    }

    function parseEdidCapabilities(connectorName, callback) {
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
            const match = entries.find(line => line.endsWith(`-${connectorName}`));
            if (!match) {
                callback(defaultCaps);
                return;
            }

            const edidPath = `/sys/class/drm/${match}/edid`;
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

    function logMonitorFeatures(monitors) {
        if (!impl || !impl.getAvailableFeatures)
            return;

        for (const monitor of monitors) {
            parseEdidCapabilities(monitor.name, caps => {
                const idx = monitorService.findMonitorIndexByName(monitor.name);
                if (idx < 0)
                    return;
                let dirty = false;
                const current = monitorsModel.get(idx);
                const vrrSupported = !!(caps?.vrr?.supported);
                const hdrSupported = !!(caps?.hdr?.supported);
                if (current.vrrSupported !== vrrSupported) {
                    monitorsModel.setProperty(idx, "vrrSupported", vrrSupported);
                    dirty = true;
                }
                if (current.hdrSupported !== hdrSupported) {
                    monitorsModel.setProperty(idx, "hdrSupported", hdrSupported);
                    dirty = true;
                }
                if (dirty)
                    monitorsChanged();

                impl.getAvailableFeatures(monitor.name, features => {
                    if (!features)
                        return;
                    let dirtyActive = false;
                    const vrrActive = !!(features.vrr && (features.vrr.active || features.vrr.enabled));
                    const hdrActive = !!(features.hdr && (features.hdr.active || features.hdr.enabled));
                    if (current.vrrActive !== vrrActive) {
                        monitorsModel.setProperty(idx, "vrrActive", vrrActive);
                        dirtyActive = true;
                    }
                    if (current.hdrActive !== hdrActive) {
                        monitorsModel.setProperty(idx, "hdrActive", hdrActive);
                        dirtyActive = true;
                    }
                    const legacyVrr = vrrActive ? "on" : "off";
                    if (current.vrr !== legacyVrr) {
                        monitorsModel.setProperty(idx, "vrr", legacyVrr);
                        dirtyActive = true;
                    }
                    if (dirtyActive)
                        monitorsChanged();
                });
            });
        }
    }

    function setMode(name, width, height, refreshRate) {
        impl?.setMode(name, width, height, refreshRate);
    }
    function setScale(name, scale) {
        impl?.setScale(name, scale);
    }
    function setTransform(name, transform) {
        impl?.setTransform(name, transform);
    }
    function setPosition(name, x, y) {
        impl?.setPosition(name, x, y);
    }
    function setVrr(name, mode) {
        impl?.setVrr(name, mode);
    }
    function changeMonitorSettings(settings) {
        if (!impl)
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
        if (width && height && refreshRate)
            impl.setMode(name, width, height, refreshRate);
        if (scale)
            impl.setScale(name, scale);
        if (transform)
            impl.setTransform(name, transform);
        if (position)
            impl.setPosition(name, position.x, position.y);
        if (vrr)
            impl.setVrr(name, vrr);
    }
    function getAvailableFeatures(name, callback) {
        impl?.getAvailableFeatures(name, callback) ?? callback(null);
    }

    onMonitorsChanged: {
        Logger.log("MonitorService", "current monitors:", JSON.stringify(monitorsModelToArray()));
    }
}
