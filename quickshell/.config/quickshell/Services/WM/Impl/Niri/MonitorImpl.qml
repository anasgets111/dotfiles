pragma Singleton
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
  id: root

  property var _replyQueue: []
  readonly property bool enabled: MainService.ready && MainService.currentWM === "niri"
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""

  signal featuresChanged

  function fetchFeatures(outputName: string, callback: var): void {
    sendRaw('"Outputs"', response => {
      const outputs = response?.Ok && Array.isArray(response.Ok) ? response.Ok : null;
      if (!outputs)
        return callback(null);

      const output = outputs.find(candidate => candidate?.name === outputName);
      if (!output)
        return callback(null);

      const modes = (output.modes || []).map(mode => ({
            width: mode.width,
            height: mode.height,
            refreshRate: typeof mode.refresh_rate === "number" ? mode.refresh_rate / 1000 : null
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

  function parseJson(text: string): var {
    try {
      return JSON.parse(text);
    } catch (error) {
      return null;
    }
  }

  function send(request: var, callback: var): void {
    sendRaw(JSON.stringify(request), callback);
  }

  function sendOutputAction(outputName: string, action: var, callback: var): void {
    send({
      Output: {
        output: outputName,
        action
      }
    }, callback);
  }

  function sendRaw(message: string, callback: var): void {
    if (!requestSocket.connected) {
      if (callback)
        callback(null);
      return;
    }
    _replyQueue.push(callback || (() => {}));
    requestSocket.write(message.endsWith("\n") ? message : `${message}\n`);
  }

  function setMode(outputName: string, width: int, height: int, refreshRate: real): void {
    sendOutputAction(outputName, {
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

  function setPosition(outputName: string, positionX: int, positionY: int): void {
    sendOutputAction(outputName, {
      Position: {
        position: {
          Specific: {
            x: positionX,
            y: positionY
          }
        }
      }
    }, () => featuresChanged());
  }

  function setScale(outputName: string, scale: real): void {
    sendOutputAction(outputName, {
      Scale: {
        scale: {
          Specific: scale
        }
      }
    }, () => featuresChanged());
  }

  function setTransform(outputName: string, transform: string): void {
    sendOutputAction(outputName, {
      Transform: {
        transform
      }
    }, () => featuresChanged());
  }

  function setVrr(outputName: string, mode: string): void {
    const normalizedMode = String(mode || "").toLowerCase();
    const vrr = normalizedMode === "on-demand" || normalizedMode === "ondemand" ? {
      vrr: true,
      on_demand: true
    } : normalizedMode === "on" || normalizedMode === "enabled" ? {
      vrr: true,
      on_demand: false
    } : {
      vrr: false,
      on_demand: false
    };

    sendOutputAction(outputName, {
      Vrr: {
        vrr
      }
    }, () => featuresChanged());
  }

  Socket {
    id: requestSocket

    connected: root.enabled && !!root.socketPath
    path: root.socketPath

    parser: SplitParser {
      splitMarker: "\n"

      onRead: message => {
        if (!message)
          return;
        const callback = root._replyQueue.shift();
        if (callback)
          callback(root.parseJson(message));
      }
    }

    onConnectionStateChanged: {
      if (!connected) {
        while (root._replyQueue.length) {
          const callback = root._replyQueue.shift();
          if (callback)
            callback(null);
        }
      }
    }
  }

  Socket {
    id: eventStreamSocket

    connected: root.enabled && !!root.socketPath
    path: root.socketPath

    parser: SplitParser {
      splitMarker: "\n"

      onRead: message => {
        const event = message && root.parseJson(message);
        if (event?.ConfigLoaded)
          root.featuresChanged();
      }
    }

    onConnectionStateChanged: {
      if (connected)
        write('"EventStream"\n');
    }
  }
}
