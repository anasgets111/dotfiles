pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.WM
import qs.Components

RowLayout {
  id: root

  readonly property var iconMap: ({
      telegram: "\uF2C6",
      slack: "\uF3EF",
      discord: "\uF392",
      vesktop: "\uF392",
      string: "\uF392",
      term: "\uF120",
      magic: "\uF120"
    })

  function capitalize(text: string): string {
    return text.length > 0 ? text.charAt(0).toUpperCase() + text.slice(1) : "";
  }

  function getIcon(name: string): string {
    const lower = name.toLowerCase();
    const key = Object.keys(iconMap).find(k => lower.includes(k));
    if (key)
      return iconMap[key];
    return name.length > 2 ? name.slice(0, 2).toUpperCase() : name.toUpperCase();
  }

  spacing: Theme.spacingSm

  Repeater {
    model: WorkspaceService.specialWorkspaces

    delegate: IconButton {
      readonly property string cleanName: (modelData?.name ?? "").replace("special:", "")
      readonly property bool isActive: modelData?.name === WorkspaceService.activeSpecial
      required property var modelData

      Layout.alignment: Qt.AlignVCenter
      Layout.preferredHeight: Theme.itemHeight
      Layout.preferredWidth: Theme.itemHeight
      colorBg: isActive ? Theme.activeColor : Theme.inactiveColor
      icon: root.getIcon(cleanName)
      tooltipText: root.capitalize(cleanName)

      onClicked: WorkspaceService.toggleSpecial(cleanName)
    }
  }
}
