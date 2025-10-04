pragma Singleton
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
  id: root

  property var _replyQueue: []
  readonly property bool active: MainService.ready && MainService.currentWM === "niri"
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""

  signal featuresChanged

  function act(name, action, callback) {
    send({
      Output: {
        output: name,
        action
      }
    }, callback);
  }

  function fetchFeatures(name, callback) {
    sendRaw('"Outputs"', resp => {
      const list = resp?.Ok && Array.isArray(resp.Ok) ? resp.Ok : null;
      if (!list)
        return callback(null);

      const out = list.find(obj => obj?.name === name);
      if (!out)
        return callback(null);

      const modes = (out.modes || []).map(modeObj => ({
            width: modeObj.width,
            height: modeObj.height,
            refreshRate: typeof modeObj.refresh_rate === "number" ? modeObj.refresh_rate / 1000 : null
          }));

      callback({
        modes,
        vrr: {
          active: !!out.vrr_enabled
        },
        hdr: {
          active: false
        }
      });
    });
  }

  function json(str) {
    try {
      return JSON.parse(str);
    } catch (e) {
      return null;
    }
  }

  function send(obj, callback) {
    sendRaw(JSON.stringify(obj), callback);
  }

  function sendRaw(raw, callback) {
    if (!requestSocket.connected) {
      if (callback)
        callback(null);
      return;
    }
    _replyQueue.push(callback || (() => {}));
    requestSocket.write(raw.endsWith("\n") ? raw : `${raw}\n`);
  }

  function setMode(name, width, height, refreshRate) {
    act(name, {
      Mode: {
        mode: {
          Specific: {
            width,
            height,
            refresh: refreshRate
          }
        }
      }
    }, () => featuresChanged());
  }

  function setPosition(name, x, y) {
    act(name, {
      Position: {
        position: {
          Specific: {
            x,
            y
          }
        }
      }
    }, () => featuresChanged());
  }

  function setScale(name, scale) {
    act(name, {
      Scale: {
        scale: {
          Specific: scale
        }
      }
    }, () => featuresChanged());
  }

  function setTransform(name, transform) {
    act(name, {
      Transform: {
        transform
      }
    }, () => featuresChanged());
  }

  function setVrr(name, mode) {
    const lower = String(mode || "").toLowerCase();
    const vrr = lower === "on-demand" || lower === "ondemand" ? {
      vrr: true,
      on_demand: true
    } : lower === "on" || lower === "enabled" ? {
      vrr: true,
      on_demand: false
    } : {
      vrr: false,
      on_demand: false
    };

    act(name, {
      Vrr: {
        vrr
      }
    }, () => featuresChanged());
  }

  Socket {
    id: requestSocket
    connected: root.active && !!root.socketPath
    path: root.socketPath

    parser: SplitParser {
      splitMarker: "\n"
      onRead: message => {
        if (!message)
          return;
        const callback = root._replyQueue.shift();
        if (callback)
          callback(root.json(message));
      }
    }

    onConnectionStateChanged: {
      if (!connected) {
        while (root._replyQueue.length) {
          const cb = root._replyQueue.shift();
          if (cb)
            cb(null);
        }
      }
    }
  }

  Socket {
    id: eventStreamSocket
    connected: root.active && !!root.socketPath
    path: root.socketPath

    parser: SplitParser {
      splitMarker: "\n"
      onRead: message => {
        const evt = message && root.json(message);
        if (evt?.ConfigLoaded)
          root.featuresChanged();
      }
    }

    onConnectionStateChanged: {
      if (connected)
        write('"EventStream"\n');
    }
  }
}
