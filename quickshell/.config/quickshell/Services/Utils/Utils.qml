pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool capsLock: false
  property bool numLock: false
  property bool scrollLock: false

  function resolveIconSource(key, arg2, arg3) {
    const hasThirdArg = arg3 !== undefined && arg3 !== null;
    const candidates = hasThirdArg ? [arg2, key, arg3] : [key, arg2, "application-x-executable"];

    for (const c of candidates) {
      if (!c)
        continue;
      const s = String(c);
      if (s.includes("/") || /^(file|data|qrc):/.test(s))
        return s;

      if (typeof DesktopEntries !== "undefined") {
        const entry = DesktopEntries.heuristicLookup?.(s) || DesktopEntries.byId?.(s);
        if (entry?.icon) {
          const p = Quickshell.iconPath(entry.icon, false);
          if (p)
            return p;
        }
      }

      const p = Quickshell.iconPath(s, false);
      if (p)
        return p;
    }
    return "";
  }

  FolderListModel {
    id: ledFolder

    folder: "file:///sys/class/leds"
    nameFilters: ["*lock"]
    showDirs: true
    showFiles: true // Required: sysfs entries are often symlinks
  }

  Instantiator {
    id: ledInstantiator

    model: ["capslock", "numlock", "scrolllock"]

    delegate: FileView {
      required property string modelData

      // Dynamically find the path. Re-evaluates when ledFolder.count or status changes.
      path: {
        if (ledFolder.status !== FolderListModel.Ready)
          return "";
        for (let i = 0; i < ledFolder.count; i++) {
          const name = ledFolder.get(i, "fileName");
          if (name.endsWith(modelData)) {
            return `/sys/class/leds/${name}/brightness`;
          }
        }
        return "";
      }

      onLoaded: {
        const val = text().trim();
        root[modelData.replace("lock", "Lock")] = val !== "0";
      }
    }
  }

  Timer {
    interval: 100
    repeat: true
    running: true

    onTriggered: {
      for (let i = 0; i < ledInstantiator.count; i++) {
        (ledInstantiator.objectAt(i) as FileView)?.reload();
      }
    }
  }
}
