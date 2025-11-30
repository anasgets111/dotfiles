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

  function getIcon(name) {
    const lower = name.toLowerCase();
    for (const key in iconMap)
      if (lower.includes(key))
        return iconMap[key];
    return name.length > 2 ? name.slice(0, 2).toUpperCase() : name.toUpperCase();
  }

  spacing: 8

  Repeater {
    model: WorkspaceService.specialWorkspaces

    delegate: IconButton {
      required property var modelData
      readonly property string cleanName: (modelData?.name ?? "").replace("special:", "")
      readonly property bool isActive: modelData?.name === WorkspaceService.activeSpecial

      Layout.alignment: Qt.AlignVCenter
      Layout.preferredHeight: Theme.itemHeight
      Layout.preferredWidth: Theme.itemHeight
      colorBg: isActive ? Theme.activeColor : Theme.inactiveColor
      icon: root.getIcon(cleanName)
      tooltipText: cleanName.charAt(0).toUpperCase() + cleanName.slice(1)

      onClicked: WorkspaceService.toggleSpecial(cleanName)
    }
  }
}
