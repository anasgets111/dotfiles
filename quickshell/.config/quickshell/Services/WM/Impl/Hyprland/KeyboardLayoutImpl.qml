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
    const clean = Utils.stripAnsi(jsonText || "").trim();
    const data = Utils.safeJsonParse(clean, {});
    const keyboards = (data && data.keyboards) || [];
    const unique = [];
    let active = "";
    let mainKbName = "";
    for (let i = 0; i < keyboards.length; i++) {
      const kb = keyboards[i];
      if (!kb || !kb.main)
        continue;

      // Store the main keyboard name for layout switching
      if (kb.name && !mainKbName)
        mainKbName = kb.name;

      const layoutStr = kb.layout || "";
      if (layoutStr) {
        const parts = layoutStr.split(",").map(s => {
          return (s || "").trim();
        }).filter(Boolean);
        for (let j = 0; j < parts.length; j++) {
          const name = parts[j];
          if (unique.indexOf(name) === -1)
            unique.push(name);
        }
      }
      if (kb.active_keymap)
        active = kb.active_keymap;
    }
    return {
      "unique": unique,
      "active": active,
      "mainKeyboard": mainKbName
    };
  }

  function cycleLayout() {
    const kbName = impl.mainKeyboardName || "at-translated-set-2-keyboard";
    Quickshell.execDetached(["hyprctl", "switchxkblayout", kbName, "next"]);
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
            "unique": unique,
            "active": active,
            "mainKeyboard": mainKeyboard
          } = impl.buildLayoutsFromDevices(text);
          impl.layouts = unique;
          impl.currentLayout = active || "";
          impl.mainKeyboardName = mainKeyboard || "";
        } catch (e) {
          Logger.log("KeyboardLayoutImpl(Hypr)", "Failed to parse devices JSON:", String(e));
        }
      }
    }
  }

  Connections {
    function onRawEvent(event) {
      if (!event || event.name !== "activelayout")
        return;

      const payload = typeof event.data === "string" ? event.data : "";
      if (!payload)
        return;

      // payload e.g. "us,us-intl,ara,ara(mac)" -> last entry is active
      const parts = payload.split(",").map(s => {
        return (s || "").trim();
      }).filter(Boolean);
      if (parts.length === 0)
        return;

      impl.layouts = parts;
      impl.currentLayout = parts[parts.length - 1] || "";
    }

    target: impl.active ? Hyprland : null
  }
}
