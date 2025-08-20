// NiriMonitorService.qml
pragma Singleton
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.SystemInfo

Singleton {
    id: niriMonitorService
    readonly property bool active: MainService.ready && MainService.currentWM === "niri"
    readonly property bool enabled: niriMonitorService.active
    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""

    // Simple request socket with FIFO reply handlers
    property var _replyQueue: []
    // Emitted when output-related features may have changed (e.g., after a set*, or config reload)
    signal featuresMayHaveChanged

    Socket {
        id: requestSocket
        path: niriMonitorService.socketPath
        connected: niriMonitorService.enabled && !!niriMonitorService.socketPath

        onConnectionStateChanged: {
            if (!connected) {
                // Flush pending callbacks on disconnect
                while (niriMonitorService._replyQueue.length > 0) {
                    const cb = niriMonitorService._replyQueue.shift();
                    if (cb)
                        cb(null);
                }
            }
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function (segment) {
                if (!segment)
                    return;
                let resp = null;
                try {
                    resp = JSON.parse(segment);
                } catch (e) {
                    resp = null;
                }
                const cb = niriMonitorService._replyQueue.shift();
                if (cb)
                    cb(resp);
            }
        }
    }

    function _sendRaw(raw, cb) {
        if (!requestSocket.connected) {
            cb(null);
            return;
        }
        niriMonitorService._replyQueue.push(cb || function () {});
        requestSocket.write(raw.endsWith("\n") ? raw : raw + "\n");
    }

    function _send(obj, cb) {
        _sendRaw(JSON.stringify(obj), cb);
    }

    function getAvailableFeatures(name, callback) {
        // Query outputs and map to the legacy shape
        _sendRaw('"Outputs"', function (resp) {
            if (!resp || !resp.Ok || !Array.isArray(resp.Ok)) {
                callback(null);
                return;
            }
            const outputs = resp.Ok;
            const out = outputs.find(o => o && o.name === name);
            if (!out) {
                callback(null);
                return;
            }
            const modes = (out.modes || []).map(m => ({
                        width: m.width,
                        height: m.height,
                        // convert mHz to Hz float
                        refreshRate: typeof m.refresh_rate === "number" ? (m.refresh_rate / 1000.0) : null
                    }));
            callback({
                modes: modes,
                vrr: {
                    active: !!out.vrr_enabled
                },
                hdr: {
                    active: false
                }
            });
        });
    }

    function setMode(name, width, height, refreshRate) {
        const req = {
            Output: {
                output: name,
                action: {
                    Mode: {
                        mode: {
                            Specific: {
                                width: width,
                                height: height,
                                refresh: refreshRate
                            }
                        }
                    }
                }
            }
        };
        _send(req, function (resp) {
            niriMonitorService.featuresMayHaveChanged();
        });
    }
    function setScale(name, scale) {
        const req = {
            Output: {
                output: name,
                action: {
                    Scale: {
                        scale: {
                            Specific: scale
                        }
                    }
                }
            }
        };
        _send(req, function (resp) {
            niriMonitorService.featuresMayHaveChanged();
        });
    }
    function setTransform(name, transform) {
        const req = {
            Output: {
                output: name,
                action: {
                    Transform: {
                        transform: transform
                    }
                }
            }
        };
        _send(req, function (resp) {
            niriMonitorService.featuresMayHaveChanged();
        });
    }
    function setPosition(name, x, y) {
        const req = {
            Output: {
                output: name,
                action: {
                    Position: {
                        position: {
                            Specific: {
                                x: x,
                                y: y
                            }
                        }
                    }
                }
            }
        };
        _send(req, function (resp) {
            niriMonitorService.featuresMayHaveChanged();
        });
    }
    function setVrr(name, mode) {
        const lower = String(mode || "").toLowerCase();
        let vrr = {
            vrr: false,
            on_demand: false
        };
        if (lower === "off") {
            vrr = {
                vrr: false,
                on_demand: false
            };
        } else if (lower === "on-demand" || lower === "ondemand") {
            vrr = {
                vrr: true,
                on_demand: true
            };
        } else if (lower === "on" || lower === "enabled") {
            vrr = {
                vrr: true,
                on_demand: false
            };
        }
        const req = {
            Output: {
                output: name,
                action: {
                    Vrr: {
                        vrr: vrr
                    }
                }
            }
        };
        _send(req, function (resp) {
            niriMonitorService.featuresMayHaveChanged();
        });
    }

    // Event stream: listen for config reloads and refresh features
    Socket {
        id: eventStreamSocket
        path: niriMonitorService.socketPath
        connected: niriMonitorService.enabled && !!niriMonitorService.socketPath

        onConnectionStateChanged: {
            if (connected) {
                write('"EventStream"\n');
            }
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function (segment) {
                if (!segment)
                    return;
                const event = JSON.parse(segment);
                if (event && event.ConfigLoaded) {
                    niriMonitorService.featuresMayHaveChanged();
                }
            }
        }
    }
}
