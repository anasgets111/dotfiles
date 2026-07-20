pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Components
import qs.Config
import qs.Services.Core

SearchGridPanel {
  id: picker

  readonly property int activeFillModeIndex: {
    const mode = stagedModes[selectedMonitor] ?? stagedModes.all ?? "fill";
    const idx = fillModeOptions.findIndex(o => o.value === mode);
    return Math.max(0, idx);
  }
  readonly property int activeTransitionIndex: {
    const idx = transitionOptions.findIndex(o => o.value === stagedTransition);
    return Math.max(0, idx);
  }
  readonly property string currentWallpaperPath: {
    if (!WallpaperService?.ready)
      return "";
    if (selectedMonitor !== "all")
      return WallpaperService.wallpaperPath(selectedMonitor);
    const paths = (WallpaperService.monitors ?? []).map(m => m?.name ? WallpaperService.wallpaperPath(m.name) : "").filter(Boolean);
    return paths.length > 0 && paths.length === (WallpaperService.monitors ?? []).length && paths.every(path => path === paths[0]) ? paths[0] : "";
  }
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
  readonly property var monitorOptions: {
    const list = [
      {
        label: qsTr("All"),
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
  readonly property bool pendingChanges: {
    if (!WallpaperService?.ready)
      return false;
    if (stagedTransition !== WallpaperService.wallpaperTransition)
      return true;
    const applyToAll = selectedMonitor === "all" && stagedWallpapers.all;
    for (const monitor of WallpaperService.monitors ?? []) {
      if (!monitor?.name)
        continue;
      const mode = stagedModes[monitor.name] ?? stagedModes.all ?? WallpaperService.defaultMode;
      if (mode !== WallpaperService.wallpaperMode(monitor.name))
        return true;
      const wallpaper = applyToAll ? stagedWallpapers.all : (stagedWallpapers[monitor.name] ?? "");
      if (wallpaper && wallpaper !== WallpaperService.wallpaperPath(monitor.name))
        return true;
    }
    return false;
  }
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
      name
    } of WallpaperService.monitors) {
      if (!name)
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
    const monitorWallpapers = monitors.map(m => m?.name ? wallpapers[m.name] : "").filter(Boolean);
    wallpapers.all = monitorWallpapers.length > 0 && monitorWallpapers.length === monitors.length && monitorWallpapers.every(path => path === monitorWallpapers[0]) ? monitorWallpapers[0] : "";
    stagedModes = modes;
    stagedWallpapers = wallpapers;
    stagedTransition = WallpaperService?.wallpaperTransition ?? "disc";
    const names = monitors.map(m => m?.name).filter(Boolean);
    const pref = preferredMonitor ?? selectedMonitor;
    selectedMonitor = (pref !== "all" && names.includes(pref)) ? pref : "all";
    updateSelection();
    loadingFromService = false;
  }
  function stageFillMode(mode) {
    if (selectedMonitor === "all") {
      const monitorNames = monitorOptions.map(option => option.value).filter(value => value !== "all");
      if (stagedModes.all === mode && monitorNames.every(name => stagedModes[name] === mode))
        return;
    } else if ((stagedModes[selectedMonitor] ?? stagedModes.all ?? WallpaperService?.defaultMode) === mode) {
      return;
    }
    const modes = Object.assign({}, stagedModes);
    if (selectedMonitor === "all") {
      modes.all = mode;
      for (const {
        value
      } of monitorOptions)
        if (value !== "all")
          modes[value] = mode;
    } else {
      modes[selectedMonitor] = mode;
    }
    stagedModes = modes;
  }
  function stageTransition(transition) {
    if (stagedTransition === transition)
      return;
    stagedTransition = transition;
  }
  function stageWallpaper(entry) {
    if (!entry?.path)
      return;
    const target = selectedMonitor === "all" ? "all" : selectedMonitor;
    if ((stagedWallpapers[target] ?? "") === entry.path)
      return;
    stagedWallpapers = Object.assign({}, stagedWallpapers, {
      [target]: entry.path
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

  cellHeight: Math.round(cellWidth * 9 / 16)
  cellWidth: 230
  closeOnActivate: false
  contentMargin: Theme.spacingLg
  contentSpacing: Theme.spacingMd
  delegateComponent: wallpaperDelegate
  items: WallpaperService?.wallpaperFiles ?? []
  labelSelector: entry => entry?.displayName ?? ""
  placeholderText: qsTr("Search wallpapers…")
  popupBorderColor: Theme.borderLight
  popupRadius: Theme.radiusXl
  scrimColor: Theme.withOpacity(Theme.bgOverlay, 0.35)
  searchSelector: labelSelector
  windowHeight: 650
  windowWidth: 960

  footerContent: [
    RowLayout {
      spacing: Theme.spacingMd
      width: parent?.width ?? 0

      OText {
        color: Theme.textContrast(Theme.bgColor)
        font.pixelSize: Theme.fontSm
        opacity: picker.pendingChanges ? 0.9 : 0.65
        text: picker.pendingChanges ? qsTr("Changes are ready to apply") : qsTr("No pending changes")
      }
      Item {
        Layout.fillWidth: true
      }
      OButton {
        Layout.preferredWidth: 110
        size: "lg"
        text: qsTr("Cancel")
        variant: "secondary"

        onClicked: picker.cancelRequested()
      }
      OButton {
        Layout.preferredWidth: 126
        isEnabled: picker.pendingChanges
        size: "lg"
        text: qsTr("Apply")

        onClicked: picker.applyChanges()
      }
    }
  ]
  headerContent: [
    ColumnLayout {
      spacing: Theme.spacingMd
      width: parent?.width ?? 0

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingMd

        Rectangle {
          Layout.preferredHeight: Theme.controlHeightXl
          Layout.preferredWidth: Theme.controlHeightXl
          color: Theme.activeSubtle
          radius: Theme.radiusLg

          OText {
            anchors.centerIn: parent
            color: Theme.activeColor
            font.pixelSize: Theme.fontXl
            text: "󰸉"
          }
        }
        ColumnLayout {
          spacing: Theme.spacingXs

          OText {
            bold: true
            color: Theme.textContrast(Theme.bgColor)
            font.pixelSize: Theme.fontXxl
            text: qsTr("Wallpaper")
          }
          OText {
            color: Theme.textContrast(Theme.bgColor)
            font.pixelSize: Theme.fontSm
            opacity: 0.72
            text: picker.selectedMonitor === "all" ? qsTr("Choose a wallpaper for all displays") : qsTr("Choose a wallpaper for %1").arg(picker.selectedMonitor)
          }
        }
        Item {
          Layout.fillWidth: true
        }
        Rectangle {
          border.color: Theme.borderSubtle
          border.width: Theme.borderWidthThin
          color: Theme.withOpacity(Theme.bgColor, 0.45)
          implicitHeight: Theme.controlHeightLg
          implicitWidth: monitorChips.implicitWidth + Theme.spacingSm
          radius: Theme.radiusFull

          Row {
            id: monitorChips

            anchors.centerIn: parent
            spacing: 2

            Repeater {
              model: picker.monitorOptions

              delegate: OButton {
                required property int index
                readonly property bool isActive: picker.selectedMonitor === modelData.value
                required property var modelData

                bgColor: isActive ? Theme.activeColor : "transparent"
                height: Theme.controlHeightMd
                radius: Theme.radiusFull
                size: "sm"
                text: modelData.label
                textColor: isActive ? Theme.textContrast(bgColor) : Theme.withOpacity(Theme.textContrast(Theme.bgColor), 0.72)
                width: Math.max(58, implicitWidth)

                onClicked: picker.selectedMonitor = modelData.value
              }
            }
          }
        }
      }
      Rectangle {
        Layout.fillWidth: true
        border.color: Theme.borderSubtle
        border.width: Theme.borderWidthThin
        color: Theme.withOpacity(Theme.bgElevated, 0.35)
        implicitHeight: settingsLayout.implicitHeight + Theme.spacingLg * 2
        radius: Theme.radiusLg

        ColumnLayout {
          id: settingsLayout

          anchors.fill: parent
          anchors.margins: Theme.spacingLg
          spacing: Theme.spacingMd

          RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            OText {
              color: Theme.textContrast(Theme.bgElevated)
              font.pixelSize: Theme.fontSm
              opacity: 0.75
              text: "󰉋  " + qsTr("Library")
            }
            OInput {
              Layout.fillWidth: true
              size: "md"
              text: WallpaperService?.wallpaperFolder ?? ""

              onInputFinished: if (text !== (WallpaperService?.wallpaperFolder ?? ""))
                WallpaperService.setWallpaperFolder(text)
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd

            OText {
              color: Theme.textContrast(Theme.bgElevated)
              font.pixelSize: Theme.fontSm
              opacity: 0.75
              text: qsTr("Display mode")
            }
            OComboBox {
              Layout.preferredWidth: 110
              currentIndex: picker.activeFillModeIndex
              model: picker.fillModeOptions
              textRole: "label"
              valueRole: "value"

              onActivated: index => picker.stageFillMode(picker.fillModeOptions[index]?.value ?? "fill")
            }
            OText {
              color: Theme.textContrast(Theme.bgElevated)
              font.pixelSize: Theme.fontSm
              opacity: 0.75
              text: qsTr("Transition")
            }
            OComboBox {
              Layout.preferredWidth: 120
              currentIndex: picker.activeTransitionIndex
              model: picker.transitionOptions
              textRole: "label"
              valueRole: "value"

              onActivated: index => picker.stageTransition(picker.transitionOptions[index]?.value ?? "disc")
            }
            Item {
              Layout.fillWidth: true
            }
            OText {
              color: Theme.textContrast(Theme.bgElevated)
              font.pixelSize: Theme.fontSm
              opacity: 0.75
              text: qsTr("Theme")
            }
            OComboBox {
              Layout.preferredWidth: 150
              currentIndex: Math.max(0, picker.themeOptions.findIndex(o => o.value === (Settings?.data?.themeName ?? "")))
              model: picker.themeOptions
              textRole: "label"
              valueRole: "value"

              onActivated: index => Settings?.setThemeName(picker.themeOptions[index]?.value ?? "")
            }
            OText {
              color: Theme.textContrast(Theme.bgElevated)
              font.pixelSize: Theme.fontSm
              opacity: 0.75
              text: qsTr("Dark")
            }
            OToggle {
              checked: (Settings?.data?.themeMode ?? "dark") === "dark"
              size: "lg"

              onToggled: checked => Settings?.setThemeMode(checked ? "dark" : "light")
            }
          }
        }
      }
    }
  ]

  // ── Connections ──────────────────────────────────────────────────
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

  // ── Wallpaper tile — gallery style ──────────────────────────────
  Component {
    id: wallpaperDelegate

    Item {
      id: tile

      readonly property bool currentWallpaper: picker.currentWallpaperPath !== "" && modelData?.path === picker.currentWallpaperPath
      readonly property bool hovered: mouse.containsMouse
      required property int index
      required property var modelData
      readonly property bool selected: GridView.isCurrentItem

      height: GridView.view?.cellHeight ?? 0
      scale: hovered && !selected ? 1.03 : 1.0
      width: GridView.view?.cellWidth ?? 0

      Behavior on scale {
        NumberAnimation {
          duration: 150
          easing.type: Easing.OutCubic
        }
      }

      // Selection ring
      Rectangle {
        border.color: Theme.activeColor
        border.width: 3
        color: "transparent"
        opacity: tile.selected ? 1 : 0
        radius: card.radius + 3

        Behavior on opacity {
          NumberAnimation {
            duration: 180
          }
        }

        anchors {
          fill: card
          margins: -3
        }
      }
      ClippingRectangle {
        id: card

        color: Theme.withOpacity(Theme.bgElevated, 0.35)
        radius: Theme.radiusLg

        anchors {
          fill: parent
          margins: 5
        }
        Image {
          anchors.fill: parent
          asynchronous: true
          cache: false
          fillMode: Image.PreserveAspectCrop
          source: tile.modelData?.previewSource ?? ""
          sourceSize: Qt.size(230, 130)
        }

        // Hover / selected overlay
        Rectangle {
          anchors.fill: parent
          color: Theme.withOpacity(Theme.shadowColorStrong, tile.selected ? 0.4 : tile.hovered ? 0.22 : 0)

          Behavior on color {
            ColorAnimation {
              duration: 130
            }
          }
        }
        Rectangle {
          color: Theme.activeColor
          height: 20
          radius: Theme.radiusFull
          visible: tile.currentWallpaper
          width: 20

          anchors {
            left: parent.left
            leftMargin: 8
            top: parent.top
            topMargin: 8
          }
          OText {
            anchors.centerIn: parent
            color: Theme.textContrast(parent.color)
            font.bold: true
            font.pixelSize: 12
            text: "󰄬"
          }
        }

        // Name label fades in on hover / select
        Rectangle {
          color: Theme.withOpacity(Theme.shadowColorStrong, 0.82)
          height: 32
          opacity: tile.hovered || tile.selected ? 1 : 0

          Behavior on opacity {
            NumberAnimation {
              duration: 150
            }
          }

          anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
          }
          OText {
            color: Theme.textContrast(parent.color)
            elide: Text.ElideRight
            font.bold: true
            font.pixelSize: 11
            horizontalAlignment: Text.AlignLeft
            maximumLineCount: 1
            text: tile.modelData?.displayName ?? ""
            verticalAlignment: Text.AlignVCenter

            anchors {
              fill: parent
              leftMargin: 10
              rightMargin: 10
            }
          }
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
