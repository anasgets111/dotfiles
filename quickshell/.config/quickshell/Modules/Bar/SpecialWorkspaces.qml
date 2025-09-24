pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.WM
import qs.Components

RowLayout {
  id: specialWorkspaces

  // New helper: capitalize only the first letter of a string
  function capitalizeFirstLetter(s) {
    if (!s)
      return "";
    return s.charAt(0).toUpperCase() + s.slice(1);
  }
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

      readonly property bool isActive: (cell.workspace?.name || "") === WorkspaceService.activeSpecial
      readonly property string labelText: specialWorkspaces.getSpecialLabelByName(cell.workspace?.name)

      // modelData can be null briefly during Hyprland workspace updates. Default to {} to avoid TypeErrors.
      required property var modelData
      property var workspace: (cell.modelData || ({}))

      Layout.alignment: Qt.AlignVCenter
      Layout.preferredHeight: implicitHeight
      Layout.preferredWidth: implicitWidth
      implicitHeight: Theme.itemHeight
      implicitWidth: Theme.itemHeight
      // Extra guard: ensure we only show valid special entries
      visible: (workspace && typeof workspace.id === "number" && workspace.id < 0)

      IconButton {
        id: button
        anchors.fill: parent
        colorBg: cell.isActive ? Theme.activeColor : Theme.inactiveColor
        icon: cell.labelText
        tooltipText: specialWorkspaces.capitalizeFirstLetter((cell.workspace?.name || "").replace("special:", ""))
        onLeftClicked: {
          const n = (cell.workspace?.name || "").replace("special:", "");
          WorkspaceService.toggleSpecial(n);
        }
      }
    }
  }
  Repeater {
    delegate: specialDelegate
    model: WorkspaceService.specialWorkspaces
  }
}
