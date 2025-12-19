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
    showDirs: true
    showFiles: false
  }

  Repeater {
    id: ledRepeater

    model: ["capslock", "numlock", "scrolllock"]

    FileView {
      required property string modelData

      path: {
        for (let i = 0; i < ledFolder.count; i++) {
          const name = ledFolder.get(i, "fileName");
          if (name.endsWith(modelData))
            return `/sys/class/leds/${name}/brightness`;
        }
        return "";
      }

      onLoaded: root[modelData.replace("lock", "Lock")] = text().trim() !== "0"
    }
  }

  Timer {
    interval: 100
    repeat: true
    running: true

    onTriggered: {
      for (let i = 0; i < ledRepeater.count; i++)
        (ledRepeater.itemAt(i) as FileView)?.reload();
    }
  }
}
