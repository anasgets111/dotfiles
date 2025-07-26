pragma Singleton

import Quickshell
import QtQuick

QtObject {
  id: root

  // 1. raw session name, e.g. "Hyprland", "GNOME", "KDE"
  property string sessionName: ""
  // 2. normalized lowercase
  readonly property string session: sessionName.toLowerCase().split(":")[0]
  // 3. booleans
  property bool isHyprland: session === "hyprland"
  property bool isNiri: session === "niri"
  // ...add more as needed

  Component.onCompleted: {
    // Try XDG_SESSION_DESKTOP, then XDG_CURRENT_DESKTOP, then DESKTOP_SESSION
    sessionName = Quickshell.env("XDG_SESSION_DESKTOP")
              || Quickshell.env("XDG_CURRENT_DESKTOP")
              || Quickshell.env("DESKTOP_SESSION")
              || ""
    console.log("Detected session:", sessionName)
  }
}
