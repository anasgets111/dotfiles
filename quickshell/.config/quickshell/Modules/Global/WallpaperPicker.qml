pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Services.Core

SearchGridPanel {
  id: picker

  readonly property var fillModeOptions: (WallpaperService?.availableModes ?? []).map(m => ({
        label: {
          fill: qsTr("Fill"),
          fit: qsTr("Fit"),
          center: qsTr("Center"),
          stretch: qsTr("Stretch"),
          tile: qsTr("Tile")
        }[m] ?? m,
        value: m
      }))
  property bool loadingFromService: false

  // Derived options
  readonly property var monitorOptions: {
    const list = [
      {
        label: qsTr("All Monitors"),
        value: "all"
      }
    ];
    for (const m of WallpaperService?.monitors ?? [])
      if (m?.name)
        list.push({
          label: m.name,
          value: m.name
        });
    return list;
  }

  // Mutable state
  property string selectedMonitor: "all"
  property var stagedModes: ({})
  property string stagedTransition: "disc"
  property var stagedWallpapers: ({})
  readonly property var themeOptions: {
    const themes = Settings?.availableThemes ?? [];
    const current = Settings?.data?.themeName ?? "";
    const list = current && !themes.includes(current) ? themes.concat([current]) : themes;
    return list.map(name => ({
          label: name,
          value: name
        }));
  }
  readonly property var transitionOptions: (WallpaperService?.availableTransitions ?? []).map(t => ({
        label: {
          fade: qsTr("Fade"),
          wipe: qsTr("Wipe"),
          disc: qsTr("Disc"),
          stripes: qsTr("Stripes"),
          portal: qsTr("Portal")
        }[t] ?? t,
        value: t
      }))

  signal applyRequested
  signal cancelRequested

  function applyChanges() {
    if (!WallpaperService?.ready)
      return;
    const applyToAll = selectedMonitor === "all" && stagedWallpapers.all;
    for (const {
      value: name
    } of monitorOptions) {
      if (name === "all")
        continue;
      const mode = stagedModes[name] ?? stagedModes.all ?? WallpaperService.defaultMode;
      const wallpaper = applyToAll ? stagedWallpapers.all : (stagedWallpapers[name] ?? "");
      if (mode)
        WallpaperService.setModePref(name, mode);
      if (wallpaper)
        WallpaperService.setWallpaper(name, wallpaper);
    }
    WallpaperService.setWallpaperTransition(stagedTransition);
    loadFromService(selectedMonitor);
    applyRequested();
  }

  function loadFromService(preferredMonitor) {
    loadingFromService = true;
    const monitors = WallpaperService?.monitors ?? [];
    const defaultMode = WallpaperService?.defaultMode ?? "fill";
    const modes = {
      all: defaultMode
    };
    const wallpapers = {
      all: ""
    };

    for (const {
      name
    } of monitors) {
      if (!name)
        continue;
      modes[name] = WallpaperService?.ready ? WallpaperService.wallpaperMode(name) : defaultMode;
      wallpapers[name] = WallpaperService?.ready ? WallpaperService.wallpaperPath(name) : "";
    }

    stagedModes = modes;
    stagedWallpapers = wallpapers;
    stagedTransition = WallpaperService?.wallpaperTransition ?? "disc";

    const names = monitors.map(m => m?.name).filter(Boolean);
    const pref = preferredMonitor ?? selectedMonitor;
    selectedMonitor = (pref !== "all" && names.includes(pref)) ? pref : "all";
    updateSelection();
    loadingFromService = false;
  }

  function stageWallpaper(entry) {
    if (!entry?.path)
      return;
    const key = selectedMonitor === "all" ? "all" : selectedMonitor;
    stagedWallpapers = Object.assign({}, stagedWallpapers, {
      [key]: entry.path
    });
    updateSelection();
  }

  function updateSelection() {
    const items = WallpaperService?.wallpaperFiles ?? [];
    const expected = stagedWallpapers[selectedMonitor] || stagedWallpapers.all || "";
    if (!items.length || !expected)
      return;
    const idx = items.findIndex(e => e?.path === expected);
    if (idx >= 0)
      currentIndex = idx;
  }

  cellHeight: 150
  cellPadding: Theme.spacingXl
  cellWidth: 240
  closeOnActivate: false
  contentMargin: Theme.spacingLg
  contentSpacing: Theme.spacingMd
  delegateComponent: wallpaperDelegate
  iconSelector: entry => entry?.previewSource ?? ""
  itemImageSize: 265
  items: WallpaperService?.wallpaperFiles ?? []
  labelSelector: entry => entry?.displayName ?? ""
  placeholderText: qsTr("Search wallpapers…")
  searchSelector: labelSelector
  windowHeight: 520
  windowWidth: 900

  footerContent: [
    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingSm

      OButton {
        bgColor: Theme.inactiveColor
        text: qsTr("Cancel")

        onClicked: picker.cancelRequested()
      }

      Item {
        Layout.fillWidth: true
      }

      OButton {
        bgColor: Theme.activeColor
        text: qsTr("Apply")

        onClicked: picker.applyChanges()
      }
    }
  ]
  headerContent: [
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingSm

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingLg

        OInput {
          Layout.fillWidth: true
          Layout.minimumWidth: 280
          placeholderText: qsTr("Wallpaper folder path")
          text: WallpaperService?.wallpaperFolder ?? ""

          onInputFinished: if (text !== (WallpaperService?.wallpaperFolder ?? ""))
            WallpaperService.setWallpaperFolder(text)
        }

        OComboBox {
          Layout.preferredWidth: 200
          currentIndex: Math.max(0, picker.monitorOptions.findIndex(o => o.value === picker.selectedMonitor))
          model: picker.monitorOptions
          textRole: "label"
          valueRole: "value"

          onActivated: idx => picker.selectedMonitor = picker.monitorOptions[idx]?.value ?? "all"
        }

        RowLayout {
          spacing: Theme.spacingSm

          OComboBox {
            readonly property string currentMode: picker.stagedModes[picker.selectedMonitor] ?? picker.stagedModes.all ?? "fill"

            Layout.preferredWidth: 140
            currentIndex: Math.max(0, picker.fillModeOptions.findIndex(o => o.value === currentMode))
            model: picker.fillModeOptions
            textRole: "label"
            valueRole: "value"

            onActivated: idx => {
              const mode = picker.fillModeOptions[idx]?.value;
              if (!mode)
                return;
              const modes = Object.assign({}, picker.stagedModes);
              if (picker.selectedMonitor === "all") {
                modes.all = mode;
                for (const {
                  value
                } of picker.monitorOptions)
                  if (value !== "all")
                    modes[value] = mode;
              } else {
                modes[picker.selectedMonitor] = mode;
              }
              picker.stagedModes = modes;
            }
          }

          OComboBox {
            Layout.preferredWidth: 150
            currentIndex: Math.max(0, picker.transitionOptions.findIndex(o => o.value === picker.stagedTransition))
            model: picker.transitionOptions
            textRole: "label"
            valueRole: "value"

            onActivated: idx => picker.stagedTransition = picker.transitionOptions[idx]?.value ?? "disc"
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Item {
          Layout.fillWidth: true
        }

        OComboBox {
          Layout.preferredWidth: 180
          currentIndex: Math.max(0, picker.themeOptions.findIndex(o => o.value === (Settings?.data?.themeName ?? "")))
          model: picker.themeOptions
          textRole: "label"
          valueRole: "value"

          onActivated: idx => Settings?.setThemeName(picker.themeOptions[idx]?.value ?? "")
        }

        RowLayout {
          spacing: Theme.spacingXs

          OText {
            muted: true
            text: qsTr("Dark mode")
          }

          OToggle {
            Layout.alignment: Qt.AlignVCenter
            checked: (Settings?.data?.themeMode ?? "dark") === "dark"

            onToggled: checked => Settings?.setThemeMode(checked ? "dark" : "light")
          }
        }
      }
    }
  ]

  Component.onCompleted: if (gridView)
    gridView.cacheBuffer = 300
  onActivated: entry => stageWallpaper(entry)
  onActiveChanged: if (active)
    loadFromService()
  onMonitorOptionsChanged: if (!monitorOptions.some(o => o.value === selectedMonitor))
    selectedMonitor = "all"
  onSelectedMonitorChanged: if (!loadingFromService)
    updateSelection()

  Connections {
    function onWallpaperFilesChanged() {
      Qt.callLater(picker.updateSelection);
    }

    target: WallpaperService
  }

  Component {
    id: wallpaperDelegate

    Item {
      id: tile

      readonly property bool hovered: mouse.containsMouse
      required property int index
      required property var modelData
      readonly property bool selected: GridView.isCurrentItem

      height: GridView.view?.cellHeight ?? 0
      width: GridView.view?.cellWidth ?? 0

      Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.spacingSm
        border.color: tile.selected ? Theme.activeColor : (tile.hovered ? Theme.onHoverColor : Theme.borderColor)
        border.width: 1
        clip: true
        color: Qt.rgba(0, 0, 0, 0.18)
        radius: Theme.itemRadius

        Image {
          anchors.fill: parent
          asynchronous: true
          cache: false
          fillMode: Image.PreserveAspectCrop
          source: tile.modelData?.previewSource ?? ""
          sourceSize: Qt.size(240, 150)
        }

        Rectangle {
          color: Qt.rgba(0, 0, 0, 0.45)
          height: Math.max(36, parent.height * 0.18)
          visible: tile.modelData?.displayName

          anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
          }

          OText {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingMd
            anchors.rightMargin: Theme.spacingMd
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
            maximumLineCount: 1
            text: tile.modelData?.displayName ?? ""
            verticalAlignment: Text.AlignVCenter
          }
        }

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(1, 1, 1, tile.selected ? 0.18 : 0.10)
          visible: tile.selected || tile.hovered
        }
      }

      MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true

        onClicked: {
          picker.currentIndex = tile.index;
          picker.activateEntry(tile.modelData);
        }
      }
    }
  }
}
