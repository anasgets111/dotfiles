pragma ComponentBehavior: Bound
import QtQuick
import qs.Config
import qs.Services.WM

Row {
  id: specialWorkspaces

  // Active special name from Hyprland events (empty means none)
  readonly property string activeSpecial: WorkspaceService.activeSpecial || ""

  // Cache labels for width calculation
  readonly property var labels: (function () {
      const arr = specialWorkspaces.specials;
      const out = new Array(arr.length);
      for (var i = 0; i < arr.length; ++i)
        out[i] = specialWorkspaces.getSpecialLabelByName(arr[i].name);
      return out;
    })()

  // Max width among specials (label width + 12), min Theme.itemWidth
  readonly property int maxSpecialWidth: (function () {
      const c = measurer.children;
      var maxW = Theme.itemWidth;
      for (var i = 0; i < c.length; ++i) {
        const w = c[i].implicitWidth + 12;
        if (w > maxW)
          maxW = w;
      }
      return maxW;
    })()

  // Derived: list of special workspaces (id < 0)
  readonly property var specials: WorkspaceService.specialWorkspaces

  // Source data from service
  readonly property var workspaces: WorkspaceService.workspaces

  // Label mapping (icons) and fallback name
  function getSpecialLabelByName(wsName) {
    const nameLower = (wsName || "").toLowerCase();
    if (nameLower.indexOf("telegram") !== -1)
      return "\uF2C6";
    if (nameLower.indexOf("slack") !== -1)
      return "\uF3EF";
    if (nameLower.indexOf("discord") !== -1 || nameLower.indexOf("vesktop") !== -1 || nameLower.indexOf("string") !== -1)
      return "\uF392";
    if (nameLower.indexOf("term") !== -1 || nameLower.indexOf("magic") !== -1)
      return "\uF120";
    return (wsName || "").replace("special:", "");
  }

  spacing: 8

  // Hidden measurer: one Text per label to compute implicitWidth
  Item {
    id: measurer

    visible: false

    Repeater {
      model: specialWorkspaces.labels

      delegate: Text {
        id: probe

        required property var modelData

        font.bold: true
        font.family: (probe.text.length === 1 ? "Nerd Font" : Theme.fontFamily)
        font.pixelSize: Theme.fontSize
        text: probe.modelData
      }
    }
  }
  Component {
    id: specialDelegate

    Rectangle {
      id: cell

      required property int index
      readonly property bool isActive: cell.ws.name === specialWorkspaces.activeSpecial
      property bool isHovered: false
      readonly property int labelIndex: (function () {
          const arr = specialWorkspaces.specials;
          for (var i = 0; i < arr.length; ++i)
            if (arr[i].name === cell.ws.name)
              return i;
          return -1;
        })()
      readonly property string labelText: specialWorkspaces.getSpecialLabelByName(cell.ws.name)
      required property var modelData
      property var ws: cell.modelData

      color: cell.isActive ? Theme.activeColor : (cell.isHovered ? Theme.onHoverColor : Theme.inactiveColor)
      height: Theme.itemHeight
      radius: Theme.itemRadius
      visible: cell.ws.id < 0
      width: (cell.labelIndex >= 0 && measurer.children[cell.labelIndex]) ? measurer.children[cell.labelIndex].implicitWidth + 12 : Theme.itemWidth

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
          easing.type: Easing.InOutQuad
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: {
          const n = (cell.ws.name || "").replace("special:", "");
          WorkspaceService.toggleSpecial(n);
        }
        onEntered: cell.isHovered = true
        onExited: cell.isHovered = false
      }
      Text {
        id: label

        anchors.centerIn: parent
        color: Theme.textContrast(cell.isActive ? Theme.activeColor : (cell.isHovered ? Theme.onHoverColor : Theme.inactiveColor))
        font.bold: true
        font.family: (label.text.length === 1 ? "Nerd Font" : Theme.fontFamily)
        font.pixelSize: Theme.fontSize
        text: cell.labelText

        Behavior on color {
          ColorAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }
      }
    }
  }
  Repeater {
    delegate: specialDelegate
    model: specialWorkspaces.workspaces
  }
}
