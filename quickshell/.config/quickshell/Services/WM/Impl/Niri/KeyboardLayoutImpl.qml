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

  function handleLayoutEvent(event: var): void {
    const info = event?.KeyboardLayoutsChanged?.keyboard_layouts;
    const layoutNames = Array.isArray(info?.names) ? info.names.map(name => String(name ?? "").trim()).filter(Boolean) : null;
    if (layoutNames)
      impl.layouts = layoutNames;
    const rawIdx = info?.current_idx ?? event?.KeyboardLayoutSwitched?.idx;
    if (!Number.isInteger(rawIdx))
      return;
    impl.currentLayoutIndex = rawIdx >= 0 && rawIdx < impl.layouts.length ? rawIdx : -1;
    if (impl.currentLayoutIndex >= 0) {
      const layout = String(impl.layouts[impl.currentLayoutIndex] ?? "").trim();
      if (layout)
        impl.currentLayout = layout;
    }
  }

  function nextLayout(): void {
    Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
  }

  Socket {
    id: eventStreamSocket

    connected: impl.active && impl.socketPath
    path: impl.socketPath

    parser: SplitParser {
      splitMarker: "\n"

      onRead: segment => {
        const clean = String(segment ?? "").trim();
        if (!clean)
          return;
        try {
          impl.handleLayoutEvent(JSON.parse(clean));
        } catch (e) {
          Logger.warn("KeyboardLayoutImpl(Niri)", `Parse error: ${e}`);
        }
      }
    }

    onConnectionStateChanged: if (connected)
      write('"EventStream"\n')
  }
}
