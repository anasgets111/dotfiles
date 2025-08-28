import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Io

Item {
  id: keyboardLayoutIndicator

  property string currentLayout: ""
  readonly property bool hasMultipleLayouts: layouts.length > 1
  property var layouts: []
  readonly property bool useHypr: DetectEnv.isHyprland
  readonly property bool useNiri: DetectEnv.isNiri

  function shortName(full) {
    if (!full)
      return "";

    var lang = full.trim().split(" ")[0];
    return lang.slice(0, 2).toUpperCase();
  }
  function update(namesArr, idxOrActive) {
    var names = namesArr.map(function (n) {
      return n.trim();
    });
    keyboardLayoutIndicator.layouts = names;
    if (keyboardLayoutIndicator.useHypr)
      keyboardLayoutIndicator.currentLayout = String(idxOrActive || "").trim();
    else
      keyboardLayoutIndicator.currentLayout = names[idxOrActive] || "";
  }

  implicitHeight: Theme.itemHeight
  implicitWidth: Math.max(Theme.itemWidth, label.implicitWidth + 12)
  visible: keyboardLayoutIndicator.hasMultipleLayouts

  Process {
    id: seedProcHypr

    command: ["hyprctl", "-j", "devices"]
    running: keyboardLayoutIndicator.useHypr

    stdout: StdioCollector {
      onStreamFinished: {
        if (!keyboardLayoutIndicator.useHypr)
          return;

        var j = JSON.parse(text);
        var arr = [], active = "";
        j.keyboards.forEach(function (k) {
          if (!k.main)
            return;

          k.layout.split(",").forEach(function (l) {
            var t = l.trim();
            if (arr.indexOf(t) === -1)
              arr.push(t);
          });
          active = k.active_keymap;
        });
        keyboardLayoutIndicator.update(arr, active);
      }
    }
  }
  Process {
    id: seedProcNiri

    command: ["niri", "msg", "--json", "keyboard-layouts"]
    running: keyboardLayoutIndicator.useNiri

    stdout: StdioCollector {
      onStreamFinished: {
        var j = JSON.parse(text);
        keyboardLayoutIndicator.update(j.names, j.current_idx);
      }
    }
  }
  Connections {
    function onRawEvent(event) {
      if (!keyboardLayoutIndicator.useHypr)
        return;

      if (event.name !== "activelayout")
        return;

      var parts = event.data.split(",").map(function (t) {
        return t.trim();
      });
      keyboardLayoutIndicator.update(parts, parts[parts.length - 1]);
    }

    enabled: keyboardLayoutIndicator.useHypr
    target: keyboardLayoutIndicator.useHypr ? Hyprland : null
  }
  Process {
    id: eventProcNiri

    command: ["niri", "msg", "--json", "event-stream"]
    running: keyboardLayoutIndicator.useNiri

    stdout: SplitParser {
      splitMarker: "\n"

      onRead: function (segment) {
        if (!segment)
          return;

        var evt = JSON.parse(segment);
        if (evt.KeyboardLayoutsChanged) {
          var kli = evt.KeyboardLayoutsChanged.keyboard_layouts;
          keyboardLayoutIndicator.update(kli.names, kli.current_idx);
        } else if (evt.KeyboardLayoutSwitched) {
          var idx = evt.KeyboardLayoutSwitched.idx;
          if (!keyboardLayoutIndicator.layouts.length)
            return;
          else
            keyboardLayoutIndicator.currentLayout = keyboardLayoutIndicator.layouts[idx] || "";
        }
      }
    }
  }
  Rectangle {
    anchors.fill: parent
    color: Theme.inactiveColor
    radius: Theme.itemRadius

    RowLayout {
      anchors.fill: parent

      Text {
        id: label

        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        color: Theme.textContrast(Theme.inactiveColor)
        font.bold: true
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        text: keyboardLayoutIndicator.shortName(keyboardLayoutIndicator.currentLayout)
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
