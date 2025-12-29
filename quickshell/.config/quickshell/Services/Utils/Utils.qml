pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

/**
 * Global Singleton for managing system-wide keyboard state and UI utilities.
 * * Capabilities:
 * 1. Tracks Keyboard LED status (Caps, Num, Scroll) by reading /sys/class/leds.
 * 2. Provides a centralized icon resolution helper.
 */
Singleton {
  id: root

  // -- Public API ------------------------------------------------------------

  property bool capsLock: false
  property bool numLock: false
  property bool scrollLock: false

  /**
   * Resolves a valid icon path from a variety of sources (system theme, file path, raw data).
   * Priorities: 3rd arg -> 2nd arg -> key -> fallback.
   */
  function resolveIconSource(key: string, arg2: var, arg3: var): string {
    const hasThirdArg = arg3 !== undefined && arg3 !== null;
    const candidates = hasThirdArg ? [arg2, key, arg3] : [key, arg2, "application-x-executable"];

    for (const c of candidates) {
      if (!c)
        continue;

      const s = String(c);
      // Direct file paths or resources are returned immediately
      if (s.includes("/") || /^(file|data|qrc):/.test(s))
        return s;

      // Lookup in XDG Desktop standards if available
      if (typeof DesktopEntries !== "undefined") {
        const entry = DesktopEntries.heuristicLookup?.(s) || DesktopEntries.byId?.(s);
        if (entry?.icon) {
          const p = Quickshell.iconPath(entry.icon, false);
          if (p)
            return p;
        }
      }

      // Fallback to Quickshell icon theme lookup
      const p = Quickshell.iconPath(s, false);
      if (p)
        return p;
    }
    return "";
  }

  // -- Internal Implementation -----------------------------------------------

  /**
   * Scans the Linux sysfs LED directory.
   * We need this because input device names change across reboots (e.g., input3::capslock).
   */
  FolderListModel {
    id: ledFolder

    folder: "file:///sys/class/leds"
    nameFilters: ["*lock"]
    showDirs: true
    showFiles: true // Required: sysfs entries are often symlinks, which strict filters might hide
  }

  /**
   * Manages a non-visual FileView object for each lock type.
   * Unlike Repeater, Instantiator does not require a visual parent.
   */
  Instantiator {
    id: ledInstantiator

    model: ["capslock", "numlock", "scrolllock"]

    delegate: FileView {
      required property string modelData

      /**
       * Dynamically resolves the specific path for this lock type.
       * Re-evaluates automatically when the sysfs FolderListModel updates.
       */
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

      /**
       * Updates the corresponding Singleton property (e.g., capsLock)
       * whenever the file content is read.
       */
      onLoaded: {
        const rawValue = text().trim();
        const propName = modelData.replace("lock", "Lock"); // "capslock" -> "capsLock"
        root[propName] = rawValue !== "0";
      }
    }
  }

  /**
   * Polls the LED status files.
   * Polling is required because /sys/class files are virtual kernel interfaces
   * and do not emit standard filesystem change events (inotify).
   */
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
