pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Item {
  id: root

  // 1. raw session name, e.g. "Hyprland", "GNOME", "KDE"
  property string sessionName: ""
  // 2. normalized lowercase
  readonly property string session: sessionName.toLowerCase().split(":")[0]
  // 3. booleans
  property bool isHyprland: session === "hyprland"
  property bool isNiri: session === "niri"
  // ...add more as needed

  // Distro detection
  property string distroId: ""

  // UPower battery detection
  property var upowerDevice: UPower.displayDevice
  readonly property bool isLaptopBattery: upowerDevice && upowerDevice.type === 2 && upowerDevice.isPresent

  FileView {
    id: osReleaseFile
    path: "/etc/os-release"
    blockLoading: true
    preload: true
    onLoaded: {
      var idMatch = osReleaseFile.text().match(/^ID="?([^"\n]+)"?/m)
      root.distroId = idMatch ? idMatch[1] : ""
      console.log("Detected distro:", root.distroId)
    }
  }

  Component.onCompleted: {
    // Try XDG_SESSION_DESKTOP, then XDG_CURRENT_DESKTOP, then DESKTOP_SESSION
    sessionName = Quickshell.env("XDG_SESSION_DESKTOP")
              || Quickshell.env("XDG_CURRENT_DESKTOP")
              || Quickshell.env("DESKTOP_SESSION")
              || ""
    console.log("Detected session:", sessionName)
  }
}
