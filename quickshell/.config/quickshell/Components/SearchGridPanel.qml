pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import qs.Config
import qs.Services.WM
import qs.Components

PanelWindow {
  id: root

  property bool active: false
  property var allItems: []
  property int cellHeight: 150
  property int cellPadding: 32
  property int cellWidth: 150
  property bool closeOnActivate: true
  property int contentMargin: 12
  property int contentSpacing: 8
  property int currentIndex: -1
  property Component delegateComponent: null
  property var filteredItems: []
  property var finder: null
  property var finderBuilder: null
  property alias footerContent: footerSlot.data
  property int footerSpacing: 8
  property alias gridView: itemGrid
  property alias headerContent: headerSlot.data
  property int headerSpacing: 8
  property var iconSelector: function (item) {
    return item?.icon || "";
  }
  property int itemImageSize: 72
  property var items: []
  property var labelSelector: function (item) {
    return item?.name || "";
  }
  property int maxResults: 200
  property string placeholderText: qsTr("Type to search")
  property var screenTarget: MonitorService ? MonitorService.effectiveMainScreen : null
  property alias searchInput: searchField
  property var searchSelector: function (item) {
    const label = root.callSelector(root.labelSelector, item) || "";
    const comment = item?.comment || "";
    return comment ? `${label} ${comment}` : label;
  }
  property bool showSearchField: true
  property int windowHeight: 471
  property int windowWidth: 741

  signal activated(var item)
  signal dismissed

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

  function clamp(v, lo, hi) {
    return Math.min(Math.max(v, lo), hi);
  }

  function close() {
    if (!root.active)
      return;
    root.active = false;
    root.currentIndex = -1;
    root.dismissed();
  }

  function ensureCurrentVisible() {
    if (root.currentIndex < 0)
      return;
    Qt.callLater(() => {
      if (itemGrid)
        itemGrid.positionViewAtIndex(root.currentIndex, GridView.Center);
    });
  }

  function ensureFinder(forceRebuild) {
    const normalized = toArray(items);
    const needs = forceRebuild || !root.finder || !root.arraysEqual(root.allItems, normalized);
    if (!needs)
      return;
    root.allItems = normalized.slice();
    const hasBuilder = typeof root.finderBuilder === "function";
    root.finder = hasBuilder ? root.buildFinder(root.allItems) : null;
    if (hasBuilder && !root.finder)
      console.warn("SearchGridPanel: FZF unavailable, using substring filter");
  }

  function gridStride() {
    return itemGrid ? itemGrid.gridColumns : 1;
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

  function isPointInsidePopup(item, x, y) {
    if (!item)
      return false;
    const local = item.mapFromItem(dismissArea, x, y);
    return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
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

  function open() {
    if (!root.active)
      root.active = true;
  }

  function releaseFocus() {
    if (root.showSearchField && searchField && searchField.activeFocus)
      searchField.focus = false;
    if (popupRect)
      popupRect.forceActiveFocus();
  }

  function resetAndFocus() {
    ensureFinder(true);
    searchField.text = "";
    updateFilter("", true);
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
    if (text.length > 0)
      root.currentIndex = 0;
    else if (root.currentIndex < 0 || root.currentIndex >= root.filteredItems.length)
      root.currentIndex = 0;
  }

  WlrLayershell.exclusiveZone: -1
  WlrLayershell.layer: WlrLayer.Overlay
  color: "transparent"
  focusable: active
  screen: screenTarget
  visible: active

  onActiveChanged: {
    if (root.active)
      root.resetAndFocus();
    else
      root.releaseFocus();
  }
  onItemsChanged: {
    ensureFinder(true);
    updateFilter(searchField.text, true);
  }

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }

  MouseArea {
    id: dismissArea

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    anchors.fill: parent

    onPressed: function (mouse) {
      if (root.isPointInsidePopup(popupRect, mouse.x, mouse.y)) {
        mouse.accepted = false;
        return;
      }
      root.close();
    }
  }

  Rectangle {
    id: popupRect

    anchors.centerIn: parent
    border.color: Theme.activeColor
    border.width: 1
    color: Theme.bgColor
    focus: true
    height: root.windowHeight
    radius: Theme.itemRadius
    width: root.windowWidth

    Keys.onPressed: event => {
      if (root.handleKeyEvent) {
        switch (event.key) {
        case Qt.Key_Escape:
        case Qt.Key_Down:
        case Qt.Key_Up:
        case Qt.Key_Left:
        case Qt.Key_Right:
        case Qt.Key_Return:
        case Qt.Key_Enter:
          root.handleKeyEvent(event);
          if (event.accepted)
            return;
        }
      }
      if (root.showSearchField && event.text && event.text.length > 0 && !(event.modifiers & ~Qt.ShiftModifier)) {
        searchField.forceActiveFocus();
        searchField.text += event.text;
        searchField.cursorPosition = searchField.text.length;
        event.accepted = true;
      }
    }

    ColumnLayout {
      id: contentColumn

      anchors.fill: parent
      anchors.margins: root.contentMargin
      spacing: root.contentSpacing

      Item {
        id: headerWrapper

        Layout.fillWidth: true
        Layout.preferredHeight: headerSlot.implicitHeight
        visible: headerSlot.children.length > 0

        Column {
          id: headerSlot

          anchors.fill: parent
          spacing: root.headerSpacing
        }
      }

      TextField {
        id: searchField

        Layout.fillWidth: true
        Layout.preferredHeight: root.showSearchField ? 32 : 0
        color: Theme.textActiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        leftPadding: 12
        placeholderText: root.placeholderText
        placeholderTextColor: Theme.textInactiveColor
        rightPadding: 12
        selectedTextColor: Theme.textContrast(Theme.activeColor)
        selectionColor: Theme.activeColor
        visible: root.showSearchField

        background: Rectangle {
          border.color: searchField.activeFocus ? Theme.activeColor : Theme.borderColor
          border.width: searchField.activeFocus ? 2 : 1
          color: Theme.bgColor
          radius: Theme.itemRadius
        }

        Keys.onPressed: event => root.handleKeyEvent(event)
        onActiveFocusChanged: if (activeFocus)
          selectAll()
        onTextChanged: root.updateFilter(searchField.text)
      }

      Item {
        id: gridContainer

        Layout.fillHeight: true
        Layout.fillWidth: true
        clip: true

        Component {
          id: defaultItemDelegate

          Item {
            id: itemDelegate

            property bool hovered: mouseArea.containsMouse
            required property int index
            required property var modelData
            readonly property string resolvedIcon: root.callSelector(root.iconSelector, itemDelegate.modelData) || ""
            readonly property string resolvedLabel: root.callSelector(root.labelSelector, itemDelegate.modelData) || ""
            readonly property bool selected: GridView.isCurrentItem

            height: GridView.view ? GridView.view.cellHeight : 0
            width: GridView.view ? GridView.view.cellWidth : (parent ? parent.width : 0)

            Rectangle {
              anchors.centerIn: parent
              color: itemDelegate.selected ? Theme.activeColor : Theme.onHoverColor
              height: Math.max(0, parent.height - root.cellPadding)
              opacity: itemDelegate.selected ? 0.3 : 0.18
              radius: Theme.itemRadius
              visible: itemDelegate.hovered || itemDelegate.selected
              width: Math.max(0, parent.width - root.cellPadding)

              Behavior on height {
                NumberAnimation {
                  duration: 150
                  easing.type: Easing.OutCubic
                }
              }
              Behavior on opacity {
                NumberAnimation {
                  duration: 150
                  easing.type: Easing.OutCubic
                }
              }
              Behavior on width {
                NumberAnimation {
                  duration: 150
                  easing.type: Easing.OutCubic
                }
              }
            }

            Column {
              anchors.centerIn: parent
              spacing: 10
              width: Math.max(0, parent.width - root.cellPadding)

              Image {
                anchors.horizontalCenter: parent.horizontalCenter
                fillMode: Image.PreserveAspectFit
                height: root.itemImageSize
                source: itemDelegate.resolvedIcon
                sourceSize: Qt.size(root.itemImageSize, root.itemImageSize)
                visible: source !== ""
                width: root.itemImageSize
              }

              OText {
                anchors.horizontalCenter: parent.horizontalCenter
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 1
                text: itemDelegate.resolvedLabel
                verticalAlignment: Text.AlignVCenter
                width: parent.width
                wrapMode: Text.NoWrap
              }
            }

            MouseArea {
              id: mouseArea

              acceptedButtons: Qt.LeftButton
              anchors.fill: parent
              hoverEnabled: true

              onClicked: function () {
                root.currentIndex = itemDelegate.index;
                root.activateEntry(itemDelegate.modelData);
              }
            }
          }
        }

        GridView {
          id: itemGrid

          readonly property int availableColumns: Math.max(1, Math.floor(maxWidth / root.cellWidth))
          readonly property int gridColumns: Math.max(1, Math.min(modelCount || 1, availableColumns))
          readonly property int gridRows: Math.max(1, Math.ceil((modelCount || 1) / gridColumns))
          readonly property real maxHeight: gridContainer.height
          readonly property real maxWidth: gridContainer.width
          readonly property int modelCount: root.filteredItems ? root.filteredItems.length : 0

          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          cellHeight: root.cellHeight
          cellWidth: root.cellWidth
          clip: true
          currentIndex: root.currentIndex
          delegate: root.delegateComponent ? root.delegateComponent : defaultItemDelegate
          flow: GridView.FlowLeftToRight
          height: Math.min(maxHeight, Math.max(root.cellHeight, gridRows * root.cellHeight))
          highlightMoveDuration: 200
          interactive: true
          model: root.filteredItems
          snapMode: GridView.SnapToRow
          width: Math.min(maxWidth, Math.max(root.cellWidth, gridColumns * root.cellWidth))
        }
      }

      Item {
        id: footerWrapper

        Layout.fillWidth: true
        Layout.preferredHeight: footerSlot.implicitHeight
        visible: footerSlot.children.length > 0

        Column {
          id: footerSlot

          anchors.fill: parent
          spacing: root.footerSpacing
        }
      }
    }
  }
}
