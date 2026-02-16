pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.Config

PanelContentBase {
  id: root

  readonly property var menuItem: panelData?.menuItem ?? null
  readonly property real preferredHeight: menuContent.implicitHeight + Theme.spacingSm * 2
  readonly property real preferredWidth: 300

  QsMenuOpener {
    id: menuOpener

    menu: root.menuItem?.menu ?? null
  }

  ColumnLayout {
    id: menuContent

    anchors.fill: parent
    anchors.margins: Theme.spacingSm
    spacing: Theme.spacingXs / 2

    Repeater {
      id: menuRepeater

      model: menuOpener.children ?? []

      delegate: Item {
        id: menuEntry

        readonly property bool isSeparator: modelData.isSeparator
        readonly property bool itemEnabled: modelData.enabled
        required property QsMenuEntry modelData

        Layout.fillWidth: true
        Layout.preferredHeight: isSeparator ? 8 : Theme.itemHeight

        Rectangle {
          anchors.centerIn: parent
          color: Theme.borderColor
          height: 1
          visible: menuEntry.isSeparator
          width: parent.width - Theme.spacingSm
        }

        Rectangle {
          anchors.fill: parent
          color: entryMouse.containsMouse ? Theme.onHoverColor : "transparent"
          radius: Theme.itemRadius
          visible: !menuEntry.isSeparator

          OText {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingMd
            anchors.rightMargin: Theme.spacingMd
            color: Theme.textContrast(parent.color)
            elide: Text.ElideRight
            opacity: menuEntry.itemEnabled ? 1.0 : 0.5
            text: menuEntry.modelData.text ?? ""
            verticalAlignment: Text.AlignVCenter
          }

          MouseArea {
            id: entryMouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: menuEntry.itemEnabled
            hoverEnabled: true

            onClicked: {
              menuEntry.modelData.triggered();
              root.closeRequested();
            }
          }
        }
      }
    }

    OText {
      Layout.fillWidth: true
      Layout.preferredHeight: Theme.itemHeight
      color: Theme.textActiveColor
      horizontalAlignment: Text.AlignHCenter
      text: "No menu items"
      verticalAlignment: Text.AlignVCenter
      visible: menuRepeater.count === 0
    }
  }
}
