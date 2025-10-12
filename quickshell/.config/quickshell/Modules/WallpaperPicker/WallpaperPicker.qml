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

  property alias applyButton: applyActionButton
  property alias cancelButton: cancelActionButton
  readonly property var defaultFillModeValues: ["fill", "fit", "center", "stretch", "tile"]
  readonly property var defaultMonitorOptions: [
    {
      label: qsTr("All Monitors"),
      value: "all"
    }
  ]
  readonly property var defaultTransitionValues: ["fade", "wipe", "disc", "stripes", "portal"]
  property alias fillModeCombo: fillModeSelector
  readonly property var fillModeOptions: {
    const values = WallpaperService && Array.isArray(WallpaperService.availableModes) && WallpaperService.availableModes.length > 0 ? WallpaperService.availableModes : defaultFillModeValues;
    return values.map(mode => ({
          label: fillModeLabel(mode),
          value: mode
        }));
  }
  property alias folderInput: folderPathInput
  property string globalPendingWallpaper: ""
  property var initialWallpapers: ({})
  property bool loadingFromService: false
  property alias monitorCombo: monitorSelector
  readonly property var monitorOptions: {
    const monitors = picker.currentMonitors();
    return defaultMonitorOptions.concat(monitors.map(mon => ({
          label: mon?.name,
          value: mon?.name
        }))).filter(entry => typeof entry.value === "string" && entry.value.length > 0);
  }
  property string selectedMonitor: "all"
  property var stagedModes: ({})
  property string stagedTransition: "disc"
  property var stagedWallpapers: ({})
  property alias transitionCombo: transitionSelector
  readonly property var transitionOptions: {
    const values = WallpaperService && Array.isArray(WallpaperService.availableTransitions) && WallpaperService.availableTransitions.length > 0 ? WallpaperService.availableTransitions : defaultTransitionValues;
    return values.map(type => ({
          label: transitionLabel(type),
          value: type
        }));
  }
  property string wallpaperFolder: WallpaperService?.wallpaperFolder ?? "/mnt/Work/1Wallpapers/Main"

  signal applyRequested
  signal cancelRequested

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

    loadFromService(previousSelection);
    applyRequested();
  }

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

  function loadFromService(preferredMonitor) {
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
    const requestedMonitor = typeof preferredMonitor === "string" && preferredMonitor.length > 0 ? preferredMonitor : selectedMonitor;
    const fallbackMonitor = (requestedMonitor !== "all" && availableMonitorNames.includes(requestedMonitor)) ? requestedMonitor : "all";

    if (selectedMonitor !== fallbackMonitor)
      selectedMonitor = fallbackMonitor;
    updateCurrentWallpaperSelection();
    loadingFromService = false;
    return fallbackMonitor;
  }

  function refreshWallpapers() {
    const folder = String(picker.wallpaperFolder || "").replace(/\/$/, "");
    if (!folder.length)
      return;
    WallpaperService.setWallpaperFolder(folder);
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

  function updateCurrentWallpaperSelection() {
    const items = Array.isArray(WallpaperService?.wallpaperFiles) ? WallpaperService.wallpaperFiles : [];
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

        highlighted: true
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
          currentIndex: {
            const options = picker.monitorOptions;
            if (!Array.isArray(options))
              return 0;
            const idx = options.findIndex(option => option.value === picker.selectedMonitor);
            return idx >= 0 ? idx : 0;
          }
          model: picker.monitorOptions
          textRole: "label"
          valueRole: "value"

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
          model: picker.fillModeOptions
          textRole: "label"
          valueRole: "value"

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
          currentIndex: {
            const options = picker.transitionOptions;
            if (!Array.isArray(options))
              return 0;
            const transition = picker.stagedTransition || (options[0] ? options[0].value : "disc");
            const idx = options.findIndex(option => option.value === transition);
            return idx >= 0 ? idx : 0;
          }
          model: picker.transitionOptions
          textRole: "label"
          valueRole: "value"

          onActivated: function (index) {
            const entry = picker.transitionOptions[index];
            if (entry && typeof entry.value === "string")
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

            Component.onDestruction: {
              // Properly release image memory
              wallpaperPreview.sourceSize = Qt.size(0, 0);
              // Clear source immediately (no Qt.callLater needed during destruction)
              wallpaperPreview.source = "";
            }
          }

          Rectangle {
            id: labelBackground

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            color: Qt.rgba(0, 0, 0, 0.45)
            height: Math.max(36, parent.height * 0.18)
            visible: wallpaperItem.resolvedLabel !== ""

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.right: parent.right
              anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              color: Theme.textActiveColor
              elide: Text.ElideRight
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
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
