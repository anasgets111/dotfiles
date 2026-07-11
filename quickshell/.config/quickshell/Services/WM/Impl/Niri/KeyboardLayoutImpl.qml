pragma Singleton
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: impl

  property string currentLayout: ""
  property int currentLayoutIndex: -1
  property bool enabled: false
  property var layouts: []
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""

  function handleLayoutEvent(event: var): void {
    const layoutInfo = event?.KeyboardLayoutsChanged?.keyboard_layouts;
    const layoutNames = Array.isArray(layoutInfo?.names) ? layoutInfo.names.map(name => String(name ?? "").trim()).filter(Boolean) : null;
    if (layoutNames)
      layouts = layoutNames;
    const rawIndex = layoutInfo?.current_idx ?? event?.KeyboardLayoutSwitched?.idx;
    if (!Number.isInteger(rawIndex))
      return;
    currentLayoutIndex = rawIndex >= 0 && rawIndex < layouts.length ? rawIndex : -1;
    if (currentLayoutIndex >= 0) {
      const layout = String(layouts[currentLayoutIndex] ?? "").trim();
      if (layout)
        currentLayout = layout;
    }
  }

  function nextLayout(): void {
    Command.detached(["niri", "msg", "action", "switch-layout", "next"]);
  }

  Socket {
    id: eventStreamSocket

    connected: impl.enabled && impl.socketPath
    path: impl.socketPath

    parser: SplitParser {
      splitMarker: "\n"

      onRead: line => {
        const message = String(line ?? "").trim();
        if (!message)
          return;
        try {
          impl.handleLayoutEvent(JSON.parse(message));
        } catch (error) {
          Logger.warn("KeyboardLayoutImpl(Niri)", `Parse error: ${error}`);
        }
      }
    }

    onConnectionStateChanged: if (connected)
      write('"EventStream"\n')
  }
}
