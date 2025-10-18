pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Services.Utils
import qs.Components

SearchGridPanel {
  id: launcherWindow

  property var appEntries: DesktopEntries.applications.values

  function launchEntry(entry) {
    const cmd = sanitizeCommand(entry);
    if (cmd)
      Quickshell.execDetached(["sh", "-c", cmd]);
  }

  function sanitizeCommand(entry) {
    return String(entry?.exec || entry?.command || "").replace(/%[fFuUdDnNickvm]/g, "").replace(/\s+/g, " ").trim();
  }

  cellHeight: 150
  cellPadding: 32
  cellWidth: 150
  finderBuilder: params => {
    if (!Fzf?.finder)
      return null;
    return new Fzf.finder(params.list, {
      selector: params.selector,
      limit: params.limit,
      tiebreakers: [Fzf.by_start_asc, Fzf.by_length_asc]
    });
  }
  iconSelector: entry => {
    const name = entry?.name || "";
    return Utils.resolveIconSource(entry?.id || name, entry?.icon, "application-x-executable");
  }
  itemImageSize: 72
  items: appEntries
  labelSelector: entry => entry?.name || ""
  maxResults: 200
  windowHeight: 471
  windowWidth: 741

  Component.onCompleted: open()
  onActivated: entry => launcherWindow.launchEntry(entry)
}
