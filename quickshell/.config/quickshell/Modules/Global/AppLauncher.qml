pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Config
import qs.Services.Utils
import qs.Components

SearchGridPanel {
  id: launcherWindow

  function launchEntry(entry) {
    const desktopId = String(entry?.id || "").replace(/\.desktop$/, "");
    if (!desktopId)
      return;
    Quickshell.execDetached(["gtk-launch", desktopId]);
  }

  cellHeight: Theme.launcherCellSize
  cellPadding: Theme.spacingXl + Theme.spacingSm
  cellWidth: Theme.launcherCellSize
  finderBuilder: params => {
    if (!Fzf?.finder)
      return null;
    return new Fzf.finder(params.list, {
      selector: params.selector,
      limit: params.limit,
      tiebreakers: [Fzf.by_start_asc, Fzf.by_length_asc]
    });
  }
  iconSelector: entry => Utils.resolveIconSource(entry?.id || entry?.name || "", entry?.icon, "application-x-executable")
  itemImageSize: Theme.launcherIconSize
  items: DesktopEntries.applications.values
  labelSelector: entry => entry?.name || ""
  maxResults: 200
  windowHeight: Theme.launcherWindowHeight
  windowWidth: Theme.launcherWindowWidth

  Component.onCompleted: open()
  onActivated: entry => launchEntry(entry)
}
