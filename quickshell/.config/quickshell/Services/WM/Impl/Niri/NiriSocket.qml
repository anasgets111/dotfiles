import QtQuick
import Quickshell
import Quickshell.Io

// Line-oriented socket on the Niri IPC path that subscribes to the event
// stream when `eventStream` is set and reconnects after any error or
// unexpected disconnect, with exponential backoff (capped) so a socket that
// never comes back doesn't spin forever. Instances handle onLineRead / onConnectedChanged.
Scope {
  id: root

  readonly property int _baseReconnectDelay: 500
  property bool _enabled: path !== ""
  readonly property int _maxReconnectDelay: 10000
  property int _reconnectAttempts: 0
  readonly property alias connected: sock.connected
  property bool eventStream: false
  property string path: ""

  signal lineRead(string message)

  function _reconnect(): void {
    if (path === "")
      return;
    _enabled = false;
    reconnectTimer.interval = Math.min(_baseReconnectDelay * Math.pow(2, _reconnectAttempts), _maxReconnectDelay);
    _reconnectAttempts++;
    reconnectTimer.restart();
  }
  function flush(): void {
    sock.flush();
  }
  function write(data: string): void {
    sock.write(data);
  }

  onPathChanged: _reconnectAttempts = 0

  Socket {
    id: sock

    connected: root._enabled
    path: root.path

    parser: SplitParser {
      splitMarker: "\n"

      onRead: message => root.lineRead(message)
    }

    onConnectionStateChanged: {
      if (connected) {
        root._reconnectAttempts = 0;
        if (root.eventStream) {
          write('"EventStream"\n');
          flush();
        }
      } else if (root._enabled) {
        root._reconnect();
      }
    }
    onError: root._reconnect()
  }
  Timer {
    id: reconnectTimer

    interval: 500

    onTriggered: root._enabled = root.path !== ""
  }
}
