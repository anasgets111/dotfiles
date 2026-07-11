import QtQuick
import Quickshell
import Quickshell.Io

// Line-oriented socket on the Niri IPC path that subscribes to the event
// stream when `eventStream` is set and reconnects 500ms after any error or
// unexpected disconnect. Instances handle onLineRead / onConnectedChanged.
Scope {
  id: root

  readonly property alias connected: sock.connected
  property bool eventStream: false
  property string path: ""
  property bool _enabled: path !== ""

  signal lineRead(string message)

  function flush(): void {
    sock.flush();
  }

  function write(data: string): void {
    sock.write(data);
  }

  function _reconnect(): void {
    if (path === "")
      return;
    _enabled = false;
    reconnectTimer.restart();
  }

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
