pragma ComponentBehavior: Bound
import QtQuick
import qs.Config
import qs.Services.WM
import qs.Widgets

Row {
  id: specialWorkspaces

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
    // Fallback: first 2 letters uppercased, trimmed to 2 chars
    const t = (wsName || "").replace("special:", "").trim();
    return t.length > 2 ? t.slice(0, 2).toUpperCase() : t.toUpperCase();
  }

  spacing: 8

  Component {
    id: specialDelegate

    Item {
      id: cell

      readonly property bool isActive: workspace.name === WorkspaceService.activeSpecial
      readonly property string labelText: specialWorkspaces.getSpecialLabelByName(workspace.name)
      required property var modelData
      property var workspace: cell.modelData

      implicitHeight: Theme.itemHeight
      implicitWidth: Theme.itemHeight
      visible: workspace.id < 0

      IconButton {
        id: button

        anchors.fill: parent
        bgColor: cell.isActive ? Theme.activeColor : Theme.inactiveColor

        contentItem: Text {
          anchors.centerIn: parent
          color: Theme.textContrast(button.effectiveBg)
          font.pixelSize: Theme.fontSize
          text: cell.labelText
        }

        onLeftClicked: {
          const n = (cell.workspace.name || "").replace("special:", "");
          WorkspaceService.toggleSpecial(n);
        }
      }
      Tooltip {
        edge: Qt.BottomEdge
        hoverSource: button.area
        target: button
        text: (cell.workspace.name || "").replace("special:", "")
      }
    }
  }
  Repeater {
    delegate: specialDelegate
    model: WorkspaceService.specialWorkspaces
  }
}
