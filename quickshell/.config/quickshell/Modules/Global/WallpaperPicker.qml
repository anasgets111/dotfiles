pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Components
import qs.Config
import qs.Services.Core

OModal {
  id: root

  readonly property string currentMode: {
    if (selectedMonitor !== "all")
      return WallpaperService.wallpaperMode(selectedMonitor);
    const modes = targetMonitorNames.map(name => WallpaperService.wallpaperMode(name));
    return modes.length === 0 ? WallpaperService.defaultMode : modes.every(mode => mode === modes[0]) ? modes[0] : "";
  }
  readonly property string currentWallpaperPath: {
    if (selectedMonitor !== "all")
      return WallpaperService.wallpaperPath(selectedMonitor);
    const paths = (WallpaperService.monitors ?? []).filter(monitor => monitor?.name).map(monitor => WallpaperService.wallpaperPath(monitor.name));
    return paths.length > 0 && paths.every(path => path === paths[0]) ? paths[0] : "";
  }
  readonly property var fillModeOptions: (WallpaperService.availableModes ?? []).map(mode => ({
        label: ({
            fill: qsTr("Fill"),
            fit: qsTr("Fit"),
            center: qsTr("Center"),
            stretch: qsTr("Stretch"),
            tile: qsTr("Tile")
          })[mode] ?? mode,
        value: mode
      }))
  readonly property var filteredWallpapers: {
    const query = search.text.trim().toLowerCase();
    const items = WallpaperService.wallpaperFiles ?? [];
    return query ? items.filter(entry => String(entry?.displayName || "").toLowerCase().includes(query)) : items;
  }
  readonly property var monitorOptions: [
    {
      label: qsTr("All displays"),
      value: "all"
    }
  ].concat((WallpaperService.monitors ?? []).filter(monitor => monitor?.name).map(monitor => ({
        label: monitor.name,
        value: monitor.name
      })))
  property string selectedMonitor: "all"
  readonly property var targetMonitorNames: selectedMonitor === "all" ? (WallpaperService.monitors ?? []).map(monitor => monitor?.name).filter(Boolean) : [selectedMonitor]
  readonly property var transitionOptions: (WallpaperService.availableTransitions ?? []).map(transition => ({
        label: ({
            fade: qsTr("Fade"),
            wipe: qsTr("Wipe"),
            disc: qsTr("Disc"),
            stripes: qsTr("Stripes"),
            portal: qsTr("Portal")
          })[transition] ?? transition,
        value: transition
      }))

  function applyWallpaper(entry: var): void {
    if (!entry?.path)
      return;
    for (const monitor of targetMonitorNames)
      WallpaperService.setWallpaper(monitor, entry.path);
  }
  function handleSearchKey(event: var): void {
    const columns = Math.max(1, Math.floor(grid.width / grid.cellWidth));
    const delta = event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : event.key === Qt.Key_Up ? -columns : event.key === Qt.Key_Down ? columns : 0;
    if (delta && filteredWallpapers.length) {
      grid.currentIndex = Math.max(0, Math.min(grid.currentIndex + delta, filteredWallpapers.length - 1));
      grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
      applyWallpaper(filteredWallpapers[grid.currentIndex]);
    else if (event.key === Qt.Key_Escape) {
      if (search.text !== "")
        search.clear();
      else
        close();
    } else
      return;
    event.accepted = true;
  }
  function positionSelection(index: int): void {
    Qt.callLater(() => {
      grid.forceLayout();
      if (index < grid.count)
        grid.positionViewAtIndex(index, GridView.Beginning);
    });
  }
  function updateSelection(): void {
    const index = filteredWallpapers.findIndex(entry => entry?.path === currentWallpaperPath);
    grid.currentIndex = Math.max(0, index);
    positionSelection(grid.currentIndex);
  }

  preferredHeight: Theme.wallpaperModalHeight
  preferredWidth: Theme.wallpaperModalWidth
  searchInput: search

  onActiveChanged: if (active)
    updateSelection()
  onFilteredWallpapersChanged: {
    if (!active)
      return;
    if (search.text.trim() === "") {
      updateSelection();
      return;
    }
    grid.currentIndex = 0;
    positionSelection(0);
  }
  onMonitorOptionsChanged: if (!monitorOptions.some(option => option.value === selectedMonitor))
    selectedMonitor = "all"
  onSelectedMonitorChanged: updateSelection()

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Theme.spacingLg
    spacing: Theme.spacingMd

    OInput {
      id: search

      Layout.fillWidth: true
      placeholderText: qsTr("Search wallpapers…")

      onKeyPressed: event => root.handleSearchKey(event)
    }
    RowLayout {
      Layout.fillHeight: true
      Layout.fillWidth: true
      spacing: Theme.spacingMd

      PanelCard {
        Layout.fillHeight: true
        Layout.fillWidth: true

        GridView {
          id: grid

          anchors.fill: parent
          boundsBehavior: Flickable.StopAtBounds
          cellHeight: Math.round(cellWidth * 9 / 16)
          cellWidth: Theme.wallpaperTileWidth
          clip: true
          highlightFollowsCurrentItem: false
          model: root.filteredWallpapers

          delegate: Item {
            id: tile

            readonly property bool applied: modelData?.path === root.currentWallpaperPath
            required property int index
            required property var modelData
            readonly property bool selected: GridView.isCurrentItem

            height: GridView.view.cellHeight
            width: GridView.view.cellWidth

            ClippingRectangle {
              anchors.fill: parent
              anchors.margins: Theme.spacingXs
              border.color: tile.selected ? Theme.activeColor : Theme.glassBorderColor
              border.width: tile.selected ? Theme.borderWidthMedium : Theme.borderWidthThin
              color: Theme.glassContentColor
              radius: Theme.radiusLg

              Image {
                anchors.fill: parent
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                scale: tileMouse.containsMouse ? 1.04 : 1
                source: tile.modelData?.previewSource ?? ""
                sourceSize: Qt.size(tile.width, tile.height)

                Behavior on scale {
                  NumberAnimation {
                    duration: Theme.animationFast
                    easing.type: Easing.OutCubic
                  }
                }

                onStatusChanged: if (status === Image.Error)
                  source = tile.modelData?.path ?? ""
              }
              Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                color: Theme.shadowColorStrong
                height: Theme.controlHeightMd

                OText {
                  anchors.centerIn: parent
                  elide: Text.ElideRight
                  text: tile.modelData?.displayName ?? ""
                  width: parent.width - Theme.spacingSm * 2
                }
              }
              MouseArea {
                id: tileMouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: {
                  grid.currentIndex = tile.index;
                  root.applyWallpaper(tile.modelData);
                }
              }
              Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingSm
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingSm
                color: Theme.activeColor
                height: Theme.controlHeightXs
                radius: Theme.radiusFull
                visible: tile.applied
                width: height

                OText {
                  anchors.centerIn: parent
                  color: Theme.textContrast(parent.color)
                  size: "xs"
                  text: "󰄬"
                }
              }
            }
          }
        }
        ColumnLayout {
          anchors.centerIn: parent
          spacing: Theme.spacingSm
          visible: root.filteredWallpapers.length === 0

          OSpinner {
            Layout.alignment: Qt.AlignHCenter
            running: !WallpaperService.wallpaperFilesReady
          }
          OText {
            Layout.alignment: Qt.AlignHCenter
            color: Theme.textInactiveColor
            text: WallpaperService.wallpaperFilesReady ? qsTr("No wallpapers found") : qsTr("Loading wallpapers…")
          }
        }
      }
      PanelCard {
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: Theme.wallpaperSidebarWidth

        ColumnLayout {
          spacing: Theme.spacingMd
          width: parent?.width ?? 0

          OText {
            bold: true
            font.pixelSize: Theme.fontLg
            text: qsTr("Wallpaper settings")
          }
          OText {
            color: Theme.textInactiveColor
            size: "xs"
            text: qsTr("Monitor")
          }
          OComboBox {
            Layout.fillWidth: true
            currentIndex: Math.max(0, root.monitorOptions.findIndex(option => option.value === root.selectedMonitor))
            model: root.monitorOptions
            textRole: "label"

            onActivated: index => root.selectedMonitor = root.monitorOptions[index]?.value ?? "all"
          }
          OText {
            color: Theme.textInactiveColor
            size: "xs"
            text: qsTr("Fill mode")
          }
          OComboBox {
            Layout.fillWidth: true
            currentIndex: root.fillModeOptions.findIndex(option => option.value === root.currentMode)
            displayText: currentIndex < 0 ? qsTr("Mixed") : currentText
            model: root.fillModeOptions
            textRole: "label"

            onActivated: index => {
              for (const monitor of root.targetMonitorNames)
                WallpaperService.setModePref(monitor, root.fillModeOptions[index]?.value ?? "fill");
            }
          }
          OText {
            color: Theme.textInactiveColor
            size: "xs"
            text: qsTr("Transition")
          }
          OComboBox {
            Layout.fillWidth: true
            currentIndex: Math.max(0, root.transitionOptions.findIndex(option => option.value === WallpaperService.wallpaperTransition))
            model: root.transitionOptions
            textRole: "label"

            onActivated: index => WallpaperService.setWallpaperTransition(root.transitionOptions[index]?.value ?? "disc")
          }
          OText {
            color: Theme.textInactiveColor
            size: "xs"
            text: qsTr("Theme")
          }
          OComboBox {
            Layout.fillWidth: true
            currentIndex: Math.max(0, Settings.availableThemes.indexOf(Settings.data.themeName))
            model: Settings.availableThemes

            onActivated: index => Settings.setThemeName(Settings.availableThemes[index] ?? "")
          }
          RowLayout {
            Layout.fillWidth: true

            OText {
              Layout.fillWidth: true
              color: Theme.textInactiveColor
              size: "xs"
              text: qsTr("Dark mode")
            }
            OToggle {
              checked: Settings.data.themeMode === "dark"

              onToggled: checked => Settings.setThemeMode(checked ? "dark" : "light")
            }
          }
        }
      }
    }
  }
}
