pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Services.Utils
import qs.Components

SearchGridPanel {
  id: launcherWindow

  property var appEntries: []

  items: appEntries
  maxResults: 200
  windowWidth: 741
  windowHeight: 471
  cellWidth: 150
  cellHeight: 150
  cellPadding: 32
  itemImageSize: 72

  finderBuilder: params => {
    if (typeof Fzf === "undefined" || typeof Fzf.finder !== "function")
      return null;
    return new Fzf.finder(params.list, {
      selector: params.selector,
      limit: params.limit
    });
  }

  labelSelector: function (entry) {
    return entry?.name || "";
  }
  iconSelector: function (entry) {
    const resolvedName = entry?.name || "";
    return Utils.resolveIconSource(entry?.id || resolvedName, entry?.icon, "application-x-executable");
  }

  onActivated: entry => launcherWindow.launchEntry(entry)

  Component.onCompleted: {
    refreshEntries();
    open();
  }

  onActiveChanged: if (active)
    refreshEntries()

  function launchEntry(entry) {
    const command = sanitizeCommand(entry);
    if (!command) {
      Logger.warn("Launcher", "entry missing exec command", entry);
      return;
    }
    try {
      if (typeof Quickshell !== "undefined" && typeof Quickshell.execDetached === "function")
        Quickshell.execDetached(Utils.shCommand(command));
      else
        Logger.warn("Launcher", "execDetached unavailable");
    } catch (e) {
      Logger.warn("Launcher", "execDetached failed", e);
    }
  }

  function sanitizeCommand(entry) {
    const raw = String(entry?.exec || entry?.command || "");
    return raw.replace(/%[fFuUdDnNickvm]/g, "").replace(/\s+/g, " ").trim();
  }

  function refreshEntries() {
    let values = [];
    try {
      if (typeof DesktopEntries !== "undefined" && DesktopEntries?.applications?.values)
        values = DesktopEntries.applications.values;
    } catch (err) {
      Logger.warn("Launcher", "failed to load DesktopEntries", err);
    }
    appEntries = values || [];
  }
}
