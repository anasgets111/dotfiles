// MonitorService.qml
pragma Singleton
import Quickshell
import QtQml
import QtQuick
import Quickshell.Io
import "../" as Services

Singleton {
    id: monitorService

    property var mainService: Services.MainService
    property ListModel monitorsModel: ListModel {}
    property var impl: null
    property bool ready: false

    signal monitorsChanged

    Connections {
        target: Quickshell
        function onScreensChanged() {
            console.log("[MonitorService] Quickshell.screensChanged detected");
            const list = monitorService.normalizeScreens(Quickshell.screens);
            monitorService.updateMonitors(list);
            if (monitorService.impl)
                monitorService.logMonitorFeatures(list);
        }
    }

    Connections {
        target: monitorService.mainService
        function onReadyChanged() {
            if (monitorService.mainService.ready) {
                monitorService.setupImpl();
            }
        }
    }

    Component.onCompleted: {
        if (monitorService.mainService.ready) {
            setupImpl();
        }
    }

    function setupImpl() {
        console.log("[MonitorService] setupImpl() called");
        const list = normalizeScreens(Quickshell.screens);
        updateMonitors(list);

        if (monitorService.mainService.currentWM === "hyprland") {
            monitorService.impl = Services.HyprMonitorService;
        } else if (monitorService.mainService.currentWM === "niri") {
            monitorService.impl = Services.NiriMonitorService;
        }

        if (impl)
            logMonitorFeatures(list);

        monitorService.ready = true;
        console.log("[MonitorService] Ready with", monitorsModel.count, "monitors");
    }

    function normalizeScreens(screens) {
        const arr = [];
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            arr.push({
                name: s.name,
                width: s.width,
                height: s.height,
                scale: s.devicePixelRatio || 1,
                fps: s.refreshRate || 60,
                bitDepth: s.colorDepth || 8,
                orientation: s.orientation,
                vrr: "off"
            });
        }
        return arr;
    }

    function updateMonitors(newList) {
        console.log("[MonitorService] updateMonitors() called with", newList.length, "monitors");

        const existingCount = monitorsModel.count;
        const newCount = newList.length;
        let setChanged = false;

        const minCount = Math.min(existingCount, newCount);
        for (let i = 0; i < minCount; i++) {
            const oldItem = monitorsModel.get(i);
            const m = newList[i];
            if (oldItem.name !== m.name || oldItem.width !== m.width || oldItem.height !== m.height || oldItem.scale !== m.scale || oldItem.fps !== m.fps || oldItem.bitDepth !== m.bitDepth || oldItem.orientation !== m.orientation || oldItem.vrr !== m.vrr) {
                monitorsModel.set(i, m);
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
            console.log("[MonitorService] Monitor set changed → emitting monitorsChanged()");
            monitorsChanged();
        }
    }

    function parseEdidCapabilities(connectorName, callback) {
        console.log(`[MonitorService] [EDID] Looking for DRM entry for connector: ${connectorName}`);

        // Step 1: List /sys/class/drm
        var findProc = Qt.createQmlObject('import Quickshell.Io; Process { }', monitorService);
        var findCollector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', findProc);
        findProc.stdout = findCollector;

        findCollector.onStreamFinished.connect(function () {
            const entries = findCollector.text.split(/\r?\n/).filter(Boolean);
            console.log(`[MonitorService] [EDID] DRM entries found: ${entries.join(", ")}`);

            // Step 2: Find matching entry
            const match = entries.find(line => line.endsWith(`-${connectorName}`));
            if (!match) {
                console.warn(`[MonitorService] [EDID] No DRM entry found for connector ${connectorName}`);
                callback({
                    vrr: {
                        supported: false
                    },
                    hdr: {
                        supported: false
                    }
                });
                return;
            }

            console.log(`[MonitorService] [EDID] Matched DRM entry: ${match}`);

            // Step 3: Run edid-decode on the matched entry
            var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', monitorService);
            var collector = Qt.createQmlObject('import Quickshell.Io; StdioCollector { }', proc);
            proc.stdout = collector;

            collector.onStreamFinished.connect(function () {
                const text = collector.text;
                console.log(`[MonitorService] [EDID] edid-decode output length: ${text.length} chars`);

                const vrrSupported = /Adaptive-Sync|FreeSync|Vendor-Specific Data Block \(AMD\)/i.test(text);
                const hdrSupported = /HDR Static Metadata|SMPTE ST2084|HLG|BT2020/i.test(text);

                console.log(`[MonitorService] [EDID] VRR supported: ${vrrSupported}`);
                console.log(`[MonitorService] [EDID] HDR supported: ${hdrSupported}`);

                callback({
                    vrr: {
                        supported: vrrSupported
                    },
                    hdr: {
                        supported: hdrSupported
                    }
                });
            });

            const edidPath = `/sys/class/drm/${match}/edid`;
            console.log(`[MonitorService] [EDID] Running: edid-decode ${edidPath}`);
            proc.command = ["edid-decode", edidPath];
            proc.running = true;
        });

        findProc.command = ["sh", "-c", "ls /sys/class/drm"];
        findProc.running = true;
    }

    function logMonitorFeatures(list) {
        if (!impl || !impl.getAvailableFeatures) {
            console.log("[MonitorService] No backend available for feature detection");
            return;
        }

        for (let i = 0; i < list.length; i++) {
            const mon = list[i];
            parseEdidCapabilities(mon.name, function (caps) {
                impl.getAvailableFeatures(mon.name, function (features) {
                    if (!features) {
                        console.log(`[MonitorService] No feature info for ${mon.name}`);
                        return;
                    }
                    console.log(`[MonitorService] Features for ${mon.name}:`);
                    console.log(`  Modes: ${features.modes.map(m => `${m.width}x${m.height}@${m.refreshRate}`).join(", ")}`);
                    console.log(`  VRR supported: ${caps.vrr.supported}, active: ${features.vrr.active}`);
                    console.log(`  HDR supported: ${caps.hdr.supported}, active: ${features.hdr.active}`);
                    if (features.mirror !== undefined) {
                        console.log(`  Mirroring: ${features.mirror}`);
                    }
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
            console.warn("[MonitorService] No WM backend available for control");
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
            console.warn("[MonitorService] No backend available for getAvailableFeatures");
            callback(null);
        }
    }
}
