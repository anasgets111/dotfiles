import Quickshell
import Quickshell.Io
import qs.Services
pragma Singleton

Singleton {
    // --- tiny helpers

    id: niriMonitorService

    readonly property bool active: MainService.ready && MainService.currentWM === "niri"
    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""
    property var _replyQueue: []

    signal featuresChanged()

    function json(str) {
        try {
            return JSON.parse(str);
        } catch (e) {
            return null;
        }
    }

    function sendRaw(raw, callback) {
        if (!requestSocket.connected) {
            callback && callback(null);
            return ;
        }
        _replyQueue.push(callback || function() {
        });
        requestSocket.write(raw.endsWith("\n") ? raw : raw + "\n");
    }

    function send(obj, callback) {
        sendRaw(JSON.stringify(obj), callback);
    }

    function act(name, action, callback) {
        send({
            "Output": {
                "output": name,
                "action": action
            }
        }, callback);
    }

    function fetchFeatures(name, callback) {
        sendRaw('"Outputs"', (resp) => {
            const list = resp && Array.isArray(resp.Ok) ? resp.Ok : null;
            if (!list)
                return callback(null);

            const out = list.find((outputObj) => {
                return outputObj && outputObj.name === name;
            });
            if (!out)
                return callback(null);

            const modes = (out.modes || []).map((modeObj) => {
                return ({
                    "width": modeObj.width,
                    "height": modeObj.height,
                    "refreshRate": typeof modeObj.refresh_rate === "number" ? modeObj.refresh_rate / 1000 : null
                });
            });
            callback({
                "modes": modes,
                "vrr": {
                    "active": !!out.vrr_enabled
                },
                "hdr": {
                    "active": false
                }
            });
        });
    }

    function setMode(name, width, height, refreshRate) {
        act(name, {
            "Mode": {
                "mode": {
                    "Specific": {
                        "width": width,
                        "height": height,
                        "refresh": refreshRate
                    }
                }
            }
        }, () => {
            return featuresMayHaveChanged();
        });
    }

    function setScale(name, scale) {
        act(name, {
            "Scale": {
                "scale": {
                    "Specific": scale
                }
            }
        }, () => {
            return featuresMayHaveChanged();
        });
    }

    function setTransform(name, transform) {
        act(name, {
            "Transform": {
                "transform": transform
            }
        }, () => {
            return featuresMayHaveChanged();
        });
    }

    function setPosition(name, x, y) {
        act(name, {
            "Position": {
                "position": {
                    "Specific": {
                        "x": x,
                        "y": y
                    }
                }
            }
        }, () => {
            return featuresMayHaveChanged();
        });
    }

    function setVrr(name, mode) {
        const lower = String(mode || "").toLowerCase();
        const vrr = (lower === "on-demand" || lower === "ondemand") ? {
            "vrr": true,
            "on_demand": true
        } : (lower === "on" || lower === "enabled") ? {
            "vrr": true,
            "on_demand": false
        } : {
            "vrr": false,
            "on_demand": false
        };
        act(name, {
            "Vrr": {
                "vrr": vrr
            }
        }, () => {
            return featuresChanged();
        });
    }

    Socket {
        id: requestSocket

        path: niriMonitorService.socketPath
        connected: niriMonitorService.active && !!niriMonitorService.socketPath
        onConnectionStateChanged: {
            if (!connected) {
                while (niriMonitorService._replyQueue.length) {
                    const cb = niriMonitorService._replyQueue.shift();
                    cb && cb(null);
                }
            }
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function(message) {
                if (!message)
                    return ;

                const callback = niriMonitorService._replyQueue.shift();
                callback && callback(niriMonitorService.json(message));
            }
        }

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
            onRead: function(message) {
                const evt = message && niriMonitorService.json(message);
                if (evt && evt.ConfigLoaded)
                    niriMonitorService.featuresChanged();

            }
        }

    }

}
