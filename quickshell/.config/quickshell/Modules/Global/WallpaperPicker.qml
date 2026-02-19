pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
  readonly property string currentWallpaperPath: selectedMonitor !== "all" && WallpaperService?.ready ? WallpaperService.wallpaperPath(selectedMonitor) : ""

  // ── Logic (unchanged) ────────────────────────────────────────────
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

  function stageFillMode(mode) {
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

  function stageWallpaper(entry) {
    if (!entry?.path)
      return;
    stagedWallpapers = Object.assign({}, stagedWallpapers, {
      [selectedMonitor === "all" ? "all" : selectedMonitor]: entry.path
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

  // ── Grid config ──────────────────────────────────────────────────
  cellHeight: 145
  cellPadding: 6
  cellWidth: 230
  closeOnActivate: false
  contentMargin: 14
  contentSpacing: 10
  delegateComponent: wallpaperDelegate
  iconSelector: entry => entry?.previewSource ?? ""
  itemImageSize: 265
  items: WallpaperService?.wallpaperFiles ?? []
  labelSelector: entry => entry?.displayName ?? ""
  placeholderText: qsTr("Search wallpapers…")
  searchSelector: labelSelector
  windowHeight: 540
  windowWidth: 960

  // ── Footer: ghost Cancel + bold pill Apply ───────────────────────
  footerContent: [
    RowLayout {
      spacing: 10
      width: parent?.width ?? 0

      Rectangle {
        border.color: Qt.rgba(1, 1, 1, 0.2)
        border.width: 1
        color: Qt.rgba(1, 1, 1, cancelMouse.containsMouse ? 0.08 : 0)
        implicitHeight: 40
        implicitWidth: 110
        radius: 20

        Behavior on color {
          ColorAnimation {
            duration: 130
          }
        }

        OText {
          anchors.centerIn: parent
          font.pixelSize: Theme.fontSize
          opacity: cancelMouse.containsMouse ? 1 : 0.65
          text: qsTr("Cancel")

          Behavior on opacity {
            NumberAnimation {
              duration: 130
            }
          }
        }

        MouseArea {
          id: cancelMouse

          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          onClicked: picker.cancelRequested()
        }
      }

      Item {
        Layout.fillWidth: true
      }

      Rectangle {
        color: Theme.activeColor
        implicitHeight: 40
        implicitWidth: 126
        radius: 20
        scale: applyMouse.containsMouse ? 1.05 : 1.0

        Behavior on scale {
          NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
          }
        }

        OText {
          anchors.centerIn: parent
          font.bold: true
          font.pixelSize: Theme.fontSize
          text: qsTr("Apply")
        }

        MouseArea {
          id: applyMouse

          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          onClicked: picker.applyChanges()
        }
      }
    }
  ]

  // ── Header ───────────────────────────────────────────────────────
  headerContent: [
    ColumnLayout {
      spacing: 10
      width: parent?.width ?? 0

      // Row 1 — folder path + monitor chip group
      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
          Layout.fillWidth: true
          border.color: Qt.rgba(1, 1, 1, 0.1)
          border.width: 1
          color: Qt.rgba(1, 1, 1, 0.05)
          implicitHeight: 36
          radius: 8

          RowLayout {
            spacing: 8

            anchors {
              fill: parent
              leftMargin: 12
              rightMargin: 12
            }

            OText {
              font.pixelSize: 13
              muted: true
              text: "⌂"
            }

            TextInput {
              Layout.fillWidth: true
              clip: true
              color: Theme.textActiveColor
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              selectByMouse: true
              text: WallpaperService?.wallpaperFolder ?? ""

              onEditingFinished: if (text !== (WallpaperService?.wallpaperFolder ?? ""))
                WallpaperService.setWallpaperFolder(text)
            }
          }
        }

        // Monitor chip group
        Rectangle {
          border.color: Qt.rgba(1, 1, 1, 0.1)
          border.width: 1
          color: Qt.rgba(1, 1, 1, 0.05)
          implicitHeight: 34
          implicitWidth: monitorChips.implicitWidth + 12
          radius: 17

          Row {
            id: monitorChips

            anchors.centerIn: parent
            spacing: 2

            Repeater {
              model: picker.monitorOptions

              delegate: Rectangle {
                id: recta

                required property int index
                readonly property bool isActive: picker.selectedMonitor === modelData.value
                required property var modelData

                color: isActive ? Theme.activeColor : "transparent"
                implicitHeight: 28
                implicitWidth: Math.max(58, monitorLabel.implicitWidth + 22)
                radius: 14

                Behavior on color {
                  ColorAnimation {
                    duration: 160
                  }
                }

                OText {
                  id: monitorLabel

                  anchors.centerIn: parent
                  font.bold: recta.isActive
                  font.pixelSize: 12
                  opacity: recta.isActive ? 1 : 0.55
                  text: recta.modelData.label

                  Behavior on opacity {
                    NumberAnimation {
                      duration: 160
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor

                  onClicked: picker.selectedMonitor = recta.modelData.value
                }
              }
            }
          }
        }
      }

      // Row 2 — fill chips + transition chips + theme + dark toggle
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        OText {
          font.pixelSize: 11
          muted: true
          opacity: 0.45
          text: qsTr("Mode")
        }

        ExpandableOptionPill {
          activeBgColor: Qt.rgba(1, 1, 1, 0.2)
          currentIndex: picker.activeFillModeIndex
          minSlotWidth: 50
          options: picker.fillModeOptions

          onSelected: value => picker.stageFillMode(value || "fill")
        }

        OText {
          font.pixelSize: 11
          muted: true
          opacity: 0.45
          text: qsTr("Transition")
        }

        ExpandableOptionPill {
          activeBgColor: Theme.activeColor
          currentIndex: picker.activeTransitionIndex
          minSlotWidth: 58
          options: picker.transitionOptions

          onSelected: value => picker.stagedTransition = value || "disc"
        }

        Item {
          Layout.fillWidth: true
        }

        OComboBox {
          Layout.preferredWidth: 160
          currentIndex: Math.max(0, picker.themeOptions.findIndex(o => o.value === (Settings?.data?.themeName ?? "")))
          model: picker.themeOptions
          textRole: "label"
          valueRole: "value"

          onActivated: idx => Settings?.setThemeName(picker.themeOptions[idx]?.value ?? "")
        }

        // macOS-style dark toggle
        RowLayout {
          spacing: 6

          OText {
            font.pixelSize: 11
            muted: true
            opacity: 0.55
            text: qsTr("Dark")
          }

          Rectangle {
            id: darkTrack

            readonly property bool isDark: (Settings?.data?.themeMode ?? "dark") === "dark"

            color: isDark ? Theme.activeColor : Qt.rgba(1, 1, 1, 0.18)
            implicitHeight: 26
            implicitWidth: 44
            radius: 13

            Behavior on color {
              ColorAnimation {
                duration: 200
              }
            }

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              color: "#ffffff"
              height: 20
              radius: 10
              width: 20
              x: darkTrack.isDark ? parent.width - width - 3 : 3

              Behavior on x {
                NumberAnimation {
                  duration: 200
                  easing.type: Easing.OutCubic
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor

              onClicked: Settings?.setThemeMode(darkTrack.isDark ? "light" : "dark")
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

      Rectangle {
        id: card

        clip: true
        color: "#111"
        radius: 12

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
          sourceSize: Qt.size(230, 145)
        }

        // Hover / selected overlay
        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(0, 0, 0, tile.selected ? 0.22 : tile.hovered ? 0.12 : 0)

          Behavior on color {
            ColorAnimation {
              duration: 130
            }
          }
        }

        Rectangle {
          color: "#20c05c"
          height: 20
          radius: 10
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
            font.bold: true
            font.pixelSize: 12
            text: "✓"
          }
        }

        // Name label fades in on hover / select
        Rectangle {
          color: Qt.rgba(0, 0, 0, 0.65)
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
