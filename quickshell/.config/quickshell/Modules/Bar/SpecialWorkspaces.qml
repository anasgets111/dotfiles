pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.WM
import qs.Components

RowLayout {
  id: root

  spacing: 8

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
    const t = (wsName || "").replace("special:", "").trim();
    return t.length > 2 ? t.slice(0, 2).toUpperCase() : t.toUpperCase();
  }

  Component {
    id: specialDelegate

    Item {
      id: cell

      required property var modelData
      property var workspace: modelData || {}
      readonly property bool isActive: (cell.workspace?.name || "") === WorkspaceService.activeSpecial
      readonly property string labelText: root.getSpecialLabelByName(cell.workspace?.name)

      Layout.alignment: Qt.AlignVCenter
      Layout.preferredHeight: implicitHeight
      Layout.preferredWidth: implicitWidth
      implicitHeight: Theme.itemHeight
      implicitWidth: Theme.itemHeight
      visible: workspace && typeof workspace.id === "number" && workspace.id < 0

      IconButton {
        id: button
        anchors.fill: parent
        colorBg: cell.isActive ? Theme.activeColor : Theme.inactiveColor
        icon: cell.labelText
        tooltipText: root.capitalizeFirstLetter((cell.workspace?.name || "").replace("special:", ""))
        onClicked: {
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
