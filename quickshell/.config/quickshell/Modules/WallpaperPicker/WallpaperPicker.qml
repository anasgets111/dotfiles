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

  signal applyRequested
  signal cancelRequested

  property alias folderInput: folderPathInput
  property alias monitorCombo: monitorSelector
  property alias fillModeCombo: fillModeSelector
  property alias transitionCombo: transitionSelector
  property alias applyButton: applyActionButton
  property alias cancelButton: cancelActionButton

  property string wallpaperFolder: "/mnt/Work/1Wallpapers/Main"
  property var wallpaperEntries: []

  readonly property var monitorOptions: {
    const monitors = picker.currentMonitors();
    return defaultMonitorOptions.concat(monitors.map(mon => ({
          label: mon?.name,
          value: mon?.name
        }))).filter(entry => typeof entry.value === "string" && entry.value.length > 0);
  }
  property string selectedMonitor: "all"
  property string committedMonitor: "all"
  onMonitorOptionsChanged: if (!monitorOptions.some(option => option.value === selectedMonitor))
    selectedMonitor = "all"
  property var stagedModes: ({})
  property var stagedWallpapers: ({})
  property string stagedTransition: "disc"
  property var initialWallpapers: ({})
  property string globalPendingWallpaper: ""
  property bool loadingFromService: false
  onSelectedMonitorChanged: {
    committedMonitor = selectedMonitor;
    if (loadingFromService)
      return;
    if (selectedMonitor !== "all" && typeof globalPendingWallpaper === "string" && globalPendingWallpaper.length > 0) {
      const staged = stagedWallpapers || {};
      const initial = initialWallpapers || {};
      const currentValue = staged[selectedMonitor];
      const baseline = initial[selectedMonitor];
      if (!currentValue || currentValue === baseline) {
        const updated = Object.assign({}, staged);
        updated[selectedMonitor] = globalPendingWallpaper;
        stagedWallpapers = updated;
      }
    }
    updateCurrentWallpaperSelection();
  }
  readonly property var defaultFillModeValues: ["fill", "fit", "center", "stretch", "tile"]
  readonly property var fillModeOptions: {
    const values = WallpaperService && Array.isArray(WallpaperService.availableModes) && WallpaperService.availableModes.length > 0 ? WallpaperService.availableModes : defaultFillModeValues;
    return values.map(mode => ({
          label: fillModeLabel(mode),
          value: mode
        }));
  }
  readonly property var defaultTransitionValues: ["fade", "wipe", "disc", "stripes", "portal"]
  readonly property var transitionOptions: {
    const values = WallpaperService && Array.isArray(WallpaperService.availableTransitions) && WallpaperService.availableTransitions.length > 0 ? WallpaperService.availableTransitions : defaultTransitionValues;
    return values.map(type => ({
          label: transitionLabel(type),
          value: type
        }));
  }

  readonly property var defaultMonitorOptions: [
    {
      label: qsTr("All Monitors"),
      value: "all"
    }
  ]

  onActiveChanged: if (active)
    loadFromService()

  windowWidth: 900
  windowHeight: 520
  itemImageSize: 265
  contentMargin: 16
  contentSpacing: 10
  closeOnActivate: false
  placeholderText: qsTr("Search wallpapers…")
  cellWidth: 240
  cellHeight: 150
  cellPadding: 24
  items: wallpaperEntries
  finderBuilder: null
  searchSelector: function (entry) {
    return entry?.displayName || "";
  }
  labelSelector: function (entry) {
    return entry?.displayName || "";
  }
  iconSelector: function (entry) {
    return entry?.previewSource || "";
  }
  delegateComponent: wallpaperDelegate
  onActivated: entry => stageWallpaper(entry)

  Component.onCompleted: refreshWallpapers()
  onWallpaperFolderChanged: refreshWallpapers()

  function currentMonitors() {
    if (Array.isArray(WallpaperService?.monitors) && WallpaperService.monitors.length > 0)
      return WallpaperService.monitors;
    if (MonitorService?.ready && MonitorService.monitors?.count)
      return Array.from({
        length: MonitorService.monitors.count
      }, (_, i) => MonitorService.monitors.get(i));
    return [];
  }

  function fillModeLabel(mode) {
    switch ((mode || "").toString().toLowerCase()) {
    case "fill":
      return qsTr("Fill");
    case "fit":
      return qsTr("Fit");
    case "center":
      return qsTr("Center");
    case "stretch":
      return qsTr("Stretch");
    case "tile":
      return qsTr("Tile");
    default:
      return mode || "";
    }
  }

  function transitionLabel(type) {
    switch ((type || "").toString().toLowerCase()) {
    case "fade":
      return qsTr("Fade");
    case "wipe":
      return qsTr("Wipe");
    case "disc":
      return qsTr("Disc");
    case "stripes":
      return qsTr("Stripes");
    case "portal":
      return qsTr("Portal");
    default:
      return type || "";
    }
  }

  function loadFromService() {
    loadingFromService = true;
    const monitors = currentMonitors();
    const modes = {};
    const wallpapers = {};
    const defaultMode = WallpaperService?.defaultMode || "fill";
    const defaultWallpaper = WallpaperService?.defaultWallpaper || "";
    const canQuery = WallpaperService?.ready && typeof WallpaperService.wallpaperFor === "function";

    for (const monitor of monitors) {
      const name = monitor?.name;
      if (!name)
        continue;
      const state = canQuery ? WallpaperService.wallpaperFor(name) : null;
      modes[name] = state?.mode || defaultMode;
      wallpapers[name] = state?.wallpaper || defaultWallpaper;
    }

    modes.all = defaultMode;
    wallpapers.all = defaultWallpaper;

    stagedModes = Object.assign({}, modes);
    initialWallpapers = Object.assign({}, wallpapers);
    stagedWallpapers = Object.assign({}, wallpapers);
    stagedTransition = WallpaperService?.wallpaperTransition || WallpaperService?.defaultTransition || "disc";
    globalPendingWallpaper = "";

    const availableMonitorNames = monitors.map(m => (typeof m?.name === "string" && m.name.length > 0) ? m.name : null).filter(name => !!name);
    const fallbackMonitor = (committedMonitor !== "all" && availableMonitorNames.includes(committedMonitor)) ? committedMonitor : "all";

    committedMonitor = fallbackMonitor;
    selectedMonitor = fallbackMonitor;
    updateCurrentWallpaperSelection();
    loadingFromService = false;
  }

  function stageWallpaper(entry) {
    const path = entry?.path;
    if (typeof path !== "string" || path.length === 0)
      return;
    const updated = Object.assign({}, stagedWallpapers || {});
    if (selectedMonitor === "all") {
      updated.all = path;
      globalPendingWallpaper = path;
    } else {
      updated[selectedMonitor] = path;
      globalPendingWallpaper = "";
    }
    stagedWallpapers = updated;
    updateCurrentWallpaperSelection();
  }

  function stagedWallpaperForMonitor(name) {
    const wallpapers = stagedWallpapers || {};
    const initial = initialWallpapers || {};
    if (name && name !== "all") {
      const stagedValue = wallpapers[name];
      if (typeof stagedValue === "string" && stagedValue.length)
        return stagedValue;
      const globalValue = wallpapers.all;
      if (typeof globalValue === "string" && globalValue.length && globalValue !== initial[name])
        return globalValue;
      const initialValue = initial[name];
      if (typeof initialValue === "string" && initialValue.length)
        return initialValue;
      return initial.all || "";
    }
    const stagedAll = wallpapers.all;
    if (typeof stagedAll === "string" && stagedAll.length)
      return stagedAll;
    return initial.all || "";
  }

  function updateCurrentWallpaperSelection() {
    const items = Array.isArray(wallpaperEntries) ? wallpaperEntries : [];
    if (!items.length)
      return;
    const key = selectedMonitor === "all" ? "all" : selectedMonitor;
    const expectedPath = stagedWallpaperForMonitor(key);
    if (!expectedPath)
      return;
    const idx = items.findIndex(entry => entry?.path === expectedPath);
    if (idx >= 0)
      currentIndex = idx;
  }

  function applyChanges() {
    if (!WallpaperService)
      return;
    const previousSelection = selectedMonitor;
    const options = monitorOptions.filter(option => option?.value && option.value !== "all");
    const modes = stagedModes || {};
    const wallpapers = stagedWallpapers || {};
    const initial = initialWallpapers || {};
    const defaultMode = WallpaperService?.defaultMode || "fill";
    const defaultWallpaper = WallpaperService?.defaultWallpaper || "";
    const transition = stagedTransition || WallpaperService?.defaultTransition || "disc";
    const applyAll = previousSelection === "all" && typeof wallpapers.all === "string" && wallpapers.all.length > 0;

    options.forEach(option => {
      const name = option.value;
      const mode = modes[name] || modes.all || defaultMode;
      let wallpaper;
      if (applyAll) {
        wallpaper = wallpapers.all;
      } else {
        wallpaper = wallpapers[name];
        if (typeof wallpaper !== "string" || !wallpaper.length)
          wallpaper = initial[name] || initial.all || defaultWallpaper;
      }
      if (typeof mode === "string" && mode.length && typeof WallpaperService.setModePref === "function")
        WallpaperService.setModePref(name, mode);
      if (typeof wallpaper === "string" && wallpaper.length && typeof WallpaperService.setWallpaper === "function")
        WallpaperService.setWallpaper(name, wallpaper);
    });

    if (typeof WallpaperService.setWallpaperTransition === "function" && transition)
      WallpaperService.setWallpaperTransition(transition);

    committedMonitor = previousSelection;
    loadFromService();
    selectedMonitor = committedMonitor;
    applyRequested();
  }

  function refreshWallpapers() {
    const folder = String(picker.wallpaperFolder || "").replace(/\/$/, "");
    if (!folder.length) {
      picker.wallpaperEntries = [];
      return;
    }

    const glob = `${folder}/*.{jpg,jpeg,png,webp,JPG,JPEG,PNG,WEBP}`;
    FileSystemService.listByGlob(glob, files => {
      const list = Array.isArray(files) ? files.filter(f => typeof f === "string" && f.length > 0) : [];
      picker.wallpaperEntries = list.map(path => {
        const resolvedPath = path.startsWith("file:") ? path : `file://${path}`;
        const nameMatch = String(path).split("/").pop() || path;
        return {
          path,
          displayName: nameMatch,
          previewSource: resolvedPath
        };
      });
      Qt.callLater(() => picker.updateCurrentWallpaperSelection());
    });
  }

  Component {
    id: wallpaperDelegate

    Item {
      id: wallpaperItem
      required property var modelData
      required property int index

      width: GridView.view ? GridView.view.cellWidth : 0
      height: GridView.view ? GridView.view.cellHeight : 0
      property bool hovered: mouseArea.containsMouse
      readonly property bool selected: GridView.isCurrentItem
      readonly property string resolvedLabel: picker.callSelector(picker.labelSelector, wallpaperItem.modelData) || ""
      readonly property string resolvedIcon: picker.callSelector(picker.iconSelector, wallpaperItem.modelData) || ""

      Rectangle {
        id: tileFrame
        anchors.fill: parent
        anchors.margins: 8
        radius: Theme.itemRadius
        color: Qt.rgba(0, 0, 0, 0.18)
        border.width: 1
        border.color: wallpaperItem.selected ? Theme.activeColor : (wallpaperItem.hovered ? Theme.onHoverColor : Theme.borderColor)
        opacity: 0.95

        Item {
          id: maskedContent
          anchors.fill: parent
          layer.enabled: true
          layer.effect: OpacityMask {
            maskSource: Rectangle {
              width: maskedContent.width
              height: maskedContent.height
              radius: tileFrame.radius
              color: "white"
            }
          }

          Image {
            id: wallpaperPreview
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: wallpaperItem.resolvedIcon
            asynchronous: true
            visible: source !== ""
            smooth: true
          }

          Rectangle {
            id: labelBackground
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(36, parent.height * 0.18)
            color: Qt.rgba(0, 0, 0, 0.45)
            visible: wallpaperItem.resolvedLabel !== ""

            Text {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              text: wallpaperItem.resolvedLabel
              color: Theme.textActiveColor
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              elide: Text.ElideRight
              maximumLineCount: 1
              horizontalAlignment: Text.AlignLeft
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
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: function () {
          picker.currentIndex = wallpaperItem.index;
          picker.activateEntry(wallpaperItem.modelData);
        }
      }
    }
  }

  headerContent: [
    RowLayout {
      Layout.fillWidth: true
      spacing: 16

      RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 280
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        spacing: 8

        TextField {
          id: folderPathInput
          Layout.fillWidth: true
          placeholderText: qsTr("Wallpaper folder path")
          text: picker.wallpaperFolder
          onEditingFinished: {
            if (picker.wallpaperFolder !== text)
              picker.wallpaperFolder = text;
          }
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        spacing: 8

        ComboBox {
          id: monitorSelector
          Layout.preferredWidth: 200
          model: picker.monitorOptions
          textRole: "label"
          valueRole: "value"
          currentIndex: {
            const options = picker.monitorOptions;
            if (!Array.isArray(options))
              return 0;
            const idx = options.findIndex(option => option.value === picker.selectedMonitor);
            return idx >= 0 ? idx : 0;
          }
          onActivated: function (index) {
            const entry = picker.monitorOptions[index];
            if (entry && typeof entry.value === "string")
              picker.selectedMonitor = entry.value;
          }
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        spacing: 8

        ComboBox {
          id: fillModeSelector
          Layout.preferredWidth: 140
          model: picker.fillModeOptions
          textRole: "label"
          valueRole: "value"
          currentIndex: {
            const options = picker.fillModeOptions;
            if (!Array.isArray(options))
              return 0;
            const modes = picker.stagedModes || {};
            const key = picker.selectedMonitor === "all" ? "all" : picker.selectedMonitor;
            const mode = modes[key] || modes.all || (options[0] ? options[0].value : "fill");
            const idx = options.findIndex(option => option.value === mode);
            return idx >= 0 ? idx : 0;
          }
          onActivated: function (index) {
            const entry = picker.fillModeOptions[index];
            if (!entry || typeof entry.value !== "string")
              return;
            const modes = Object.assign({}, picker.stagedModes || {});
            if (picker.selectedMonitor === "all") {
              modes.all = entry.value;
              picker.monitorOptions.forEach(option => {
                if (option?.value && option.value !== "all")
                  modes[option.value] = entry.value;
              });
            } else {
              modes[picker.selectedMonitor] = entry.value;
            }
            picker.stagedModes = modes;
          }
        }

        ComboBox {
          id: transitionSelector
          Layout.preferredWidth: 150
          model: picker.transitionOptions
          textRole: "label"
          valueRole: "value"
          currentIndex: {
            const options = picker.transitionOptions;
            if (!Array.isArray(options))
              return 0;
            const transition = picker.stagedTransition || (options[0] ? options[0].value : "disc");
            const idx = options.findIndex(option => option.value === transition);
            return idx >= 0 ? idx : 0;
          }
          onActivated: function (index) {
            const entry = picker.transitionOptions[index];
            if (entry && typeof entry.value === "string")
              picker.stagedTransition = entry.value;
          }
        }
      }
    }
  ]

  footerContent: [
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Button {
        id: cancelActionButton
        text: qsTr("Cancel")
        onClicked: picker.cancelRequested()
      }

      Item {
        Layout.fillWidth: true
      }

      Button {
        id: applyActionButton
        text: qsTr("Apply")
        highlighted: true
        onClicked: picker.applyChanges()
      }
    }
  ]
}
