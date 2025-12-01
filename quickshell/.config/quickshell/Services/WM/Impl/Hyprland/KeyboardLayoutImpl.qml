pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Services
import qs.Services.Utils

Singleton {
  id: impl

  readonly property bool active: MainService.ready && MainService.currentWM === "hyprland"
  property string currentLayout: ""
  property var layouts: []
  property string mainKeyboardName: ""

  function buildLayoutsFromDevices(jsonText) {
    const clean = jsonText.replace(/\x1B\[[0-9;]*[A-Za-z]/g, "").trim();
    const keyboards = JSON.parse(clean)?.keyboards?.filter(kb => kb.main) || [];

    const unique = [];
    let active = "";
    let mainKeyboard = "";

    keyboards.forEach(kb => {
      if (kb.name && !mainKeyboard)
        mainKeyboard = kb.name;

      kb.layout?.split(",").map(s => s.trim()).filter(Boolean).forEach(name => {
        if (!unique.includes(name))
          unique.push(name);
      });

      if (kb.active_keymap)
        active = kb.active_keymap;
    });

    return {
      unique,
      active,
      mainKeyboard
    };
  }

  function cycleLayout() {
    Quickshell.execDetached(["hyprctl", "switchxkblayout", impl.mainKeyboardName || "at-translated-set-2-keyboard", "next"]);
  }

  Process {
    id: layoutSeedProcess

    command: ["hyprctl", "-j", "devices"]
    running: impl.active

    stdout: StdioCollector {
      onStreamFinished: {
        if (!impl.active)
          return;

        try {
          const {
            unique,
            active,
            mainKeyboard
          } = impl.buildLayoutsFromDevices(text);
          impl.layouts = unique;
          impl.currentLayout = active;
          impl.mainKeyboardName = mainKeyboard;
        } catch (e) {
          Logger.log("KeyboardLayoutImpl(Hypr)", `Parse error: ${e}`);
        }
      }
    }
  }

  Connections {
    function onRawEvent(event) {
      if (event?.name !== "activelayout" || !event.data)
        return;

      // Event format: "KEYBOARDNAME,LAYOUTNAME" - only update current layout
      const commaIdx = event.data.indexOf(",");
      if (commaIdx > 0)
        impl.currentLayout = event.data.slice(commaIdx + 1).trim();
    }

    target: impl.active ? Hyprland : null
  }
}
