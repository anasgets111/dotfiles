pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Wayland
import qs.Config
import qs.Services.WM

PanelWindow {
  id: root

  signal dismissed
  signal activated(var item)

  property bool active: false
  property var items: []
  property var filteredItems: []
  property var allItems: []
  property var finder: null
  property int currentIndex: -1
  property int maxResults: 200
  property int windowWidth: 741
  property int windowHeight: 471
  property int cellWidth: 150
  property int cellHeight: 150
  property int cellPadding: 32
  property int itemImageSize: 72
  property bool closeOnActivate: true
  property string placeholderText: qsTr("Type to search")
  property var finderBuilder: null
  property var searchSelector: function (item) {
    const label = root.callSelector(root.labelSelector, item) || "";
    const comment = item?.comment || "";
    return comment ? `${label} ${comment}` : label;
  }
  property var labelSelector: function (item) {
    return item?.name || "";
  }
  property var iconSelector: function (item) {
    return item?.icon || "";
  }
  property var screenTarget: MonitorService ? MonitorService.effectiveMainScreen : null

  color: "transparent"
  visible: active

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  WlrLayershell.exclusiveZone: -1
  screen: screenTarget

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

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

  function toArray(value) {
    if (!value)
      return [];
    if (Array.isArray(value))
      return value;
    if (typeof value.length === "number")
      return Array.from(value);
    return [];
  }

  function buildFinder(list) {
    const builder = root.finderBuilder;
    if (typeof builder !== "function")
      return null;
    try {
      return builder({
        list,
        selector: entry => {
          try {
            const field = root.callSelector(root.searchSelector, entry);
            return typeof field === "string" ? field : String(field ?? "");
          } catch (e) {
            console.warn("SearchGridPanel: selector failed", e);
            return "";
          }
        },
        limit: root.maxResults
      });
    } catch (e) {
      console.warn("SearchGridPanel finderBuilder failed:", e);
      return null;
    }
  }

  function callSelector(selector, item) {
    if (typeof selector === "function") {
      try {
        return selector(item);
      } catch (e) {
        console.warn("SearchGridPanel selector threw:", e);
        return "";
      }
    }
    return selector;
  }

  function gridStride() {
    return itemGrid ? itemGrid.gridColumns : 1;
  }

  function ensureFinder(forceRebuild) {
    const normalized = toArray(items);
    const needs = forceRebuild || !root.finder || !root.arraysEqual(root.allItems, normalized);
    if (!needs)
      return;
    root.allItems = normalized.slice();
    root.finder = root.buildFinder(root.allItems);
    if (!root.finder)
      console.warn("SearchGridPanel: FZF unavailable, using substring filter");
  }

  function updateFilter(query, skipEnsure) {
    if (!skipEnsure)
      ensureFinder(false);
    const text = String(query || "");
    if (root.finder) {
      try {
        root.filteredItems = root.finder.find(text).map(r => r.item);
      } catch (e) {
        console.warn("SearchGridPanel FZF search failed:", e);
        root.filteredItems = [];
      }
    } else {
      const lower = text.toLowerCase();
      const base = root.allItems;
      const filtered = lower.length ? base.filter(entry => {
        try {
          return String(root.callSelector(root.searchSelector, entry) || "").toLowerCase().includes(lower);
        } catch (e) {
          console.warn("SearchGridPanel substring filter failed:", e);
          return false;
        }
      }) : base.slice();
      root.filteredItems = filtered.slice(0, root.maxResults);
    }
    selectDefaultIndex();
  }

  function selectDefaultIndex() {
    const len = root.filteredItems.length;
    if (!len)
      root.currentIndex = -1;
    else if (root.currentIndex < 0 || root.currentIndex >= len)
      root.currentIndex = 0;
  }

  function moveSelection(step) {
    const entries = root.filteredItems;
    if (!entries.length)
      return;
    const len = entries.length;
    const start = root.currentIndex < 0 ? (step > 0 ? -1 : len) : root.currentIndex;
    const next = root.clamp(start + step, 0, len - 1);
    if (next !== root.currentIndex) {
      root.currentIndex = next;
      root.ensureCurrentVisible();
    }
  }

  function ensureCurrentVisible() {
    if (root.currentIndex < 0)
      return;
    Qt.callLater(() => {
      if (itemGrid)
        itemGrid.positionViewAtIndex(root.currentIndex, GridView.Center);
    });
  }

  function activateCurrent() {
    const entries = root.filteredItems;
    if (!entries.length)
      return;
    const i = root.clamp(root.currentIndex, 0, entries.length - 1);
    const entry = entries[i];
    if (entry)
      activateEntry(entry);
  }

  function activateEntry(entry) {
    if (!entry)
      return;
    root.activated(entry);
    if (root.closeOnActivate)
      root.close();
  }

  function open() {
    if (root.active)
      return;
    root.active = true;
  }

  function close() {
    if (!root.active)
      return;
    root.active = false;
    root.currentIndex = -1;
    root.dismissed();
  }

  function resetAndFocus() {
    ensureFinder(true);
    searchField.text = "";
    updateFilter("", true);
    Qt.callLater(() => {
      searchField.forceActiveFocus();
    });
  }

  function handleKeyEvent(event) {
    switch (event.key) {
    case Qt.Key_Escape:
      root.close();
      event.accepted = true;
      break;
    case Qt.Key_Down:
      root.moveSelection(root.gridStride());
      event.accepted = true;
      break;
    case Qt.Key_Up:
      root.moveSelection(-root.gridStride());
      event.accepted = true;
      break;
    case Qt.Key_Left:
      root.moveSelection(-1);
      event.accepted = true;
      break;
    case Qt.Key_Right:
      root.moveSelection(1);
      event.accepted = true;
      break;
    case Qt.Key_Return:
    case Qt.Key_Enter:
      root.activateCurrent();
      event.accepted = true;
      break;
    }
  }

  onActiveChanged: {
    if (root.active)
      root.resetAndFocus();
  }

  onItemsChanged: {
    ensureFinder(true);
    updateFilter(searchField.text, true);
  }

  MouseArea {
    id: dismissArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: function (mouse) {
      if (root.isPointInsidePopup(popupRect, mouse.x, mouse.y)) {
        mouse.accepted = false;
        return;
      }
      root.close();
    }
  }

  function isPointInsidePopup(item, x, y) {
    if (!item)
      return false;
    const local = item.mapFromItem(dismissArea, x, y);
    return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
  }

  Rectangle {
    id: popupRect
    width: root.windowWidth
    height: root.windowHeight
    radius: Theme.itemRadius
    color: Theme.bgColor
    border.color: Theme.activeColor
    border.width: 1
    anchors.centerIn: parent
    focus: true

    Keys.onPressed: event => root.handleKeyEvent(event)

    Column {
      id: contentColumn
      spacing: 8
      anchors.fill: parent
      anchors.margins: 12

      TextField {
        id: searchField
        width: parent.width
        implicitHeight: 30
        placeholderText: root.placeholderText
        onActiveFocusChanged: if (activeFocus)
          selectAll()
        onTextChanged: root.updateFilter(searchField.text)
        Keys.onPressed: event => root.handleKeyEvent(event)
      }

      Item {
        id: gridContainer
        width: parent.width
        height: parent.height - searchField.height - contentColumn.spacing
        clip: true

        GridView {
          id: itemGrid
          anchors.centerIn: parent
          clip: true
          model: root.filteredItems
          currentIndex: root.currentIndex
          readonly property int modelCount: root.filteredItems ? root.filteredItems.length : 0
          readonly property real maxWidth: gridContainer.width
          readonly property real maxHeight: gridContainer.height
          readonly property int availableColumns: Math.max(1, Math.floor(maxWidth / root.cellWidth))
          readonly property int gridColumns: Math.max(1, Math.min(modelCount || 1, availableColumns))
          readonly property int gridRows: Math.max(1, Math.ceil((modelCount || 1) / gridColumns))
          width: Math.min(maxWidth, Math.max(root.cellWidth, gridColumns * root.cellWidth))
          height: Math.min(maxHeight, Math.max(root.cellHeight, gridRows * root.cellHeight))
          cellWidth: root.cellWidth
          cellHeight: root.cellHeight
          flow: GridView.FlowLeftToRight
          interactive: true
          snapMode: GridView.SnapToRow
          highlightMoveDuration: Theme.animationDuration

          delegate: Item {
            id: itemDelegate
            required property var modelData
            required property int index

            width: GridView.view ? GridView.view.cellWidth : (parent ? parent.width : 0)
            height: GridView.view ? GridView.view.cellHeight : 0
            property bool hovered: mouseArea.containsMouse
            readonly property bool selected: GridView.isCurrentItem
            readonly property string resolvedLabel: root.callSelector(root.labelSelector, itemDelegate.modelData) || ""
            readonly property string resolvedIcon: root.callSelector(root.iconSelector, itemDelegate.modelData) || ""

            Rectangle {
              anchors.centerIn: parent
              width: Math.max(0, parent.width - root.cellPadding)
              height: Math.max(0, parent.height - root.cellPadding)
              radius: Theme.itemRadius
              visible: itemDelegate.hovered || itemDelegate.selected
              color: itemDelegate.selected ? Theme.activeColor : Theme.onHoverColor
              opacity: itemDelegate.selected ? 0.3 : 0.18
            }

            Column {
              anchors.centerIn: parent
              spacing: 10
              width: Math.max(0, parent.width - root.cellPadding)

              Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.itemImageSize
                height: root.itemImageSize
                fillMode: Image.PreserveAspectFit
                source: itemDelegate.resolvedIcon
                sourceSize.width: width
                sourceSize.height: height
                visible: source !== ""
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: itemDelegate.resolvedLabel
                color: Theme.textContrast(Theme.bgColor)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                maximumLineCount: 1
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
                root.currentIndex = itemDelegate.index;
                root.activateEntry(itemDelegate.modelData);
              }
              onEntered: root.currentIndex = itemDelegate.index
            }
          }
        }
      }
    }
  }
}
