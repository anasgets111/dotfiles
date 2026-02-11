pragma Singleton
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils

Singleton {
  id: impl

  readonly property bool active: MainService.ready && MainService.currentWM === "niri"
  property string currentLayout: ""
  property int currentLayoutIndex: -1
  property var layouts: []
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET")

  function nextLayout(): void {
    Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
  }

  function handleLayoutEvent(event: var): void {
    const info = event?.KeyboardLayoutsChanged?.keyboard_layouts;
    if (info)
      impl.layouts = info.names || [];
    const idx = info?.current_idx ?? event?.KeyboardLayoutSwitched?.idx;
    if (idx === undefined)
      return;
    impl.currentLayoutIndex = idx >= 0 && idx < impl.layouts.length ? idx : -1;
    impl.currentLayout = impl.currentLayoutIndex >= 0 ? impl.layouts[impl.currentLayoutIndex] : "";
  }

  Socket {
    id: eventStreamSocket

    connected: impl.active && impl.socketPath
    path: impl.socketPath

    parser: SplitParser {
      splitMarker: "\n"

      onRead: segment => {
        if (!segment)
          return;
        try {
          impl.handleLayoutEvent(JSON.parse(segment));
        } catch (e) {
          Logger.log("KeyboardLayoutImpl(Niri)", `Parse error: ${e}`);
        }
      }
    }

    onConnectionStateChanged: if (connected)
      write('"EventStream"\n')
  }
}
