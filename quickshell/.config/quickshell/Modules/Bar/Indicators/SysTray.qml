pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.Config
import qs.Components
import qs.Services.UI

Item {
  id: tray

  required property string screenName

  height: Theme.itemHeight
  width: trayRepeater.count === 0 ? emptyLabel.implicitWidth : trayRow.implicitWidth

  Rectangle {
    anchors.fill: parent
    color: Theme.inactiveColor
    radius: Theme.itemRadius
  }
  RowLayout {
    id: trayRow

    anchors.centerIn: parent
    spacing: 0

    Repeater {
      id: trayRepeater

      model: SystemTray.items

      delegate: IconButton {
        id: btn

        required property SystemTrayItem modelData

        Layout.alignment: Qt.AlignVCenter
        icon: ""
        suppressTooltip: ShellUiState.isPanelOpen("tray", tray.screenName) && ShellUiState.panelData?.menuItem === modelData
        tooltipText: modelData && (modelData.tooltipTitle || modelData.title) || ""
        visible: modelData !== null

        onClicked: function (mouse) {
          if (!mouse || !modelData)
            return;
          if (mouse.button === Qt.RightButton && modelData.hasMenu) {
            ShellUiState.togglePanelForItem("tray", tray.screenName, btn, {
              menuItem: modelData
            });
          } else if (mouse.button === Qt.LeftButton) {
            modelData.activate();
          } else {
            modelData.secondaryActivate();
          }
        }

        MouseArea {
          acceptedButtons: Qt.NoButton
          anchors.fill: parent

          onWheel: w => btn.modelData && btn.modelData.scroll(Math.abs(w.angleDelta.y) > Math.abs(w.angleDelta.x) ? w.angleDelta.y : w.angleDelta.x, Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y))
        }
        Item {
          anchors.fill: parent

          IconImage {
            id: iconImage

            anchors.centerIn: parent
            backer.cache: false
            backer.fillMode: Image.PreserveAspectFit
            backer.smooth: true
            backer.sourceSize: Qt.size(Theme.iconSize, Theme.iconSize)
            implicitSize: Theme.iconSize
            source: btn.modelData && btn.modelData.icon || ""
            visible: status !== Image.Error && status !== Image.Null
          }
          OText {
            anchors.centerIn: parent
            bold: true
            color: Theme.textContrast(btn.effectiveBg)
            text: {
              const label = btn.modelData && (btn.modelData.tooltipTitle || btn.modelData.title || btn.modelData.id) || "?";
              return String(label).charAt(0).toUpperCase();
            }
            visible: !iconImage.visible
          }
        }
      }
    }
  }
  OText {
    id: emptyLabel

    anchors.centerIn: parent
    color: Theme.textInactiveColor
    opacity: Theme.opacityMuted
    size: "xs"
    text: "No tray items"
    visible: trayRepeater.count === 0
  }
}
