pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  property var _replyQueue: []
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""

  signal featuresChanged

  function fetchFeatures(outputName: string, callback: var): void {
    sendRaw('"Outputs"', response => {
      const outputs = response?.Ok?.Outputs;
      if (!outputs || typeof outputs !== "object")
        return callback(null);

      const output = outputs[outputName] ?? Object.values(outputs).find(candidate => candidate?.name === outputName);
      if (!output)
        return callback(null);

      const modes = (output.modes || []).map(mode => ({
            width: mode.width,
            height: mode.height,
            refreshRate: typeof mode.refresh_rate === "number" ? mode.refresh_rate / 1000 : null
          }));
      const currentMode = Number.isInteger(output.current_mode) ? modes[output.current_mode] : null;

      callback({
        bitDepth: typeof output.max_bpc === "number" ? output.max_bpc : null,
        fps: currentMode?.refreshRate ?? null,
        modes,
        vrr: {
          supported: !!output.vrr_supported,
          active: !!output.vrr_enabled
        },
        hdr: {
          supported: false,
          active: false
        },
        mirror: false
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

  function sendRaw(message: string, callback: var): void {
    if (!requestSocket.connected) {
      if (callback)
        callback(null);
      return;
    }
    _replyQueue.push(callback || (() => {}));
    requestSocket.write(message.endsWith("\n") ? message : `${message}\n`);
    requestSocket.flush();
  }

  NiriSocket {
    id: requestSocket

    path: root.socketPath

    onConnectedChanged: {
      if (connected) {
        root.featuresChanged();
        return;
      }
      while (root._replyQueue.length) {
        const callback = root._replyQueue.shift();
        if (callback)
          callback(null);
      }
    }
    onLineRead: message => {
      if (!message)
        return;
      const callback = root._replyQueue.shift();
      if (callback)
        callback(root.parseJson(message));
    }
  }

  NiriSocket {
    eventStream: true
    path: root.socketPath

    onLineRead: message => {
      const event = message && root.parseJson(message);
      if (event?.ConfigLoaded)
        root.featuresChanged();
    }
  }
}
