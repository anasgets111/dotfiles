pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Services.Utils
import qs.Components

SearchGridPanel {
  id: launcherWindow

  property var appEntries: []

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

  function sanitizeCommand(entry) {
    const raw = String(entry?.exec || entry?.command || "");
    return raw.replace(/%[fFuUdDnNickvm]/g, "").replace(/\s+/g, " ").trim();
  }

  cellHeight: 150
  cellPadding: 32
  cellWidth: 150
  finderBuilder: params => {
    if (typeof Fzf === "undefined" || typeof Fzf.finder !== "function")
      return null;
    return new Fzf.finder(params.list, {
      selector: params.selector,
      limit: params.limit,
      tiebreakers: [Fzf.by_start_asc, Fzf.by_length_asc]
    });
  }
  iconSelector: function (entry) {
    const resolvedName = entry?.name || "";
    return Utils.resolveIconSource(entry?.id || resolvedName, entry?.icon, "application-x-executable");
  }
  itemImageSize: 72
  items: appEntries
  labelSelector: function (entry) {
    return entry?.name || "";
  }
  maxResults: 200
  windowHeight: 471
  windowWidth: 741

  Component.onCompleted: {
    refreshEntries();
    open();
  }
  onActivated: entry => launcherWindow.launchEntry(entry)
  onActiveChanged: if (active)
    refreshEntries()
}
