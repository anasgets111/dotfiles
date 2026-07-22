pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.Services.Utils

Singleton {
  id: root

  property bool capsLock: false
  property bool numLock: false
  property bool scrollLock: false

  function copyText(text: string): void {
    Command.run(["wl-copy"], null, "clipboard", String(text ?? ""));
  }
  function fmtKib(kib: real): string {
    const formatted = formatKib(kib || 0);
    return `${formatted.value.toFixed(1)} ${formatted.unit}`;
  }
  function formatKib(kib: real): var {
    const units = ["TiB", "GiB", "MiB", "KiB"];
    const thresholds = [1024 ** 3, 1024 ** 2, 1024, 0];
    for (let index = 0; index < thresholds.length; index++) {
      const threshold = thresholds[index];
      if (kib >= threshold)
        return {
          value: threshold > 0 ? kib / threshold : kib,
          unit: units[index]
        };
    }
    return {
      value: kib,
      unit: "KiB"
    };
  }
  function lookupDesktopEntryName(appId: string): string {
    if (typeof DesktopEntries === "undefined" || !appId)
      return "";
    const entry = DesktopEntries.heuristicLookup?.(appId) || DesktopEntries.byId?.(appId);
    return entry?.name || "";
  }
  function normalizeImageUrl(imageSource: string): string {
    if (!imageSource)
      return "";
    if (imageSource.startsWith("file://"))
      return imageSource;
    if (imageSource.startsWith("/"))
      return "file://" + imageSource;
    return imageSource;
  }

  // With two arguments appId wins; providing fallbackIcon makes iconHint win.
  function resolveIconSource(appId: string, iconHint: var, fallbackIcon: var): string {
    const hasFallback = fallbackIcon !== undefined;
    const fallback = hasFallback ? String(fallbackIcon ?? "") : "application-x-executable";
    const candidates = hasFallback ? [iconHint, appId] : [appId, iconHint];
    const fallbackPath = Quickshell.hasThemeIcon(fallback) ? Quickshell.iconPath(fallback) : "";

    for (const candidate of candidates) {
      if (!candidate)
        continue;
      const source = String(candidate);

      if (source.includes("/") || /^(file|data|qrc):/.test(source))
        return normalizeImageUrl(source);

      if (typeof DesktopEntries !== "undefined") {
        const entry = DesktopEntries.heuristicLookup?.(source) || DesktopEntries.byId?.(source);
        const entryIcon = String(entry?.icon ?? "");
        if (entryIcon) {
          if (entryIcon.includes("/") || /^(file|data|qrc):/.test(entryIcon))
            return normalizeImageUrl(entryIcon);
          const entryIconPath = Quickshell.iconPath(entryIcon, true);
          if (entryIconPath)
            return entryIconPath;
        }
      }

      const iconPath = Quickshell.iconPath(source, true);
      if (iconPath)
        return iconPath;
    }

    return fallbackPath;
  }

  FolderListModel {
    id: ledFolder

    folder: "file:///sys/class/leds"
    nameFilters: ["*lock"]
    showDirs: true
    showFiles: true // sysfs entries are symlinks and strict filters hide them
  }
  Instantiator {
    id: ledInstantiator

    model: ["capslock", "numlock", "scrolllock"]

    delegate: FileView {
      required property string modelData

      path: {
        if (ledFolder.status !== FolderListModel.Ready)
          return "";
        for (let index = 0; index < ledFolder.count; index++) {
          const fileName = ledFolder.get(index, "fileName");
          if (fileName.endsWith(modelData))
            return `/sys/class/leds/${fileName}/brightness`;
        }
        return "";
      }

      onLoaded: root[modelData.replace("lock", "Lock")] = text().trim() === "1"
    }
  }

  // sysfs virtual files do not emit inotify events.
  Timer {
    interval: 100
    repeat: true
    running: ledFolder.count > 0

    onTriggered: {
      for (let index = 0; index < ledInstantiator.count; index++)
        (ledInstantiator.objectAt(index) as FileView)?.reload();
    }
  }
}
