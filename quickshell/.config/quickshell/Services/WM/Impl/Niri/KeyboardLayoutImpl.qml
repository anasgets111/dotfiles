pragma Singleton
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
  id: impl

  readonly property bool active: MainService.ready && MainService.currentWM === "niri"
  property string currentLayout: ""
  property var layouts: []
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET")

  function cycleLayout() {
    Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
  }

  function parseKeyboardLayouts(event) {
    const info = event?.KeyboardLayoutsChanged?.keyboard_layouts;
    if (info) {
      impl.layouts = info.names || [];
      impl.setLayoutByIndex(info.current_idx ?? -1);
      return;
    }

    const switchedIdx = event?.KeyboardLayoutSwitched?.idx;
    if (switchedIdx !== undefined)
      impl.setLayoutByIndex(switchedIdx);
  }

  function setLayoutByIndex(idx) {
    impl.currentLayout = idx >= 0 && idx < impl.layouts.length ? impl.layouts[idx] : "";
  }

  Socket {
    id: eventStreamSocket

    connected: impl.active && impl.socketPath
    path: impl.socketPath

    parser: SplitParser {
      splitMarker: "\n"

      onRead: segment => {
        if (segment) {
          try {
            impl.parseKeyboardLayouts(JSON.parse(segment));
          } catch (_) {}
        }
      }
    }

    onConnectionStateChanged: {
      if (connected)
        write('"EventStream"\n');
    }
  }
}
