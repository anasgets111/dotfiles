// MonitorService.qml
pragma Singleton
import Quickshell
import QtQml
import QtQuick
import Quickshell.Io
import qs.Services
import qs.Services.SystemInfo
import qs.Services.WM.Impl.Hyprland as Hyprland
import qs.Services.WM.Impl.Niri as Niri

Singleton {
    id: monitorService
    property var logger: LoggerService

    property var mainService: MainService
    property ListModel monitorsModel: ListModel {}
    // Select backend implementation declaratively based on current WM
    property var impl: (monitorService.mainService && monitorService.mainService.currentWM === "hyprland") ? Hyprland.MonitorImpl : (monitorService.mainService && monitorService.mainService.currentWM === "niri") ? Niri.MonitorImpl : null
    readonly property bool ready: impl !== null

    signal monitorsChanged

    Connections {
        target: Quickshell
        function onScreensChanged() {
            const list = monitorService.normalizeScreens(Quickshell.screens);
            monitorService.updateMonitors(list);
            if (monitorService.impl)
                monitorService.logMonitorFeatures(list);
        }
    }

    // Initialize model with current screens at startup
    Component.onCompleted: {
        const list = normalizeScreens(Quickshell.screens);
        updateMonitors(list);
        if (impl)
            logMonitorFeatures(list);
    }

    // Helper: convert ListModel to plain JS array for logging/inspection
    function monitorsModelToArray() {
        var arr = [];
        for (var i = 0; i < monitorsModel.count; i++) {
            arr.push(monitorsModel.get(i));
        }
        return arr;
    }

    // Small helper to run a command and collect stdout
    function runCmd(cmd, onDone) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', monitorService);
        var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
        proc.stdout = collector;
        collector.onStreamFinished.connect(function () {
            onDone(collector.text);
        });
        proc.command = cmd;
        proc.running = true;
    }

    // When backend impl becomes available or changes, refresh feature info
    onImplChanged: {
        if (impl) {
            logMonitorFeatures(monitorsModelToArray());
        }
    }

    function normalizeScreens(screens) {
        // Convert to a plain array to ensure Array.map is available
        const list = Array.prototype.slice.call(screens);
        return list.map(function (s) {
            return {
                name: s.name,
                width: s.width,
                height: s.height,
                scale: s.devicePixelRatio || 1,
                fps: s.refreshRate || 60,
                bitDepth: s.colorDepth || 8,
                orientation: s.orientation,
                // Legacy string for UI that expects a simple mode indicator
                vrr: "off",
                // New fine-grained capability/state flags
                vrrSupported: false,
                hdrSupported: false,
                vrrActive: false,
                hdrActive: false
            };
        });
    }

    function updateMonitors(newList) {
        const existingCount = monitorsModel.count;
        const newCount = newList.length;
        let setChanged = false;

        const minCount = Math.min(existingCount, newCount);
        for (let i = 0; i < minCount; i++) {
            const oldItem = monitorsModel.get(i);
            const m = newList[i];
            if (!monitorService.sameMonitor(oldItem, m)) {
                // Merge to avoid clobbering capability/state flags updated asynchronously
                const merged = monitorService.mergeObjects(oldItem, m);
                monitorsModel.set(i, merged);
                setChanged = true;
            }
        }

        if (existingCount > newCount) {
            setChanged = true;
            for (let i = existingCount - 1; i >= newCount; i--) {
                monitorsModel.remove(i);
            }
        }

        if (newCount > existingCount) {
            setChanged = true;
            for (let i = existingCount; i < newCount; i++) {
                monitorsModel.append(newList[i]);
            }
        }

        if (setChanged) {
            monitorsChanged();
        }
    }

    // Compare two monitor entries for equality (only structural fields from Quickshell.screens)
    function sameMonitor(a, b) {
        if (!a || !b)
            return false;
        const keys = ["name", "width", "height", "scale", "fps", "bitDepth", "orientation"];
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            if (a[k] !== b[k])
                return false;
        }
        return true;
    }

    // Shallow merge helper (b overrides a)
    function mergeObjects(a, b) {
        var out = {};
        for (var k in a)
            out[k] = a[k];
        for (var k2 in b)
            out[k2] = b[k2];
        return out;
    }

    function findMonitorIndexByName(name) {
        for (var i = 0; i < monitorsModel.count; i++) {
            if (monitorsModel.get(i).name === name)
                return i;
        }
        return -1;
    }

    function parseEdidCapabilities(connectorName, callback) {
        const unsupported = {
            vrr: {
                supported: false
            },
            hdr: {
                supported: false
            }
        };

        // Step 1: List /sys/class/drm
        runCmd(["sh", "-c", "ls /sys/class/drm"], function (stdout) {
            const entries = stdout.split(/\r?\n/).filter(Boolean);

            // Step 2: Find matching entry
            const match = entries.find(line => line.endsWith(`-${connectorName}`));
            if (!match) {
                callback(unsupported);
                return;
            }

            // Step 3: Run edid-decode on the matched entry
            const edidPath = `/sys/class/drm/${match}/edid`;
            runCmd(["edid-decode", edidPath], function (text) {
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
            });
        });
    }

    function logMonitorFeatures(list) {
        if (!impl || !impl.getAvailableFeatures) {
            return;
        }

        for (let i = 0; i < list.length; i++) {
            const mon = list[i];
            parseEdidCapabilities(mon.name, function (caps) {
                const idx = monitorService.findMonitorIndexByName(mon.name);
                if (idx < 0)
                    return;
                // Update support flags immediately (only if changed)
                let dirty = false;
                const itemNow = monitorsModel.get(idx);
                const vrrSupported = !!(caps && caps.vrr && caps.vrr.supported);
                const hdrSupported = !!(caps && caps.hdr && caps.hdr.supported);
                if (itemNow.vrrSupported !== vrrSupported) {
                    monitorsModel.setProperty(idx, "vrrSupported", vrrSupported);
                    dirty = true;
                }
                if (itemNow.hdrSupported !== hdrSupported) {
                    monitorsModel.setProperty(idx, "hdrSupported", hdrSupported);
                    dirty = true;
                }
                if (dirty)
                    monitorsChanged();

                impl.getAvailableFeatures(mon.name, function (features) {
                    if (!features)
                        return;
                    // Active states from WM impl (only if changed)
                    const current = monitorsModel.get(idx);
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
        if (impl && impl.setMode)
            impl.setMode(name, width, height, refreshRate);
    }
    function setScale(name, scale) {
        if (impl && impl.setScale)
            impl.setScale(name, scale);
    }
    function setTransform(name, transform) {
        if (impl && impl.setTransform)
            impl.setTransform(name, transform);
    }
    function setPosition(name, x, y) {
        if (impl && impl.setPosition)
            impl.setPosition(name, x, y);
    }
    function setVrr(name, mode) {
        if (impl && impl.setVrr)
            impl.setVrr(name, mode);
    }
    function changeMonitorSettings(settings) {
        if (!impl) {
            return;
        }
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
        if (width && height && refreshRate && impl.setMode) {
            impl.setMode(name, width, height, refreshRate);
        }
        if (scale && impl.setScale) {
            impl.setScale(name, scale);
        }
        if (transform && impl.setTransform) {
            impl.setTransform(name, transform);
        }
        if (position && impl.setPosition) {
            impl.setPosition(name, position.x, position.y);
        }
        if (vrr && impl.setVrr) {
            impl.setVrr(name, vrr);
        }
    }
    function getAvailableFeatures(name, callback) {
        if (impl && impl.getAvailableFeatures) {
            impl.getAvailableFeatures(name, callback);
        } else {
            callback(null);
        }
    }

    // Log whenever the model changes or capabilities update
    onMonitorsChanged: {
        monitorService.logger.log("MonitorService", "current monitors:", JSON.stringify(monitorService.monitorsModelToArray()));
    }
}
