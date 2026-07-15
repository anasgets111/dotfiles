pragma Singleton
import QtQml
import Quickshell
import Quickshell.Hyprland
import qs.Services.Utils

Singleton {
  id: impl

  property string currentLayout: ""
  property int currentLayoutIndex: -1
  property string keyboardDeviceName: ""
  property var layouts: []

  function nextLayout(): void {
    Command.detached(["hyprctl", "switchxkblayout", keyboardDeviceName || "at-translated-set-2-keyboard", "next"]);
  }
  function requestLayoutSync(): void {
    Command.run(["hyprctl", "-j", "devices"], result => {
      try {
        impl.syncLayoutState(result.stdout);
      } catch (error) {
        Logger.warn("KeyboardLayoutImpl(Hypr)", `Parse error: ${error}`);
      }
    }, "hypr.layoutSync");
  }
  function setLayoutByIndex(layoutIndex: int): void {
    if (layoutIndex < 0 || layoutIndex >= layouts.length)
      return;
    Command.detached(["hyprctl", "switchxkblayout", keyboardDeviceName || "at-translated-set-2-keyboard", `${layoutIndex}`]);
  }
  function syncLayoutState(jsonText: string): void {
    if (!jsonText)
      return;
    const keyboards = JSON.parse(String(jsonText)).keyboards || [];
    const isUsableDevice = device => !/(virtual-keyboard|consumer-control|system-control|power-button)/i.test(String(device?.name ?? ""));
    const keyboard = keyboards.find(device => device?.name === keyboardDeviceName && isUsableDevice(device)) || keyboards.find(device => device?.main && isUsableDevice(device)) || keyboards.find(isUsableDevice) || {};
    const layoutNames = keyboard.layout?.split(",").map(name => name.trim()).filter(Boolean) || [];
    const activeIndex = Number.isInteger(keyboard.active_layout_index) ? keyboard.active_layout_index : Number.isInteger(keyboard.active_keymap_index) ? keyboard.active_keymap_index : -1;
    const rawKeymap = String(keyboard.active_keymap ?? "").trim();
    layouts = layoutNames;
    currentLayoutIndex = activeIndex >= 0 && activeIndex < layoutNames.length ? activeIndex : -1;
    if (rawKeymap.toLowerCase() !== "error")
      currentLayout = rawKeymap || (currentLayoutIndex >= 0 ? layoutNames[currentLayoutIndex] || currentLayout : currentLayout);
    if (keyboard.name)
      keyboardDeviceName = keyboard.name;
  }

  Component.onCompleted: requestLayoutSync()

  Connections {
    function onRawEvent(event: var): void {
      if (event?.name !== "activelayout")
        return;
      impl.keyboardDeviceName = String(event?.data ?? "").split(",")[0].trim() || impl.keyboardDeviceName;
      impl.requestLayoutSync();
    }

    target: Hyprland
  }
}
