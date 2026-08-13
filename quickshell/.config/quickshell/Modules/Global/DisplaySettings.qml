pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Services.Utils
import qs.Services.WM

Item {
  id: root

  property double _previewDeadline: 0
  property bool _revertWhenReady: false
  property int previewSecondsRemaining: 0
  property var preview: null
  property string selectedMonitor: ""
  readonly property bool previewActive: preview !== null
  readonly property var monitorOptions: {
    const revision = MonitorService.monitorsRevision;
    return MonitorService.toArray().map(monitor => ({
          label: monitor.displayModel ? `${monitor.name} · ${monitor.displayModel}` : monitor.name,
          value: monitor.name
        }));
  }
  readonly property var selectedMonitorData: {
    const revision = MonitorService.monitorsRevision;
    return MonitorService.monitor(selectedMonitor);
  }
  readonly property int selectedNumber: monitorOptions.findIndex(option => option.value === selectedMonitor) + 1
  readonly property var modeOptions: (selectedMonitorData?.modeKeysText ?? "").split("\n").filter(Boolean).map(key => ({
        label: modeLabel(key),
        value: key
      }))
  readonly property var scaleValues: (selectedMonitorData?.scaleKeysText ?? "").split("\n").filter(Boolean).map(value => parseFloat(value))
  readonly property var transformOptions: MonitorService.controlOptions("transform").map(value => ({
        label: transformLabel(value),
        value
      }))
  readonly property var vrrOptions: MonitorService.controlOptions("vrrMode").map(value => ({
        label: vrrLabel(value),
        value
      }))
  readonly property var maxBpcOptions: MonitorService.controlOptions("maxBpc").filter(value => !Number.isFinite(selectedMonitorData?.maxBpcSupported) || value <= selectedMonitorData.maxBpcSupported).map(value => ({
        label: qsTr("%1 bpc").arg(value),
        value
      }))
  readonly property var colorModeOptions: MonitorService.controlOptions("colorMode").map(value => ({ label: colorModeLabel(value), value }))
  readonly property int scaleSteps: Math.max(1, scaleValues.length - 1)
  readonly property bool hdrOn: ["hdr", "hdredid"].includes(selectedMonitorData?.colorMode ?? "")
  readonly property var previewFields: ["mode", "scale", "position", "transform"]
  readonly property bool previewEditable: !previewActive || isPreviewing(selectedMonitor)
  readonly property bool hasIccProfile: (selectedMonitorData?.iccProfile ?? "").trim() !== ""
  property string _lastIccPath: ""
  readonly property string savedIccPath: (selectedMonitorData?.iccProfile || selectedMonitorData?.lastIccProfile || _lastIccPath) || ""
  property bool _iccToggled: hasIccProfile
  readonly property bool isIccActive: hasIccProfile || _iccToggled

  onHasIccProfileChanged: {
    _iccToggled = hasIccProfile;
    if (!hasIccProfile && (selectedMonitorData?.lastIccProfile ?? "") === "")
      _lastIccPath = "";
  }

  function ensureSelection(): void {
    if (!monitorOptions.some(option => option.value === selectedMonitor))
      selectedMonitor = monitorOptions[0]?.value ?? "";
  }
  function modeLabel(key: string): string {
    const match = key.match(/^(\d+)x(\d+)@([\d.]+)$/);
    return match ? qsTr("%1 × %2 · %3 Hz").arg(match[1]).arg(match[2]).arg(Math.round(parseFloat(match[3]) * 100) / 100) : key;
  }
  function transformLabel(value: string): string {
    return ({ normal: qsTr("Landscape"), "90": qsTr("Portrait · 90°"), "180": qsTr("Landscape · 180°"), "270": qsTr("Portrait · 270°"), flipped: qsTr("Flipped"), "flipped-90": qsTr("Flipped · 90°"), "flipped-180": qsTr("Flipped · 180°"), "flipped-270": qsTr("Flipped · 270°") })[value] ?? value;
  }
  function vrrLabel(value: string): string {
    return ({ off: qsTr("Off"), on: qsTr("Always"), "on-demand": qsTr("On demand"), fullscreen: qsTr("Fullscreen"), "content-aware": qsTr("Content aware") })[value] ?? value;
  }
  function colorModeLabel(value: string): string {
    return ({ srgb: qsTr("SDR (sRGB)"), hdr: qsTr("HDR (PQ ST2084)"), hdredid: qsTr("HDR (EDID Passthrough)") })[value] ?? value;
  }
  function optionIndex(options: var, value: var): int {
    return options.findIndex(option => option?.value === value);
  }
  function scaleFromSlider(value: real): real {
    return scaleValues[Math.round(Math.max(0, Math.min(1, value)) * (scaleValues.length - 1))];
  }
  function scaleToSlider(value: real): real {
    if (scaleValues.length < 2)
      return 0;
    const closest = scaleValues.reduce((best, scale, index) => Math.abs(scale - value) < Math.abs(scaleValues[best] - value) ? index : best, 0);
    return closest / (scaleValues.length - 1);
  }
  function currentValue(field: string): var {
    if (field === "position")
      return { x: selectedMonitorData?.logicalX ?? 0, y: selectedMonitorData?.logicalY ?? 0 };
    return selectedMonitorData?.[MonitorService._fieldRoles[field]];
  }
  // Anything that can leave an output unreadable goes through the timed revert; the rest commits.
  function applyValue(field: string, value: var): void {
    const changes = { [field]: value };
    if (!previewFields.includes(field)) {
      MonitorService.setMonitorConfig(selectedMonitor, changes);
      return;
    }
    // A rotation relays out the desktop, so a revert has to restore the position too.
    const original = { position: currentValue("position"), [field]: currentValue(field) };
    previewConfig(selectedMonitor, original, changes);
  }
  function applyIcc(input: var): void {
    const raw = typeof input === "string" ? input : (input?.text ?? "");
    const path = raw.trim();
    if (path && !path.startsWith("/"))
      return;
    if (path)
      _lastIccPath = path;
    applyValue("icc", path);
  }
  function isPreviewing(name: string): bool {
    return preview?.name === name;
  }
  function previewValue(name: string, field: string, fallback: var): var {
    return isPreviewing(name) && Utils.has(preview?.changes ?? {}, field) ? preview.changes[field] : fallback;
  }
  function isQuarterTurn(transformMode: var): bool {
    return ["90", "270", "flipped-90", "flipped-270"].includes(transformMode);
  }
  function _restorePreview(state: var): void {
    preview = state ? Object.assign({}, state, { applying: false }) : null;
    previewSecondsRemaining = state ? 10 : 0;
    if (!state) {
      _revertWhenReady = false;
      previewTimer.stop();
      return;
    }
    if (_revertWhenReady) {
      _revertWhenReady = false;
      Qt.callLater(revertPreview);
      return;
    }
    _previewDeadline = Date.now() + 10000;
    previewTimer.restart();
  }
  function previewConfig(name: string, original: var, changes: var): void {
    if (previewActive && !isPreviewing(name))
      return;
    const previous = preview;
    const base = previous ?? { name, original: {}, changes: {} };
    const next = Object.assign({}, base, {
      applying: true,
      // Keep the value each field held before the preview began; a later edit must not overwrite it.
      original: Object.assign(Utils.clone(original), base.original),
      changes: Object.assign({}, base.changes, Utils.clone(changes))
    });
    preview = next;
    previewTimer.stop();
    MonitorService.previewMonitorConfig(name, changes, result => root._restorePreview(result?.success ? next : previous));
  }
  function confirmPreview(): void {
    const pending = preview;
    if (!pending || pending.applying)
      return;
    preview = Object.assign({}, pending, { applying: true });
    previewTimer.stop();
    MonitorService.setMonitorConfig(pending.name, pending.changes, result => root._restorePreview(result?.success ? null : pending));
  }
  function revertPreview(): void {
    const pending = preview;
    if (!pending)
      return;
    if (pending.applying) {
      _revertWhenReady = true;
      return;
    }
    const changes = {};
    for (const field of Object.keys(pending.changes))
      if (Utils.has(pending.original, field))
        changes[field] = Utils.clone(pending.original[field]);
    if (!Object.keys(changes).length) {
      _restorePreview(null);
      return;
    }
    preview = Object.assign({}, pending, { applying: true });
    previewTimer.stop();
    MonitorService.previewMonitorConfig(pending.name, changes, () => root._restorePreview(null));
  }

  onVisibleChanged: {
    if (!visible)
      revertPreview();
  }
  onMonitorOptionsChanged: {
    if (preview && !monitorOptions.some(option => option.value === preview.name))
      _restorePreview(null);
    ensureSelection();
  }

  Component.onCompleted: ensureSelection()

  Timer {
    id: previewTimer

    interval: 250
    repeat: true

    onTriggered: {
      const remaining = Math.max(0, root._previewDeadline - Date.now());
      root.previewSecondsRemaining = Math.ceil(remaining / 1000);
      if (remaining === 0)
        root.revertPreview();
    }
  }

  component ComboRow: PanelRow {
    id: comboRow

    required property int currentIndex
    property bool inputEnabled: true
    required property var options

    signal optionActivated(int index)

    rowActionEnabled: false
    actions: [
      OComboBox {
        implicitWidth: Theme.wallpaperSidebarWidth
        currentIndex: comboRow.currentIndex
        enabled: comboRow.inputEnabled
        model: comboRow.options
        textRole: "label"

        onActivated: index => comboRow.optionActivated(index)
      }
    ]
  }

  ScrollView {
    id: scrollView

    anchors.bottom: previewBar.visible ? previewBar.top : parent.bottom
    anchors.bottomMargin: previewBar.visible ? Theme.spacingMd : 0
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    clip: true
    contentWidth: availableWidth
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    ColumnLayout {
      spacing: Theme.spacingMd
      width: scrollView.availableWidth

      Item {
        Layout.preferredHeight: Theme.spacingXs
      }
      PanelCard {
        Layout.fillWidth: true
        implicitHeight: arrangementLayout.implicitHeight + padding * 2

        ColumnLayout {
          id: arrangementLayout

          anchors.fill: parent
          spacing: Theme.spacingMd

          PanelHeader {
            icon: "󰍹"
            subtitle: root.previewActive ? qsTr("Adjust the highlighted display, then keep or revert the preview.") : qsTr("Drag displays to match the physical setup; nearby edges snap together.")
            title: qsTr("Arrange displays")

            InfoBadge {
              badgeColor: Theme.activeColor
              text: qsTr("%1 connected").arg(MonitorService.monitors.count)
            }
          }
          Item {
            id: arrangementCanvas

            readonly property var bounds: MonitorService.arrangementBounds
            readonly property real canvasPadding: Theme.spacingMd
            readonly property real logicalHeight: Math.max(1, bounds.maxY - bounds.minY)
            readonly property real logicalWidth: Math.max(1, bounds.maxX - bounds.minX)
            readonly property real arrangementScale: Math.max(0.01, Math.min((width - canvasPadding * 2) / logicalWidth, (height - canvasPadding * 2) / logicalHeight, 0.16))
            readonly property real originX: (width - logicalWidth * arrangementScale) / 2
            readonly property real originY: (height - logicalHeight * arrangementScale) / 2

            function toCanvasX(logicalX: real): real {
              return originX + (logicalX - bounds.minX) * arrangementScale;
            }
            function toCanvasY(logicalY: real): real {
              return originY + (logicalY - bounds.minY) * arrangementScale;
            }

            readonly property real idealAspectHeight: (width - canvasPadding * 2) * logicalHeight / logicalWidth + canvasPadding * 2
            readonly property real responsiveMaxHeight: Math.max(Theme.controlHeightXl * 2, scrollView.availableHeight * 0.32)

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(Theme.controlHeightXl * 2, Math.min(responsiveMaxHeight, idealAspectHeight))
            clip: true

            Rectangle {
              anchors.fill: parent
              border.color: Theme.glassBorderColor
              border.width: Theme.borderWidthThin
              color: Theme.glassInputColor
              radius: Theme.radiusMd

              Canvas {
                id: gridCanvas

                anchors.fill: parent
                opacity: 0.12

                onHeightChanged: requestPaint()
                onPaint: {
                  const ctx = getContext("2d");
                  ctx.clearRect(0, 0, width, height);
                  ctx.strokeStyle = Theme.textActiveColor;
                  ctx.lineWidth = 1;
                  const step = 24;
                  for (let x = step; x < width; x += step) {
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, height);
                    ctx.stroke();
                  }
                  for (let y = step; y < height; y += step) {
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(width, y);
                    ctx.stroke();
                  }
                }
                onWidthChanged: requestPaint()
              }
            }
            Repeater {
              model: MonitorService.monitors

              delegate: Rectangle {
                id: outputPreview

                required property bool displayBusy
                required property var logicalHeight
                required property var logicalWidth
                required property var logicalX
                required property var logicalY
                required property string name
                required property var transformMode

                readonly property var effectivePosition: dragPosition ?? root.previewValue(name, "position", { x: logicalX, y: logicalY })
                readonly property var effectiveTransform: root.previewValue(name, "transform", transformMode)
                readonly property bool selected: root.selectedMonitor === name
                readonly property bool swapDimensions: root.isQuarterTurn(effectiveTransform) !== root.isQuarterTurn(transformMode)
                readonly property real outputLogicalHeight: swapDimensions ? logicalWidth : logicalHeight
                readonly property real outputLogicalWidth: swapDimensions ? logicalHeight : logicalWidth
                property var dragPosition: null
                property var dragStartPosition: null
                property point dragStartPoint: Qt.point(0, 0)

                border.color: root.isPreviewing(name) ? Theme.warning : selected ? Theme.activeColor : dragArea.containsMouse ? Theme.glassBorderHoverColor : Theme.glassBorderColor
                border.width: selected || root.isPreviewing(name) ? Theme.borderWidthMedium : Theme.borderWidthThin
                color: root.isPreviewing(name) ? Theme.withOpacity(Theme.warning, Theme.opacityLight) : selected ? Theme.activeSubtle : dragArea.containsMouse ? Theme.glassContentHoverColor : Theme.glassContentColor
                height: Math.max(Theme.controlHeightLg, outputLogicalHeight * arrangementCanvas.arrangementScale)
                opacity: !root.previewActive || root.isPreviewing(name) ? 1 : Theme.opacityDisabled
                radius: Theme.radiusSm
                width: Math.max(Theme.controlHeightXl * 1.5, outputLogicalWidth * arrangementCanvas.arrangementScale)
                x: arrangementCanvas.toCanvasX(effectivePosition.x)
                y: arrangementCanvas.toCanvasY(effectivePosition.y)
                z: dragArea.pressed ? 1 : 0

                Theme.ColorTransition on border.color {
                }
                Theme.ColorTransition on color {
                }

                Column {
                  anchors.centerIn: parent
                  spacing: Theme.spacingXs

                  OText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    bold: true
                    color: outputPreview.selected ? Theme.activeColor : Theme.textActiveColor
                    text: outputPreview.name
                  }
                  OText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.textInactiveColor
                    size: "xs"
                    text: `${Math.round(outputPreview.outputLogicalWidth)} × ${Math.round(outputPreview.outputLogicalHeight)}`
                  }
                }
                MouseArea {
                  id: dragArea

                  readonly property bool editable: MonitorService.supportsControl("position")

                  anchors.fill: parent
                  cursorShape: editable ? Qt.SizeAllCursor : Qt.PointingHandCursor
                  enabled: !MonitorService.busy && !outputPreview.displayBusy && (!root.previewActive || root.isPreviewing(outputPreview.name)) && !root.preview?.applying
                  hoverEnabled: true
                  preventStealing: true

                  onPressed: mouse => {
                    root.selectedMonitor = outputPreview.name;
                    if (!editable)
                      return;
                    outputPreview.dragStartPoint = outputPreview.mapToItem(arrangementCanvas, mouse.x, mouse.y);
                    outputPreview.dragStartPosition = { x: outputPreview.effectivePosition.x, y: outputPreview.effectivePosition.y };
                    outputPreview.dragPosition = { x: outputPreview.effectivePosition.x, y: outputPreview.effectivePosition.y };
                  }
                  onPositionChanged: mouse => {
                    if (!pressed || !editable)
                      return;
                    const point = outputPreview.mapToItem(arrangementCanvas, mouse.x, mouse.y);
                    const requested = {
                      x: outputPreview.dragStartPosition.x + (point.x - outputPreview.dragStartPoint.x) / arrangementCanvas.arrangementScale,
                      y: outputPreview.dragStartPosition.y + (point.y - outputPreview.dragStartPoint.y) / arrangementCanvas.arrangementScale
                    };
                    outputPreview.dragPosition = MonitorService.snapMonitorPosition(outputPreview.name, requested, outputPreview.outputLogicalWidth, outputPreview.outputLogicalHeight, Theme.spacingLg / arrangementCanvas.arrangementScale);
                  }
                  onReleased: {
                    if (!editable)
                      return;
                    const target = outputPreview.dragPosition ?? outputPreview.effectivePosition;
                    outputPreview.dragPosition = null;
                    outputPreview.dragStartPosition = null;
                    if (Math.round(target.x) === Math.round(outputPreview.effectivePosition.x) && Math.round(target.y) === Math.round(outputPreview.effectivePosition.y))
                      return;
                    root.previewConfig(outputPreview.name, {
                      position: { x: outputPreview.logicalX, y: outputPreview.logicalY },
                      transform: outputPreview.transformMode
                    }, { position: target });
                  }
                }
              }
            }
            ColumnLayout {
              anchors.centerIn: parent
              spacing: Theme.spacingXs
              visible: MonitorService.monitors.count === 0

              OText {
                Layout.alignment: Qt.AlignHCenter
                color: Theme.textInactiveColor
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSizeXl
                text: "󰍹"
              }
              OText {
                Layout.alignment: Qt.AlignHCenter
                color: Theme.textInactiveColor
                text: qsTr("No displays detected")
              }
            }
          }
        }
      }
      PanelCard {
        id: controlsCard
        Layout.fillWidth: true
        implicitHeight: displayLayout.implicitHeight + padding * 2
        visible: root.selectedMonitorData !== null

        ColumnLayout {
          id: displayLayout

          anchors.fill: parent
          spacing: Theme.spacingSm

          PanelHeader {
            icon: "󰍹"
            subtitle: [
              root.selectedMonitorData?.displayModel ? root.selectedMonitorData?.name : qsTr("Connected display"),
              root.modeLabel(root.selectedMonitorData?.currentModeKey ?? ""),
              qsTr("%1% scale").arg(Math.round((root.selectedMonitorData?.displayScale ?? 1) * 100)),
              MonitorService.monitors.count > 1 ? qsTr("Position %1, %2").arg(Math.round(root.selectedMonitorData?.logicalX ?? 0)).arg(Math.round(root.selectedMonitorData?.logicalY ?? 0)) : ""
            ].filter(Boolean).join(" · ")
            title: root.selectedMonitorData?.displayModel || root.selectedMonitorData?.name || ""

            OSpinner {
              running: root.selectedMonitorData?.displayBusy ?? false
            }
            OComboBox {
              implicitWidth: Theme.wallpaperSidebarWidth
              currentIndex: root.selectedNumber - 1
              enabled: !root.previewActive && !MonitorService.busy
              model: root.monitorOptions
              textRole: "label"
              visible: root.monitorOptions.length > 1

              onActivated: index => root.selectedMonitor = root.monitorOptions[index]?.value ?? root.selectedMonitor
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXs

            InfoBadge {
              badgeColor: root.selectedMonitorData?.vrrMode === "off" ? Theme.glassControlColor : Theme.activeColor
              text: qsTr("VRR · %1").arg(root.vrrLabel(root.selectedMonitorData?.vrrMode ?? "off"))
              visible: root.selectedMonitorData?.vrrSupported ?? false
            }
            InfoBadge {
              text: Number.isFinite(root.selectedMonitorData?.maxBpc) ? qsTr("%1 bpc").arg(root.selectedMonitorData.maxBpc) : ""
              visible: Number.isFinite(root.selectedMonitorData?.maxBpc) && !root.isIccActive
            }
            InfoBadge {
              badgeColor: root.isIccActive ? Theme.warning : Theme.activeColor
              text: root.isIccActive ? qsTr("ICC Active") : root.colorModeLabel(root.selectedMonitorData?.colorMode ?? "srgb")
              visible: root.isIccActive || (root.selectedMonitorData?.hdrSupported ?? false)
            }
            Item {
              Layout.fillWidth: true
            }
          }
          PanelCard {
            Layout.fillWidth: true
            tone: "error"
            visible: (root.selectedMonitorData?.errorText ?? "") !== ""

            OText {
              width: parent?.width ?? 0
              color: Theme.critical
              text: root.selectedMonitorData?.errorText ?? ""
              wrapMode: Text.Wrap
            }
          }
          OText {
            Layout.fillWidth: true
            color: Theme.textInactiveColor
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Display controls are not available on this compositor yet.")
            visible: MonitorService.controls.length === 0
            wrapMode: Text.Wrap
          }
          ColumnLayout {
            Layout.fillWidth: true
            enabled: !MonitorService.busy && !(root.selectedMonitorData?.displayBusy ?? false)
            opacity: enabled ? 1 : Theme.opacityDisabled
            spacing: Theme.spacingXs

            ComboRow {
              Layout.fillWidth: true
              currentIndex: root.optionIndex(root.modeOptions, root.previewValue(root.selectedMonitor, "mode", root.selectedMonitorData?.currentModeKey))
              inputEnabled: root.previewEditable
              options: root.modeOptions
              subtitle: qsTr("Resolution and refresh rate")
              title: qsTr("Display mode")
              visible: MonitorService.supportsControl("mode") && root.modeOptions.length > 0

              onOptionActivated: index => root.applyValue("mode", root.modeOptions[index]?.value)
            }
            PanelRow {
              Layout.fillWidth: true
              rowActionEnabled: false
              subtitle: qsTr("Size of text and interface elements")
              title: qsTr("Scale")
              visible: MonitorService.supportsControl("scale") && root.scaleValues.length > 0

              actions: [
                Item {
                  implicitHeight: Theme.controlHeightSm
                  implicitWidth: Theme.wallpaperSidebarWidth

                  RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingSm

                    Slider {
                      id: scaleSlider

                      readonly property real effectiveScale: root.previewValue(root.selectedMonitor, "scale", root.selectedMonitorData?.displayScale ?? 1)

                      Layout.fillWidth: true
                      Layout.preferredHeight: Theme.controlHeightSm
                      interactive: root.previewEditable
                      steps: root.scaleSteps
                      value: root.scaleToSlider(effectiveScale)
                      wheelStep: 1 / root.scaleSteps

                      onCommitted: value => {
                        root.applyValue("scale", root.scaleFromSlider(value));
                        scaleSlider.value = Qt.binding(() => root.scaleToSlider(scaleSlider.effectiveScale));
                      }
                    }
                    OText {
                      color: Theme.activeColor
                      text: qsTr("%1%").arg(Math.round(scaleSlider.effectiveScale * 100))
                    }
                  }
                }
              ]
            }
            ComboRow {
              Layout.fillWidth: true
              currentIndex: root.optionIndex(root.transformOptions, root.previewValue(root.selectedMonitor, "transform", root.selectedMonitorData?.transformMode))
              inputEnabled: root.previewEditable
              options: root.transformOptions
              subtitle: qsTr("Rotate or flip this display")
              title: qsTr("Orientation")
              visible: MonitorService.supportsControl("transform")

              onOptionActivated: index => root.applyValue("transform", root.transformOptions[index]?.value)
            }
            ComboRow {
              Layout.fillWidth: true
              currentIndex: root.optionIndex(root.vrrOptions, root.selectedMonitorData?.vrrMode)
              inputEnabled: !root.previewActive
              options: root.vrrOptions
              subtitle: qsTr("Reduce tearing on compatible content")
              title: qsTr("Variable refresh rate")
              visible: MonitorService.supportsControl("vrrMode") && (root.selectedMonitorData?.vrrSupported ?? false)

              onOptionActivated: index => root.applyValue("vrrMode", root.vrrOptions[index]?.value)
            }

            // Custom ICC Profile Gatekeeper Toggle (on top of moving parts)
            PanelRow {
              Layout.fillWidth: true
              rowActionEnabled: false
              subtitle: root.isIccActive ? qsTr("Using a custom .icc / .icm calibration profile") : qsTr("Enable to load custom .icc file instead of hardware HDR")
              title: qsTr("Custom ICC profile")
              visible: MonitorService.supportsControl("icc")

              actions: [
                OToggle {
                  checked: root.isIccActive
                  disabled: root.previewActive

                  onToggled: checked => {
                    root._iccToggled = checked;
                    if (!checked) {
                      if (root.selectedMonitorData?.iccProfile)
                        root._lastIccPath = root.selectedMonitorData.iccProfile;
                      root.applyValue("icc", "");
                    } else {
                      const target = root.savedIccPath || iccInput.text.trim();
                      if (target && target.startsWith("/")) {
                        root._lastIccPath = target;
                        root.applyValue("icc", target);
                      }
                    }
                  }
                }
              ]
            }

            // Dynamic Moving Parts Stack Below Toggle:
            // 1. Hardware Color / HDR Controls (When ICC is OFF)
            ComboRow {
              Layout.fillWidth: true
              currentIndex: root.optionIndex(root.colorModeOptions, root.selectedMonitorData?.colorMode)
              inputEnabled: !root.previewActive
              options: root.colorModeOptions
              subtitle: qsTr("SDR sRGB or HDR (PQ / EDID passthrough)")
              title: qsTr("Color mode & HDR")
              visible: !root.isIccActive && MonitorService.supportsControl("colorMode") && (root.selectedMonitorData?.hdrSupported ?? false)

              onOptionActivated: index => root.applyValue("colorMode", root.colorModeOptions[index]?.value)
            }
            ComboRow {
              Layout.fillWidth: true
              currentIndex: root.optionIndex(root.maxBpcOptions, root.selectedMonitorData?.maxBpc)
              inputEnabled: !root.previewActive
              options: root.maxBpcOptions
              subtitle: qsTr("Colour precision sent to the panel")
              title: qsTr("Bit depth")
              visible: !root.isIccActive && MonitorService.supportsControl("maxBpc") && root.maxBpcOptions.length > 1

              onOptionActivated: index => root.applyValue("maxBpc", root.maxBpcOptions[index]?.value)
            }
            PanelRow {
              Layout.fillWidth: true
              rowActionEnabled: false
              subtitle: qsTr("SDR content brightness in HDR mode")
              title: qsTr("SDR brightness")
              visible: !root.isIccActive && root.hdrOn && MonitorService.supportsControl("sdrBrightness")

              actions: [
                Item {
                  implicitHeight: Theme.controlHeightSm
                  implicitWidth: Theme.wallpaperSidebarWidth

                  RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingSm

                    Slider {
                      id: sdrBrightnessSlider

                      readonly property real effectiveVal: root.selectedMonitorData?.sdrBrightness ?? 1.0

                      Layout.fillWidth: true
                      Layout.preferredHeight: Theme.controlHeightSm
                      interactive: root.previewEditable
                      steps: 15
                      value: Math.max(0, Math.min(1, (effectiveVal - 0.5) / 1.5))

                      onCommitted: value => root.applyValue("sdrBrightness", Math.round((0.5 + value * 1.5) * 100) / 100)
                    }
                    OText {
                      color: Theme.activeColor
                      text: qsTr("%1%").arg(Math.round(sdrBrightnessSlider.effectiveVal * 100))
                    }
                  }
                }
              ]
            }
            PanelRow {
              Layout.fillWidth: true
              rowActionEnabled: false
              subtitle: qsTr("SDR color vibrancy in HDR mode")
              title: qsTr("SDR saturation")
              visible: !root.isIccActive && root.hdrOn && MonitorService.supportsControl("sdrSaturation")

              actions: [
                Item {
                  implicitHeight: Theme.controlHeightSm
                  implicitWidth: Theme.wallpaperSidebarWidth

                  RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingSm

                    Slider {
                      id: sdrSaturationSlider

                      readonly property real effectiveVal: root.selectedMonitorData?.sdrSaturation ?? 1.0

                      Layout.fillWidth: true
                      Layout.preferredHeight: Theme.controlHeightSm
                      interactive: root.previewEditable
                      steps: 15
                      value: Math.max(0, Math.min(1, (effectiveVal - 0.5) / 1.5))

                      onCommitted: value => root.applyValue("sdrSaturation", Math.round((0.5 + value * 1.5) * 100) / 100)
                    }
                    OText {
                      color: Theme.activeColor
                      text: qsTr("%1%").arg(Math.round(sdrSaturationSlider.effectiveVal * 100))
                    }
                  }
                }
              ]
            }

            // 2. Custom ICC Profile Path & Warning Alert (When ICC is ON)
            PanelRow {
              Layout.fillWidth: true
              rowActionEnabled: false
              subtitle: qsTr("Absolute path; leave empty to disable")
              title: qsTr("ICC profile path")
              visible: root.isIccActive && MonitorService.supportsControl("icc")

              actions: [
                Item {
                  implicitHeight: iccInput.implicitHeight
                  implicitWidth: Theme.wallpaperSidebarWidth * 1.6

                  RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingSm

                    OInput {
                      id: iccInput

                      Layout.fillWidth: true
                      enabled: !root.previewActive
                      errorMessage: qsTr("Use an absolute path")
                      hasError: text.trim() !== "" && !text.trim().startsWith("/")
                      placeholderText: qsTr("/path/to/display.icc")
                      text: root.savedIccPath

                      onInputAccepted: root.applyIcc(iccInput)
                    }
                    OButton {
                      isEnabled: !root.previewActive && !iccInput.hasError && iccInput.text.trim() !== (root.selectedMonitorData?.iccProfile ?? "")
                      text: qsTr("Save")

                      onClicked: root.applyIcc(iccInput)
                    }
                  }
                }
              ]
            }
            PanelCard {
              Layout.fillWidth: true
              padding: Theme.spacingSm
              tone: "warning"
              visible: root.isIccActive

              RowLayout {
                anchors.fill: parent
                spacing: Theme.spacingSm

                OText {
                  Layout.alignment: Qt.AlignVCenter
                  color: Theme.warning
                  font.family: Theme.iconFontFamily
                  font.pixelSize: Theme.iconSizeMd
                  text: "󰀪"
                }
                OText {
                  Layout.alignment: Qt.AlignVCenter
                  Layout.fillWidth: true
                  color: Theme.warning
                  size: "xs"
                  text: root.hasIccProfile ? qsTr("Hardware HDR modes and PQ color mapping are disabled while custom ICC profile (%1) is loaded.").arg(root.selectedMonitorData?.iccProfile ?? "") : root.savedIccPath ? qsTr("Saved ICC profile (%1) will be applied when enabled.").arg(root.savedIccPath) : qsTr("Enter an absolute path to a .icc / .icm file above and click Save to apply.")
                  wrapMode: Text.Wrap
                }
                OButton {
                  Layout.alignment: Qt.AlignVCenter
                  isEnabled: !root.previewActive
                  text: qsTr("Disable & Use HDR")
                  variant: "secondary"

                  onClicked: {
                    root._iccToggled = false;
                    root.applyValue("icc", "");
                  }
                }
              }
            }
          }
          RowLayout {
            Layout.fillWidth: true
            visible: MonitorService.controls.length > 0

            OText {
              Layout.fillWidth: true
              color: Theme.textInactiveColor
              size: "xs"
              text: qsTr("Settings are saved for this display on this machine.")
            }
            OButton {
              isEnabled: !MonitorService.busy && !root.previewActive
              text: qsTr("Restore defaults")
              variant: "secondary"

              onClicked: {
                root._lastIccPath = "";
                root._iccToggled = false;
                MonitorService.resetMonitorConfig(root.selectedMonitor);
              }
            }
          }
        }
      }
      Item {
        Layout.preferredHeight: Theme.spacingXs
      }
    }
  }
  PanelCard {
    id: previewBar

    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    tone: "warning"
    visible: root.previewActive
    z: 1

    RowLayout {
      anchors.fill: parent
      spacing: Theme.spacingMd

      OText {
        Layout.fillWidth: true
        text: root.preview?.applying ? qsTr("Applying display preview…") : qsTr("Keep these display settings? Reverting in %1 seconds.").arg(root.previewSecondsRemaining)
        wrapMode: Text.Wrap
      }
      OButton {
        isEnabled: !root.preview?.applying
        text: qsTr("Revert")
        variant: "secondary"

        onClicked: root.revertPreview()
      }
      OButton {
        isEnabled: !root.preview?.applying
        text: qsTr("Keep")

        onClicked: root.confirmPreview()
      }
    }
  }
}
