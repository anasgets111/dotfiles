pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Global Singleton for managing system-wide keyboard state and UI utilities.
// Capabilities:
// 1. Tracks Keyboard LED status (Caps, Num, Scroll) by reading /sys/class/leds.
// 2. Provides a centralized icon resolution helper.
Singleton {
  id: root

  property bool capsLock: false
  property bool numLock: false
  property bool scrollLock: false

  // Normalizes image paths for QML Image sources (adds file:// prefix for absolute paths)
  function normalizeImageUrl(img: string): string {
    if (!img)
      return "";
    if (img.startsWith("file://"))
      return img;
    if (img.startsWith("/"))
      return "file://" + img;
    return img;
  }

  // Resolves a valid icon path from a variety of sources (system theme, file path, raw data).
  // Priorities: 3rd arg -> 2nd arg -> key -> fallback.
  function resolveIconSource(key: string, arg2: var, arg3: var): string {
    const fallback = (arg3 !== undefined && arg3 !== null) ? String(arg3) : "application-x-executable";
    const candidates = arg3 ? [arg2, key] : [key, arg2];

    for (const c of candidates) {
      if (!c)
        continue;
      const s = String(c);

      // Direct paths
      if (s.includes("/") || /^(file|data|qrc):/.test(s))
        return s;

      // DesktopEntries
      if (typeof DesktopEntries !== "undefined") {
        const entry = DesktopEntries.heuristicLookup?.(s) || DesktopEntries.byId?.(s);
        if (entry?.icon)
          return Quickshell.iconPath(entry.icon, fallback);
      }

      // Icon theme with fallback
      const path = Quickshell.iconPath(s, fallback);
      if (path)
        return path;
    }

    return Quickshell.iconPath(fallback);
  }

  // Scans the Linux sysfs LED directory.
  // We need this because input device names change across reboots (e.g., input3::capslock).
  FolderListModel {
    id: ledFolder

    folder: "file:///sys/class/leds"
    nameFilters: ["*lock"]
    showDirs: true
    showFiles: true // Required: sysfs entries are often symlinks, which strict filters might hide
  }

  // Manages a non-visual FileView object for each lock type.
  // Unlike Repeater, Instantiator does not require a visual parent.
  Instantiator {
    id: ledInstantiator

    model: ["capslock", "numlock", "scrolllock"]

    delegate: FileView {
      required property string modelData

      // Dynamically resolves the specific path for this lock type.
      // Re-evaluates automatically when the sysfs FolderListModel updates.
      path: {
        if (ledFolder.status !== FolderListModel.Ready)
          return "";
        for (let i = 0; i < ledFolder.count; i++) {
          const fileName = ledFolder.get(i, "fileName");
          if (fileName.endsWith(modelData)) {
            return `/sys/class/leds/${fileName}/brightness`;
          }
        }
        return "";
      }

      // Updates the corresponding Singleton property (e.g., capsLock)
      // whenever the file content is read.
      onLoaded: {
        const rawValue = text().trim();
        const propName = modelData.replace("lock", "Lock"); // "capslock" -> "capsLock"
        root[propName] = rawValue !== "0";
      }
    }
  }

  // Polls the LED status files.
  // Polling is required because /sys/class files are virtual kernel interfaces
  // and do not emit standard filesystem change events (inotify).
  Timer {
    interval: 100
    repeat: true
    running: true

    onTriggered: {
      for (let i = 0; i < ledInstantiator.count; i++) {
        // Safe cast to FileView to access the .reload() method
        (ledInstantiator.objectAt(i) as FileView)?.reload();
      }
    }
  }
}
