pragma Singleton
import QtQml
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Services
import qs.Services.Utils

Singleton {
  id: impl

  readonly property bool active: MainService.ready && MainService.currentWM === "hyprland"
  property string currentLayout: ""
  property int currentLayoutIndex: -1
  property string keyboardDeviceName: ""
  property var layouts: []

  function nextLayout(): void {
    Quickshell.execDetached(["hyprctl", "switchxkblayout", impl.keyboardDeviceName || "at-translated-set-2-keyboard", "next"]);
  }

  function requestLayoutSync(): void {
    if (impl.active && !layoutSyncProcess.running)
      layoutSyncProcess.running = true;
  }

  function setLayoutByIndex(index: int): void {
    if (index < 0 || index >= impl.layouts.length)
      return;
    Quickshell.execDetached(["hyprctl", "switchxkblayout", impl.keyboardDeviceName || "at-translated-set-2-keyboard", `${index}`]);
  }

  function syncLayoutState(jsonText: string): void {
    const clean = String(jsonText ?? "").replace(/\x1B\[[0-9;]*[A-Za-z]/g, "").trim();
    if (!clean || !clean.startsWith("{"))
      return;
    const keyboard = (JSON.parse(clean).keyboards || []).find(kb => kb.main) || {};
    const layoutNames = keyboard.layout?.split(",").map(name => name.trim()).filter(Boolean) || [];
    const activeIndex = Number.isInteger(keyboard.active_layout_index) ? keyboard.active_layout_index : Number.isInteger(keyboard.active_keymap_index) ? keyboard.active_keymap_index : -1;

    impl.layouts = layoutNames;
    impl.currentLayoutIndex = activeIndex >= 0 && activeIndex < layoutNames.length ? activeIndex : -1;
    impl.currentLayout = keyboard.active_keymap || (impl.currentLayoutIndex >= 0 ? layoutNames[impl.currentLayoutIndex] : "");
    impl.keyboardDeviceName = keyboard.name || "";
  }

  Component.onCompleted: requestLayoutSync()
  onActiveChanged: if (active)
    requestLayoutSync()

  Process {
    id: layoutSyncProcess

    command: ["hyprctl", "-j", "devices"]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        if (!impl.active)
          return;

        try {
          impl.syncLayoutState(text);
        } catch (e) {
          Logger.warn("KeyboardLayoutImpl(Hypr)", `Parse error: ${e}`);
        }
      }
    }
  }

  Connections {
    function onRawEvent(event: var): void {
      if (event?.name === "activelayout")
        impl.requestLayoutSync();
    }

    target: impl.active ? Hyprland : null
  }
}
