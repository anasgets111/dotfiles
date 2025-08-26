// NiriMonitorService.qml
pragma Singleton
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: niriMonitorService
    readonly property bool active: MainService.ready && MainService.currentWM === "niri"
    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""

    property var _replyQueue: []

    signal featuresMayHaveChanged

    Socket {
        id: requestSocket
        path: niriMonitorService.socketPath
        connected: niriMonitorService.active && !!niriMonitorService.socketPath

        onConnectionStateChanged: {
            if (!connected) {
                while (niriMonitorService._replyQueue.length > 0) {
                    const callback = niriMonitorService._replyQueue.shift();
                    callback(null);
                }
            }
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function (segment) {
                if (!segment)
                    return;
                let response = null;
                response = JSON.parse(segment);
                const callback = niriMonitorService._replyQueue.shift();
                callback(response);
            }
        }
    }

    function _sendRaw(raw, callback) {
        if (!requestSocket.connected) {
            callback(null);
            return;
        }
        _replyQueue.push(callback || function () {});
        requestSocket.write(raw.endsWith("\n") ? raw : raw + "\n");
    }

    function _send(obj, callback) {
        _sendRaw(JSON.stringify(obj), callback);
    }

    function getAvailableFeatures(name, callback) {
        _sendRaw('"Outputs"', response => {
            if (!response?.Ok || !Array.isArray(response.Ok)) {
                callback(null);
                return;
            }
            const output = response.Ok.find(o => o?.name === name);
            if (!output) {
                callback(null);
                return;
            }
            const modes = (output.modes || []).map(m => ({
                        width: m.width,
                        height: m.height,
                        refreshRate: typeof m.refresh_rate === "number" ? m.refresh_rate / 1000.0 : null
                    }));
            callback({
                modes,
                vrr: {
                    active: !!output.vrr_enabled
                },
                hdr: {
                    active: false
                }
            });
        });
    }

    function setMode(name, width, height, refreshRate) {
        _send({
            Output: {
                output: name,
                action: {
                    Mode: {
                        mode: {
                            Specific: {
                                width,
                                height,
                                refresh: refreshRate
                            }
                        }
                    }
                }
            }
        }, () => featuresMayHaveChanged());
    }

    function setScale(name, scale) {
        _send({
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
        }, () => featuresMayHaveChanged());
    }

    function setTransform(name, transform) {
        _send({
            Output: {
                output: name,
                action: {
                    Transform: {
                        transform
                    }
                }
            }
        }, () => featuresMayHaveChanged());
    }

    function setPosition(name, x, y) {
        _send({
            Output: {
                output: name,
                action: {
                    Position: {
                        position: {
                            Specific: {
                                x,
                                y
                            }
                        }
                    }
                }
            }
        }, () => featuresMayHaveChanged());
    }

    function setVrr(name, mode) {
        const lower = String(mode || "").toLowerCase();
        let vrr = {
            vrr: false,
            on_demand: false
        };
        if (lower === "on-demand" || lower === "ondemand")
            vrr = {
                vrr: true,
                on_demand: true
            };
        else if (lower === "on" || lower === "enabled")
            vrr = {
                vrr: true,
                on_demand: false
            };

        _send({
            Output: {
                output: name,
                action: {
                    Vrr: {
                        vrr
                    }
                }
            }
        }, () => featuresMayHaveChanged());
    }

    Socket {
        id: eventStreamSocket
        path: niriMonitorService.socketPath
        connected: niriMonitorService.active && !!niriMonitorService.socketPath

        onConnectionStateChanged: {
            if (connected)
                write('"EventStream"\n');
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function (segment) {
                if (!segment)
                    return;
                const event = JSON.parse(segment);
                if (event?.ConfigLoaded)
                    niriMonitorService.featuresMayHaveChanged();
            }
        }
    }
}
