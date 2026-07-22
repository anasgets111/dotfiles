pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.Config
import qs.Modules.Global.Launcher
import qs.Services.Utils

OModal {
  id: root

  property real _lastPointerX: -1
  property real _lastPointerY: -1
  readonly property var allApps: Array.from(DesktopEntries.applications?.values ?? [])
  property int currentIndex: 0
  property var filteredApps: []
  property var finder: null
  readonly property bool hasSpecial: LauncherService.hasSpecial
  property bool hoverSelectionArmed: false
  readonly property int maxResults: 200
  readonly property int selectedAppIndex: specialSelected || filteredApps.length === 0 ? -1 : Math.max(0, Math.min(currentIndex - (hasSpecial ? 1 : 0), filteredApps.length - 1))
  readonly property bool specialSelected: hasSpecial && currentIndex === 0
  readonly property int totalRows: filteredApps.length + (hasSpecial ? 1 : 0)

  function activateCurrent(): void {
    if (specialSelected) {
      LauncherService.activateSpecial();
      close();
    } else if (selectedAppIndex >= 0) {
      launch(filteredApps[selectedAppIndex]);
    }
  }
  function ensureFinder(force: bool): void {
    if (!force && finder)
      return;
    finder = Fzf.createFinder(allApps, {
      selector: entry => [entry?.name || "", entry?.comment || ""].filter(Boolean).join(" "),
      limit: maxResults,
      tiebreakers: [Fzf.byStartAsc, Fzf.byLengthAsc]
    });
  }
  function handlePointerMove(row: Item, position: point, targetIndex: int): void {
    const mapped = row.mapToItem(root, position.x, position.y);
    if (_lastPointerX >= 0 && (mapped.x !== _lastPointerX || mapped.y !== _lastPointerY))
      hoverSelectionArmed = true;
    _lastPointerX = mapped.x;
    _lastPointerY = mapped.y;
    if (hoverSelectionArmed)
      currentIndex = targetIndex;
  }
  function handleSearchKey(event: var): void {
    if (event.key === Qt.Key_Escape) {
      if (search.text !== "")
        search.clear();
      else
        close();
      event.accepted = true;
    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
      move(1);
      event.accepted = true;
    } else if (event.key === Qt.Key_Up) {
      move(-1);
      event.accepted = true;
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      activateCurrent();
      event.accepted = true;
    }
  }
  function launch(entry: var): void {
    const id = String(entry?.id || "").replace(/\.desktop$/, "");
    if (!id)
      return;
    Quickshell.execDetached(["gtk-launch", id]);
    close();
  }
  function move(delta: int): void {
    if (totalRows <= 0)
      return;
    hoverSelectionArmed = false;
    currentIndex = Math.max(0, Math.min(currentIndex + delta, totalRows - 1));
    if (!specialSelected && selectedAppIndex >= 0)
      appList.positionViewAtIndex(selectedAppIndex, ListView.Contain);
  }
  function processInput(text: string): void {
    ensureFinder(false);
    const query = text.trim();
    const results = query ? finder.find(query) : [];
    filteredApps = query ? results.map(result => result.item) : allApps.slice(0, maxResults);
    LauncherService.route(query, filteredApps.length, results[0]?.score ?? 0);
    hoverSelectionArmed = false;
    currentIndex = 0;
    appList.positionViewAtBeginning();
  }

  searchInput: search

  onActiveChanged: if (active) {
    LauncherService.refresh();
    hoverSelectionArmed = false;
    _lastPointerX = -1;
    _lastPointerY = -1;
    ensureFinder(true);
    processInput("");
  }
  onAllAppsChanged: if (active) {
    ensureFinder(true);
    processInput(search.text);
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Theme.spacingLg
    spacing: Theme.spacingSm

    OInput {
      id: search

      Layout.fillWidth: true
      placeholderText: qsTr("Search apps, calculate, convert currency…")
      size: "xl"

      onInputChanged: root.processInput(text)
      onKeyPressed: event => root.handleSearchKey(event)
    }
    PanelCard {
      Layout.fillHeight: true
      Layout.fillWidth: true

      ColumnLayout {
        height: parent?.height ?? 0
        spacing: Theme.spacingXs
        width: parent?.width ?? 0

        PanelRow {
          id: specialRow

          Layout.fillWidth: true
          Layout.preferredHeight: Theme.launcherSpecialRowHeight
          selected: root.specialSelected
          subtitle: LauncherService.activeProvider?.rowSubtitle ?? ""
          title: LauncherService.activeProvider?.rowTitle ?? ""
          visible: root.hasSpecial

          badges: [
            InfoBadge {
              text: LauncherService.activeProvider?.rowBadge ?? ""
            },
            OText {
              color: Theme.textInactiveColor
              size: "xs"
              text: LauncherService.activeProvider?.rowHint ?? ""
            }
          ]
          leading: [
            OText {
              anchors.centerIn: parent
              font.family: LauncherService.activeProvider?.rowIconIsText ? Theme.fontFamily : Theme.iconFontFamily
              font.pixelSize: Theme.launcherIconSize
              text: LauncherService.activeProvider?.rowIcon ?? ""
            }
          ]

          onClicked: {
            root.currentIndex = 0;
            root.activateCurrent();
          }
          onPointerMoved: position => root.handlePointerMove(specialRow, position, 0)
        }
        ListView {
          id: appList

          Layout.fillHeight: true
          Layout.fillWidth: true
          boundsBehavior: Flickable.StopAtBounds
          clip: true
          model: root.filteredApps
          spacing: Theme.spacingXs

          delegate: PanelRow {
            id: appRow

            readonly property int composedIndex: root.hasSpecial ? index + 1 : index
            required property int index
            required property var modelData

            height: Theme.launcherRowHeight
            selected: composedIndex === root.currentIndex
            subtitle: modelData?.comment || ""
            title: modelData?.name || ""
            width: ListView.view.width

            leading: [
              Image {
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                height: Theme.launcherIconSize
                scale: appRow.selected ? 1.3 : 1
                source: Utils.resolveIconSource(appRow.modelData?.id || appRow.modelData?.name || "", appRow.modelData?.icon, "application-x-executable")
                sourceSize: Qt.size(width, height)
                width: Theme.launcherIconSize

                Behavior on scale {
                  NumberAnimation {
                    duration: Theme.animationFast
                    easing.type: Easing.OutCubic
                  }
                }
              }
            ]

            onClicked: root.launch(modelData)
            onPointerMoved: position => root.handlePointerMove(appRow, position, composedIndex)
          }
        }
        OText {
          Layout.alignment: Qt.AlignHCenter
          color: Theme.textInactiveColor
          text: search.text.trim().length > 0 && root.totalRows === 0 ? qsTr("No results found") : ""
        }
      }
    }
  }
}
