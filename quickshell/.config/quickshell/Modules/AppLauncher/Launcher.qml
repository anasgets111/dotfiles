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

  signal dismissed

  property bool active: false
  readonly property int contentWidth: 741
  readonly property int contentHeight: 471
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
          return comment ? `${name} ${comment}` : name;
        },
        limit: launcherWindow.maxResults
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
      launcherWindow.moveSelection(launcherWindow.gridStride());
      event.accepted = true;
      break;
    case Qt.Key_Up:
      launcherWindow.moveSelection(-launcherWindow.gridStride());
      event.accepted = true;
      break;
    case Qt.Key_Left:
      launcherWindow.moveSelection(-1);
      event.accepted = true;
      break;
    case Qt.Key_Right:
      launcherWindow.moveSelection(1);
      event.accepted = true;
      break;
    case Qt.Key_Return:
    case Qt.Key_Enter:
      launcherWindow.activateCurrent();
      event.accepted = true;
      break;
    }
  }
  function gridStride() {
    if (!appGrid)
      return 1;
    const cols = appGrid.gridColumns || 0;
    return cols > 0 ? cols : 1;
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
  }
  function close() {
    if (!launcherWindow.active)
      return;
    launcherWindow.active = false;
    launcherWindow.currentIndex = -1;
    launcherWindow.dismissed();
  }

  function resetAndFocus() {
    launcherWindow.ensureFinder(true);
    search.text = "";
    launcherWindow.updateFilter("", true);
    Qt.callLater(() => {
      search.forceActiveFocus();
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
      if (appGrid)
        appGrid.positionViewAtIndex(launcherWindow.currentIndex, GridView.Center);
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
    const sanitized = String(entry.exec || entry.command || "").replace(/%[fFuUdDnNickvm]/g, "").replace(/\s+/g, " ").trim();

    if (!sanitized) {
      console.warn("Launcher: entry missing exec command", entry);
      return;
    }

    try {
      Quickshell.execDetached(Utils.shCommand(sanitized));
      launcherWindow.close();
    } catch (e) {
      console.warn("Launcher: execDetached failed", e);
    }
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
      }

      Item {
        id: gridContainer
        width: parent.width
        height: parent.height - search.height - contentColumn.spacing
        clip: true

        GridView {
          id: appGrid
          anchors.centerIn: parent
          clip: true
          model: launcherWindow.filteredEntries
          currentIndex: launcherWindow.currentIndex
          readonly property int cellPadding: 32
          readonly property real maxWidth: gridContainer.width
          readonly property real maxHeight: gridContainer.height
          readonly property int modelCount: Array.isArray(model) ? model.length : (model && typeof model.length === "number" ? model.length : (typeof model.count === "number" ? model.count : 0))
          readonly property int gridColumns: {
            const availableColumns = Math.max(1, Math.floor(maxWidth / cellWidth));
            if (!modelCount)
              return availableColumns;
            return Math.max(1, Math.min(modelCount, availableColumns));
          }
          readonly property int gridRows: gridColumns > 0 ? Math.max(1, Math.ceil((modelCount || 1) / gridColumns)) : 1
          width: Math.min(maxWidth, Math.max(cellWidth, gridColumns * cellWidth))
          height: Math.min(maxHeight, Math.max(cellHeight, gridRows * cellHeight))
          cellWidth: 150
          cellHeight: 150
          flow: GridView.FlowLeftToRight
          interactive: true
          snapMode: GridView.SnapToRow
          highlightMoveDuration: Theme.animationDuration

          delegate: Item {
            id: appDelegate
            required property var modelData
            required property int index

            width: GridView.view ? GridView.view.cellWidth : (parent ? parent.width : 0)
            height: GridView.view ? GridView.view.cellHeight : 0
            property bool hovered: mouseArea.containsMouse
            readonly property bool selected: GridView.isCurrentItem
            readonly property string resolvedName: appDelegate.modelData?.name || ""
            readonly property string resolvedIcon: Utils.resolveIconSource(appDelegate.modelData?.id || appDelegate.resolvedName, appDelegate.modelData?.icon, "application-x-executable")

            Rectangle {
              id: selectionBackground
              anchors.centerIn: parent
              width: Math.max(0, parent.width - appGrid.cellPadding)
              height: Math.max(0, parent.height - appGrid.cellPadding)
              radius: Theme.itemRadius
              visible: appDelegate.hovered || appDelegate.selected
              color: appDelegate.selected ? Theme.activeColor : Theme.onHoverColor
              opacity: appDelegate.selected ? 0.3 : 0.18
            }

            Column {
              id: entryContent
              anchors.centerIn: parent
              spacing: 10
              width: Math.max(0, parent.width - appGrid.cellPadding)

              Image {
                id: appIcon
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72
                height: 72
                fillMode: Image.PreserveAspectFit
                source: appDelegate.resolvedIcon
                sourceSize.width: width
                sourceSize.height: height
                visible: source !== ""
              }

              Text {
                id: appLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: appDelegate.resolvedName
                color: Theme.textContrast(Theme.bgColor)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                width: parent.width
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
}
