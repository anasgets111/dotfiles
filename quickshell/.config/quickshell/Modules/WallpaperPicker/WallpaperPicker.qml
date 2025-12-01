pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Components
import qs.Config
import qs.Services.WM
import qs.Services.Core

SearchGridPanel {
  id: picker

  readonly property var _modeLabels: ({
      fill: qsTr("Fill"),
      fit: qsTr("Fit"),
      center: qsTr("Center"),
      stretch: qsTr("Stretch"),
      tile: qsTr("Tile")
    })
  readonly property var _transitionLabels: ({
      fade: qsTr("Fade"),
      wipe: qsTr("Wipe"),
      disc: qsTr("Disc"),
      stripes: qsTr("Stripes"),
      portal: qsTr("Portal")
    })
  property alias applyButton: applyActionButton
  property alias cancelButton: cancelActionButton
  property alias fillModeCombo: fillModeSelector
  readonly property var fillModeOptions: (WallpaperService?.availableModes ?? []).map(m => ({
        label: _modeLabels[m] ?? m,
        value: m
      }))
  property alias folderInput: folderPathInput
  property bool loadingFromService: false
  property alias monitorCombo: monitorSelector
  readonly property var monitorOptions: [
    {
      label: qsTr("All Monitors"),
      value: "all"
    }
  ].concat((WallpaperService?.monitors ?? []).map(m => ({
        label: m.name,
        value: m.name
      })).filter(e => e.value))
  property string selectedMonitor: "all"
  property var stagedModes: ({})
  property string stagedTransition: "disc"
  property var stagedWallpapers: ({})
  property alias transitionCombo: transitionSelector
  readonly property var transitionOptions: (WallpaperService?.availableTransitions ?? []).map(t => ({
        label: _transitionLabels[t] ?? t,
        value: t
      }))
  property string wallpaperFolder: WallpaperService?.wallpaperFolder ?? ""

  signal applyRequested
  signal cancelRequested

  function applyChanges() {
    if (!WallpaperService?.ready)
      return;
    const applyToAll = selectedMonitor === "all" && stagedWallpapers.all;

    for (const option of monitorOptions) {
      if (option.value === "all")
        continue;
      const name = option.value;
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
    const modes = {
      all: WallpaperService?.defaultMode ?? "fill"
    };
    const wallpapers = {
      all: ""
    };

    for (const mon of monitors) {
      const name = mon?.name;
      if (!name)
        continue;
      const state = WallpaperService?.ready ? WallpaperService.wallpaperFor(name) : null;
      modes[name] = state?.mode ?? modes.all;
      wallpapers[name] = state?.wallpaper ?? "";
    }

    stagedModes = modes;
    stagedWallpapers = wallpapers;
    stagedTransition = WallpaperService?.wallpaperTransition ?? "disc";

    const validNames = monitors.map(m => m?.name).filter(Boolean);
    const preferred = preferredMonitor ?? selectedMonitor;
    selectedMonitor = (preferred !== "all" && validNames.includes(preferred)) ? preferred : "all";

    updateCurrentWallpaperSelection();
    loadingFromService = false;
  }

  function refreshWallpapers() {
    const folder = String(picker.wallpaperFolder || "").replace(/\/$/, "");
    if (!folder.length)
      return;
    WallpaperService.setWallpaperFolder(folder);
  }

  function stageWallpaper(entry) {
    const path = entry?.path;
    if (!path)
      return;
    const key = selectedMonitor === "all" ? "all" : selectedMonitor;
    const updated = Object.assign({}, stagedWallpapers);
    updated[key] = path;
    stagedWallpapers = updated;
    updateCurrentWallpaperSelection();
  }

  function stagedWallpaperForMonitor(name) {
    if (name && name !== "all")
      return stagedWallpapers[name] || stagedWallpapers.all || "";
    return stagedWallpapers.all || "";
  }

  function updateCurrentWallpaperSelection() {
    const items = WallpaperService?.wallpaperFiles ?? [];
    const expectedPath = stagedWallpaperForMonitor(selectedMonitor);
    if (!items.length || !expectedPath)
      return;
    const idx = items.findIndex(entry => entry?.path === expectedPath);
    if (idx >= 0)
      currentIndex = idx;
  }

  cellHeight: 150
  cellPadding: 24
  cellWidth: 240
  closeOnActivate: false
  contentMargin: 16
  contentSpacing: 10
  delegateComponent: wallpaperDelegate
  finderBuilder: null
  iconSelector: function (entry) {
    return entry?.previewSource || "";
  }
  itemImageSize: 265
  items: WallpaperService?.wallpaperFiles || []
  labelSelector: function (entry) {
    return entry?.displayName || "";
  }
  placeholderText: qsTr("Search wallpapers…")
  searchSelector: function (entry) {
    return entry?.displayName || "";
  }
  windowHeight: 520
  windowWidth: 900

  footerContent: [
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      OButton {
        id: cancelActionButton

        bgColor: Theme.inactiveColor
        text: qsTr("Cancel")

        onClicked: picker.cancelRequested()
      }

      Item {
        Layout.fillWidth: true
      }

      OButton {
        id: applyActionButton

        bgColor: Theme.activeColor
        text: qsTr("Apply")

        onClicked: picker.applyChanges()
      }
    }
  ]
  headerContent: [
    RowLayout {
      Layout.fillWidth: true
      spacing: 16

      RowLayout {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.fillWidth: true
        Layout.minimumWidth: 280
        spacing: 8

        OInput {
          id: folderPathInput

          Layout.fillWidth: true
          placeholderText: qsTr("Wallpaper folder path")
          text: picker.wallpaperFolder

          onInputFinished: {
            if (picker.wallpaperFolder !== text)
              picker.wallpaperFolder = text;
          }
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        spacing: 8

        OComboBox {
          id: monitorSelector

          Layout.preferredWidth: 200
          currentIndex: Math.max(0, picker.monitorOptions.findIndex(o => o.value === picker.selectedMonitor))
          model: picker.monitorOptions
          textRole: "label"
          valueRole: "value"

          onActivated: index => {
            const entry = picker.monitorOptions[index];
            if (entry?.value)
              picker.selectedMonitor = entry.value;
          }
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        spacing: 8

        OComboBox {
          id: fillModeSelector

          readonly property string currentMode: {
            const modes = picker.stagedModes ?? {};
            const key = picker.selectedMonitor === "all" ? "all" : picker.selectedMonitor;
            return modes[key] ?? modes.all ?? "fill";
          }

          Layout.preferredWidth: 140
          currentIndex: Math.max(0, picker.fillModeOptions.findIndex(o => o.value === currentMode))
          model: picker.fillModeOptions
          textRole: "label"
          valueRole: "value"

          onActivated: index => {
            const entry = picker.fillModeOptions[index];
            if (!entry?.value)
              return;
            const modes = Object.assign({}, picker.stagedModes ?? {});
            if (picker.selectedMonitor === "all") {
              modes.all = entry.value;
              picker.monitorOptions.forEach(o => {
                if (o?.value && o.value !== "all")
                  modes[o.value] = entry.value;
              });
            } else {
              modes[picker.selectedMonitor] = entry.value;
            }
            picker.stagedModes = modes;
          }
        }

        OComboBox {
          id: transitionSelector

          Layout.preferredWidth: 150
          currentIndex: Math.max(0, picker.transitionOptions.findIndex(o => o.value === picker.stagedTransition))
          model: picker.transitionOptions
          textRole: "label"
          valueRole: "value"

          onActivated: index => {
            const entry = picker.transitionOptions[index];
            if (entry?.value)
              picker.stagedTransition = entry.value;
          }
        }
      }
    }
  ]

  Component.onCompleted: {
    // Optimize GridView memory usage
    if (gridView) {
      gridView.cacheBuffer = 300; // Limit off-screen items (2 rows)
    }
    refreshWallpapers();
  }
  onActivated: entry => stageWallpaper(entry)
  onActiveChanged: if (active)
    loadFromService()
  onMonitorOptionsChanged: if (!monitorOptions.some(option => option.value === selectedMonitor))
    selectedMonitor = "all"
  onSelectedMonitorChanged: {
    if (!loadingFromService)
      updateCurrentWallpaperSelection();
  }
  onWallpaperFolderChanged: refreshWallpapers()

  Connections {
    function onWallpaperFilesChanged() {
      Qt.callLater(() => picker.updateCurrentWallpaperSelection());
    }

    target: WallpaperService
  }

  Component {
    id: wallpaperDelegate

    Item {
      id: wallpaperItem

      property bool hovered: mouseArea.containsMouse
      required property int index
      required property var modelData
      readonly property string resolvedIcon: picker.callSelector(picker.iconSelector, wallpaperItem.modelData) || ""
      readonly property string resolvedLabel: picker.callSelector(picker.labelSelector, wallpaperItem.modelData) || ""
      readonly property bool selected: GridView.isCurrentItem

      height: GridView.view ? GridView.view.cellHeight : 0
      width: GridView.view ? GridView.view.cellWidth : 0

      Rectangle {
        id: tileFrame

        anchors.fill: parent
        anchors.margins: 8
        border.color: wallpaperItem.selected ? Theme.activeColor : (wallpaperItem.hovered ? Theme.onHoverColor : Theme.borderColor)
        border.width: 1
        color: Qt.rgba(0, 0, 0, 0.18)
        opacity: 0.95
        radius: Theme.itemRadius

        Item {
          id: maskedContent

          anchors.fill: parent
          layer.enabled: true

          layer.effect: OpacityMask {
            maskSource: Rectangle {
              color: "white"
              height: maskedContent.height
              radius: tileFrame.radius
              width: maskedContent.width
            }
          }

          Image {
            id: wallpaperPreview

            anchors.fill: parent
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectCrop
            smooth: true
            source: wallpaperItem.resolvedIcon
            // Optimize: Use thumbnail size instead of full resolution
            sourceSize.height: 150
            sourceSize.width: 240
            visible: source !== ""
          }

          Rectangle {
            id: labelBackground

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            color: Qt.rgba(0, 0, 0, 0.45)
            height: Math.max(36, parent.height * 0.18)
            visible: wallpaperItem.resolvedLabel !== ""

            OText {
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.right: parent.right
              anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              horizontalAlignment: Text.AlignLeft
              maximumLineCount: 1
              text: wallpaperItem.resolvedLabel
              verticalAlignment: Text.AlignVCenter
            }
          }

          Rectangle {
            anchors.fill: parent
            color: (wallpaperItem.selected || wallpaperItem.hovered) ? Qt.rgba(1, 1, 1, wallpaperItem.selected ? 0.18 : 0.10) : "transparent"
          }
        }
      }

      MouseArea {
        id: mouseArea

        acceptedButtons: Qt.LeftButton
        anchors.fill: parent
        hoverEnabled: true

        onClicked: function () {
          picker.currentIndex = wallpaperItem.index;
          picker.activateEntry(wallpaperItem.modelData);
        }
      }
    }
  }
}
