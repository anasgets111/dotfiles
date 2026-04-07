pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services.Utils

Singleton {
  id: root

  readonly property var _keyNames: ({
      KEY_APOSTROPHE: "'",
      KEY_LEFTALT: "Alt",
      KEY_RIGHTALT: "Alt",
      KEY_BACKSPACE: "Backspace",
      KEY_BACKSLASH: "\\",
      KEY_CAPSLOCK: "Caps",
      KEY_COMMA: ",",
      KEY_DELETE: "Del",
      KEY_DOT: ".",
      KEY_DOWN: "Down",
      KEY_END: "End",
      KEY_ENTER: "Enter",
      KEY_EQUAL: "=",
      KEY_ESC: "Esc",
      KEY_GRAVE: "`",
      KEY_HOME: "Home",
      KEY_INSERT: "Ins",
      KEY_LEFT: "Left",
      KEY_LEFTBRACE: "[",
      KEY_LEFTCTRL: "Ctrl",
      KEY_LEFTMETA: "Super",
      KEY_LEFTSHIFT: "Shift",
      KEY_MENU: "Menu",
      KEY_MINUS: "-",
      KEY_PAGEDOWN: "PgDn",
      KEY_PAGEUP: "PgUp",
      KEY_PRINT: "Print",
      KEY_RIGHT: "Right",
      KEY_RIGHTBRACE: "]",
      KEY_RIGHTCTRL: "Ctrl",
      KEY_RIGHTMETA: "Super",
      KEY_RIGHTSHIFT: "Shift",
      KEY_SEMICOLON: ";",
      KEY_SLASH: "/",
      KEY_SPACE: "Space",
      KEY_TAB: "Tab",
      KEY_UP: "Up"
    })
  readonly property var _modifierOrder: ({
      Ctrl: 0,
      Shift: 1,
      Alt: 2,
      Super: 3
    })
  readonly property var _mouseNames: ({
      BTN_BACK: "Mouse4",
      BTN_EXTRA: "Mouse5",
      BTN_FORWARD: "Mouse5",
      BTN_LEFT: "LMB",
      BTN_MIDDLE: "MMB",
      BTN_RIGHT: "RMB",
      BTN_SIDE: "Mouse4"
    })
  readonly property var _mouseOrder: ({
      LMB: 0,
      RMB: 1,
      MMB: 2,
      Mouse4: 3,
      Mouse5: 4
    })
  readonly property var _printableSymbols: ({
      "'": true,
      ",": true,
      "-": true,
      ".": true,
      "/": true,
      ";": true,
      "=": true,
      "Space": true,
      "[": true,
      "\\": true,
      "]": true,
      "`": true
    })
  readonly property var _wheelNames: ({
      REL_HWHEEL_LEFT: "WheelLeft",
      REL_HWHEEL_RIGHT: "WheelRight",
      REL_WHEEL_DOWN: "WheelDown",
      REL_WHEEL_UP: "WheelUp",
      WHEEL_DOWN: "WheelDown",
      WHEEL_LEFT: "WheelLeft",
      WHEEL_RIGHT: "WheelRight",
      WHEEL_UP: "WheelUp"
    })
  property var activeKeys: []
  property var activeMouseButtons: []
  readonly property string backend: "showmethekey-cli"
  property bool backendAvailable: false
  readonly property string comboDisplayLabel: comboLabel.length > 0 ? (comboRepeatCount > 1 ? `${comboLabel} ×${comboRepeatCount}` : comboLabel) : ""
  property string comboLabel: ""
  property int comboRepeatCount: 0
  readonly property bool enabled: Settings.data?.inputDisplay?.enabled ?? false
  property bool overlayHovered: false
  readonly property real positionXRatio: root.validRatio(Settings.data?.inputDisplay?.positionXRatio) ? Settings.data.inputDisplay.positionXRatio : 0.06
  readonly property real positionYRatio: root.validRatio(Settings.data?.inputDisplay?.positionYRatio) ? Settings.data.inputDisplay.positionYRatio : 0.74
  property var retainedKeys: []
  property var retainedMouseButtons: []
  readonly property bool showPrintableKeys: Settings.data?.inputDisplay?.showPrintableKeys ?? false
  readonly property bool visible: enabled && (comboLabel.length > 0 || visibleKeys.length > 0 || visibleMouseButtons.length > 0)
  readonly property var visibleKeys: activeKeys.length > 0 ? activeKeys : retainedKeys
  readonly property var visibleMouseButtons: activeMouseButtons.length > 0 ? activeMouseButtons : retainedMouseButtons

  function clearState(): void {
    activeKeys = [];
    activeMouseButtons = [];
    retainedKeys = [];
    retainedMouseButtons = [];
    comboLabel = "";
    comboRepeatCount = 0;
  }

  function handleBackendLine(line: string): void {
    const raw = String(line ?? "").trim();
    const jsonStart = raw.indexOf("{");
    if (jsonStart < 0)
      return;

    try {
      root.handleEvent(JSON.parse(raw.slice(jsonStart)));
    } catch (error) {
      Logger.warn("InputDisplayService", `Parse error: ${error}`);
    }
  }

  function handleEvent(event: var): void {
    const eventName = String(event?.event_name ?? "").trim().toUpperCase();
    const rawName = String(event?.key_name ?? "").trim().toUpperCase();
    const pressed = String(event?.state_name ?? "").trim().toUpperCase() !== "RELEASED";

    if (eventName === "KEYBOARD_KEY") {
      root.handleKeyboardEvent(rawName, pressed);
      return;
    }

    if (eventName === "POINTER_BUTTON") {
      root.handlePointerButton(rawName, pressed);
      return;
    }

    root.handlePointerPulse(rawName);
  }

  function handleKeyboardEvent(rawName: string, pressed: bool): void {
    const label = root.normalizeKeyboardKey(rawName);
    if (!label)
      return;

    if (root.isModifierKey(label)) {
      activeKeys = root.updatedList(activeKeys, label, pressed, root._modifierOrder);
      return;
    }

    if (!pressed)
      return;

    if (activeKeys.length === 0 && root.isPrintableKey(label) && !root.showPrintableKeys)
      return;

    root.showCombo(label);
  }

  function handlePointerButton(rawName: string, pressed: bool): void {
    const label = root._mouseNames[rawName] ?? "";
    if (!label)
      return;

    activeMouseButtons = root.updatedList(activeMouseButtons, label, pressed, root._mouseOrder);

    if (pressed)
      root.showCombo(label);
  }

  function handlePointerPulse(rawName: string): void {
    const label = root._wheelNames[rawName] ?? "";
    if (!label)
      return;

    root.showCombo(label);
  }

  function isModifierKey(label: string): bool {
    return root._modifierOrder[label] !== undefined;
  }

  function isPrintableKey(label: string): bool {
    if (/^[A-Z]$/.test(label) || /^[0-9]$/.test(label))
      return true;

    return root._printableSymbols[label] ?? false;
  }

  function normalizeKeyboardKey(rawName: string): string {
    if (root._keyNames[rawName])
      return root._keyNames[rawName];

    if (rawName.startsWith("KEY_F"))
      return rawName.substring(4);

    if (!rawName.startsWith("KEY_"))
      return "";

    const shortName = rawName.substring(4);
    if (/^[A-Z]$/.test(shortName) || /^[0-9]$/.test(shortName))
      return shortName;

    if (/^KP[0-9]$/.test(shortName))
      return shortName.substring(2);

    return "";
  }

  function orderedTokens(values: var, order: var): var {
    return values.slice().sort((left, right) => {
      const leftOrder = order[left] ?? 99;
      const rightOrder = order[right] ?? 99;
      if (leftOrder !== rightOrder)
        return leftOrder - rightOrder;
      return String(left).localeCompare(String(right));
    });
  }

  function persistPositionRatios(xRatio: real, yRatio: real): void {
    if (!Settings.data?.inputDisplay)
      return;
    Settings.data.inputDisplay.positionXRatio = root.sanitizeRatio(xRatio, 0.06);
    Settings.data.inputDisplay.positionYRatio = root.sanitizeRatio(yRatio, 0.74);
  }

  function refreshBackendAvailability(): void {
    backendCheckProcess.running = false;
    backendCheckProcess.running = true;
  }

  function sanitizeRatio(value: real, fallback: real): real {
    const num = Number(value);
    if (!Number.isFinite(num))
      return fallback;
    return Math.max(0, Math.min(1, num));
  }

  function setEnabled(value: bool): void {
    if (!Settings.data?.inputDisplay)
      return;
    Settings.data.inputDisplay.enabled = !!value;
  }

  function setShowPrintableKeys(value: bool): void {
    if (!Settings.data?.inputDisplay)
      return;
    Settings.data.inputDisplay.showPrintableKeys = !!value;
  }

  function showCombo(label: string): void {
    const nextLabel = [...root.activeKeys, label].join("+");
    comboRepeatCount = comboHideTimer.running && comboLabel === nextLabel ? comboRepeatCount + 1 : 1;
    comboLabel = nextLabel;
    comboHideTimer.restart();
  }

  function syncProcess(): void {
    const shouldRun = enabled && backendAvailable;
    restartTimer.stop();

    if (!shouldRun) {
      inputProcess.running = false;
      return;
    }

    if (!inputProcess.running)
      inputProcess.running = true;
  }

  function syncRetainedState(): void {
    if (activeKeys.length > 0)
      retainedKeys = activeKeys.slice();
    else if (!overlayHovered)
      retainedKeys = [];

    if (activeMouseButtons.length > 0)
      retainedMouseButtons = activeMouseButtons.slice();
    else if (!overlayHovered)
      retainedMouseButtons = [];
  }

  function updatedList(list: var, label: string, pressed: bool, order: var): var {
    const next = list.filter(entry => entry !== label);
    if (pressed)
      next.push(label);
    return root.orderedTokens(next, order);
  }

  function validRatio(value: real): bool {
    const num = Number(value);
    return Number.isFinite(num) && num >= 0 && num <= 1;
  }

  Component.onCompleted: root.refreshBackendAvailability()
  onActiveKeysChanged: root.syncRetainedState()
  onActiveMouseButtonsChanged: root.syncRetainedState()
  onBackendAvailableChanged: {
    if (!backendAvailable)
      clearState();
    syncProcess();
  }
  onEnabledChanged: {
    if (!enabled)
      clearState();
    else if (!backendAvailable)
      refreshBackendAvailability();
    syncProcess();
  }
  onOverlayHoveredChanged: root.syncRetainedState()

  Process {
    id: backendCheckProcess

    command: ["sh", "-c", "command -v showmethekey-cli >/dev/null 2>&1 && printf yes || printf no"]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        const found = String(text ?? "").trim() === "yes";
        root.backendAvailable = found;

        if (!found)
          Logger.warn("InputDisplayService", "showmethekey-cli not found; input display disabled");
      }
    }
  }

  Process {
    id: inputProcess

    command: [root.backend]
    running: false

    stderr: SplitParser {
      splitMarker: "\n"

      onRead: line => {
        const clean = String(line ?? "").trim();
        if (clean.length > 0)
          Logger.warn("InputDisplayService", clean);
      }
    }
    stdout: SplitParser {
      splitMarker: "\n"

      onRead: line => root.handleBackendLine(line)
    }

    onExited: (code, exitStatus) => {
      if (!root.enabled || !root.backendAvailable)
        return;

      if (code !== 0)
        Logger.warn("InputDisplayService", `showmethekey-cli exited with code ${code}`);
    }
    onRunningChanged: {
      if (!inputProcess.running && root.enabled && root.backendAvailable)
        restartTimer.restart();
    }
  }

  Timer {
    id: comboHideTimer

    interval: 850

    onTriggered: {
      if (root.overlayHovered) {
        restart();
        return;
      }
      root.comboLabel = "";
      root.comboRepeatCount = 0;
    }
  }

  Timer {
    id: restartTimer

    interval: 3000

    onTriggered: root.syncProcess()
  }
}
