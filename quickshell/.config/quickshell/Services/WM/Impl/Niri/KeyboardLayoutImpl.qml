pragma Singleton
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Services.Utils

Singleton {
  id: impl

  readonly property bool active: MainService.ready && MainService.currentWM === "niri"
  property string currentLayout: ""
  property var layouts: []
  readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""

  function parseKeyboardLayouts(event) {
    const info = event && event.KeyboardLayoutsChanged && event.KeyboardLayoutsChanged.keyboard_layouts;
    if (info) {
      impl.layouts = Array.isArray(info.names) ? info.names : [];
      const idx = typeof info.current_idx === "number" ? info.current_idx : -1;
      impl.setLayoutByIndex(idx);
      return true;
    }
    const switchedIdx = event && event.KeyboardLayoutSwitched && event.KeyboardLayoutSwitched.idx;
    if (typeof switchedIdx === "number") {
      impl.setLayoutByIndex(switchedIdx);
      return true;
    }
    return false;
  }
  function setLayoutByIndex(layoutIndex) {
    if (!Array.isArray(impl.layouts)) {
      impl.currentLayout = "";
      return;
    }
    const idx = Number.isInteger(layoutIndex) ? layoutIndex : -1;
    impl.currentLayout = idx >= 0 && idx < impl.layouts.length ? (impl.layouts[idx] || "") : "";
  }

  Socket {
    id: eventStreamSocket

    connected: impl.active && !!impl.socketPath
    path: impl.socketPath

    parser: SplitParser {
      splitMarker: "\n"

      onRead: function (segment) {
        if (!segment)
          return;

        const event = Utils.safeJsonParse(segment, null);
        if (!event)
          return;

        impl.parseKeyboardLayouts(event);
      }
    }

    onConnectionStateChanged: {
      if (connected)
        write('"EventStream"\n');
    }
  }
}
