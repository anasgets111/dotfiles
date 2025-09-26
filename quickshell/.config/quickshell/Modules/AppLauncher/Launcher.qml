pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Wayland
import qs.Services.Utils
import qs.Config
import qs.Services.WM

PanelWindow {
  id: launcherWindow

  signal opened
  signal dismissed

  property bool active: false
  readonly property int contentWidth: 320
  readonly property int contentHeight: 500
  readonly property int maxResults: 200

  property var finder: null
  property var allEntries: []
  property var filteredEntries: []
  property int currentIndex: -1

  color: "transparent"
  visible: active

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  WlrLayershell.exclusiveZone: -1
  screen: MonitorService ? MonitorService.effectiveMainScreen : null

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  // helpers
  function clamp(v, lo, hi) {
    return Math.min(Math.max(v, lo), hi);
  }
  function arraysEqual(a, b) {
    a = Array.isArray(a) ? a : [];
    b = Array.isArray(b) ? b : [];
    if (a.length !== b.length)
      return false;
    for (let i = 0; i < a.length; i++)
      if (a[i] !== b[i])
        return false;
    return true;
  }
  function getApplicationsModel() {
    return (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values) ? DesktopEntries.applications.values : [];
  }
  function buildFinder(list) {
    if (typeof Fzf === "undefined" || typeof Fzf.finder !== "function")
      return null;
    try {
      return new Fzf.finder(list, {
        selector: entry => {
          const name = entry?.name || "";
          const comment = entry?.comment || "";
          return comment && comment.length ? `${name} ${comment}` : name;
        },
        limit: launcherWindow.maxResults,
        fuzzy: "v2",
        normalize: true,
        casing: "smart-case"
      });
    } catch (e) {
      console.warn("Launcher FZF init failed:", e);
      return null;
    }
  }
  function handleKeyEvent(event) {
    switch (event.key) {
    case Qt.Key_Escape:
      launcherWindow.close();
      event.accepted = true;
      break;
    case Qt.Key_Down:
      launcherWindow.moveSelection(1);
      event.accepted = true;
      break;
    case Qt.Key_Up:
      launcherWindow.moveSelection(-1);
      event.accepted = true;
      break;
    case Qt.Key_Return:
    case Qt.Key_Enter:
      launcherWindow.activateCurrent();
      event.accepted = true;
      break;
    }
  }
  function selectDefaultIndex() {
    const len = launcherWindow.filteredEntries.length;
    if (!len)
      launcherWindow.currentIndex = -1;
    else if (launcherWindow.currentIndex < 0 || launcherWindow.currentIndex >= len)
      launcherWindow.currentIndex = 0;
  }

  function open() {
    if (launcherWindow.active)
      return;
    launcherWindow.active = true;
    launcherWindow.opened();
  }
  function close() {
    if (!launcherWindow.active)
      return;
    launcherWindow.releaseSearchFocus();
    launcherWindow.dismiss();
    launcherWindow.active = false;
    launcherWindow.currentIndex = -1;
    launcherWindow.dismissed();
  }
  function toggle() {
    launcherWindow.active ? launcherWindow.close() : launcherWindow.open();
  }

  function releaseSearchFocus() {
    if (search && search.activeFocus)
      popupRect.forceActiveFocus();
  }
  function resetAndFocus() {
    launcherWindow.ensureFinder(true);
    search.text = "";
    launcherWindow.updateFilter("", true);
    Qt.callLater(() => {
      search.forceActiveFocus();
      search.selectAll();
    });
  }
  function dismiss() {
    if (search && search.activeFocus)
      search.focus = false;
  }

  function moveSelection(step) {
    const entries = launcherWindow.filteredEntries;
    if (!entries.length)
      return;
    const len = entries.length;
    const start = launcherWindow.currentIndex < 0 ? (step > 0 ? -1 : len) : launcherWindow.currentIndex;
    const next = launcherWindow.clamp(start + step, 0, len - 1);
    if (next !== launcherWindow.currentIndex) {
      launcherWindow.currentIndex = next;
      launcherWindow.ensureCurrentVisible();
    }
  }
  function ensureCurrentVisible() {
    if (launcherWindow.currentIndex < 0)
      return;
    Qt.callLater(() => {
      if (appList)
        appList.positionViewAtIndex(launcherWindow.currentIndex, ListView.Center);
    });
  }
  function activateCurrent() {
    const entries = launcherWindow.filteredEntries;
    if (!entries.length)
      return;
    const i = launcherWindow.clamp(launcherWindow.currentIndex, 0, entries.length - 1);
    const entry = entries[i];
    if (entry)
      launcherWindow.activateEntry(entry);
  }

  function ensureFinder(forceRebuild) {
    const apps = launcherWindow.getApplicationsModel();
    const needs = forceRebuild || !launcherWindow.finder || !launcherWindow.arraysEqual(launcherWindow.allEntries, apps);
    if (!needs)
      return;
    launcherWindow.allEntries = apps.slice();
    launcherWindow.finder = launcherWindow.buildFinder(launcherWindow.allEntries);
    if (!launcherWindow.finder)
      console.warn("Launcher: FZF unavailable, using substring filter");
  }
  function updateFilter(query, skipEnsure) {
    if (!skipEnsure)
      launcherWindow.ensureFinder(false);
    const text = String(query || "");
    if (launcherWindow.finder) {
      try {
        launcherWindow.filteredEntries = launcherWindow.finder.find(text).map(r => r.item);
      } catch (e) {
        console.warn("Launcher FZF search failed:", e);
        launcherWindow.filteredEntries = [];
      }
    } else {
      const lower = text.toLowerCase();
      const base = launcherWindow.allEntries;
      const filtered = lower.length ? base.filter(entry => String(entry?.name || "").toLowerCase().includes(lower)) : base.slice();
      launcherWindow.filteredEntries = filtered.slice(0, launcherWindow.maxResults);
    }
    launcherWindow.selectDefaultIndex();
  }

  function activateEntry(entry) {
    if (!entry)
      return;
    let launched = false;
    const entryId = String(entry.id || entry.desktopId || entry.desktopFile || entry.appId || entry.name || "").trim();

    try {
      if (typeof entry.launch === "function") {
        entry.launch();
        launched = true;
      }
    } catch (e) {
      console.warn("Launcher: entry.launch failed", e);
    }

    if (!launched && typeof DesktopEntries !== "undefined") {
      try {
        const launchFn = Reflect?.get(DesktopEntries, "launch");
        const launchById = Reflect?.get(DesktopEntries, "launchById");
        const launchDesktopEntry = Reflect?.get(DesktopEntries, "launchDesktopEntry");
        if (typeof launchFn === "function") {
          launchFn.call(DesktopEntries, entry);
          launched = true;
        } else if (typeof launchById === "function" && entryId) {
          launchById.call(DesktopEntries, entryId);
          launched = true;
        } else if (typeof launchDesktopEntry === "function" && entryId) {
          launchDesktopEntry.call(DesktopEntries, entryId);
          launched = true;
        }
      } catch (e) {
        console.warn("Launcher: DesktopEntries launch failed", e);
      }
    }

    if (!launched && entryId) {
      try {
        Utils.runCmd(["gtk-launch", entryId], function () {}, launcherWindow);
        launched = true;
      } catch (e) {
        console.warn("Launcher: gtk-launch fallback failed", e);
      }
    }

    if (!launched && entry?.exec) {
      const sanitized = String(entry.exec).replace(/%[fFuUdDnNickvm]/g, "").replace(/\s+/g, " ").trim();
      if (sanitized) {
        try {
          Utils.runCmd(Utils.shCommand(sanitized), function () {}, launcherWindow);
          launched = true;
        } catch (e) {
          console.warn("Launcher: exec fallback failed", e);
        }
      }
    }

    if (launched)
      launcherWindow.close();
  }

  onActiveChanged: {
    if (launcherWindow.active)
      launcherWindow.resetAndFocus();
    else
      launcherWindow.dismiss();
  }

  function isPointInsidePopup(item, x, y) {
    if (!item)
      return false;
    const local = item.mapFromItem(dismissArea, x, y);
    return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
  }

  MouseArea {
    id: dismissArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    propagateComposedEvents: true
    onPressed: function (mouse) {
      if (launcherWindow.isPointInsidePopup(popupRect, mouse.x, mouse.y)) {
        mouse.accepted = false;
        return;
      }
      mouse.accepted = true;
      launcherWindow.close();
    }
  }

  Rectangle {
    id: popupRect
    width: launcherWindow.contentWidth
    height: launcherWindow.contentHeight
    radius: Theme.itemRadius
    color: Theme.bgColor
    border.color: Theme.activeColor
    border.width: 1
    anchors.centerIn: parent
    focus: true

    Keys.onPressed: event => launcherWindow.handleKeyEvent(event)

    Column {
      id: contentColumn
      spacing: 8
      anchors.fill: parent
      anchors.margins: 12

      TextField {
        id: search
        width: parent.width
        implicitHeight: 30
        placeholderText: qsTr("Type to search")
        onActiveFocusChanged: if (activeFocus)
          selectAll()
        onTextChanged: launcherWindow.updateFilter(search.text)
        Keys.onPressed: event => launcherWindow.handleKeyEvent(event)
        onAccepted: launcherWindow.activateCurrent()
      }

      ListView {
        id: appList
        width: parent.width
        height: parent.height - search.height - contentColumn.spacing
        clip: true
        model: launcherWindow.filteredEntries
        currentIndex: launcherWindow.currentIndex
        highlightMoveDuration: Theme.animationDuration

        delegate: Item {
          id: appDelegate
          required property var modelData
          required property int index

          height: 40
          width: ListView.view ? ListView.view.width : (parent ? parent.width : 0)
          property bool hovered: mouseArea.containsMouse
          readonly property bool selected: ListView.isCurrentItem
          readonly property string resolvedName: appDelegate.modelData?.name || ""
          readonly property string resolvedIcon: Utils.resolveIconSource(appDelegate.modelData?.id || appDelegate.resolvedName, appDelegate.modelData?.icon, "application-x-executable")

          Rectangle {
            anchors.fill: parent
            radius: Theme.itemRadius
            visible: appDelegate.hovered || appDelegate.selected
            color: appDelegate.selected ? Theme.activeColor : Theme.onHoverColor
            opacity: appDelegate.selected ? 0.3 : 0.18
          }

          Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 8
            spacing: 10
            height: parent.height

            Image {
              id: appIcon
              width: 26
              height: 26
              anchors.verticalCenter: parent.verticalCenter
              fillMode: Image.PreserveAspectFit
              source: appDelegate.resolvedIcon
              sourceSize.width: width
              sourceSize.height: height
              visible: source !== ""
            }

            Text {
              id: appLabel
              anchors.verticalCenter: parent.verticalCenter
              text: appDelegate.resolvedName
              color: Theme.textContrast(Theme.bgColor)
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              elide: Text.ElideRight
              horizontalAlignment: Text.AlignLeft
              verticalAlignment: Text.AlignVCenter
              width: parent.width - (appIcon.visible ? appIcon.width + parent.spacing : 0)
            }
          }

          MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: function () {
              launcherWindow.currentIndex = appDelegate.index;
              launcherWindow.activateEntry(appDelegate.modelData);
            }
            onEntered: launcherWindow.currentIndex = appDelegate.index
          }
        }
      }
    }
  }
}
