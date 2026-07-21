import QtQuick
import Quickshell
import qs.Components
import qs.Config

Item {
  id: root

  readonly property Region barPanelRegion: Region {
    item: panelRect
  }
  readonly property Region blurRegion: Region {
    regions: [barCornerLeft.region, barCornerRight.region, root.barPanelRegion]
  }
  readonly property bool centerShouldHide: leftSide.workspacesExpanded || rightSide.expanded
  required property ShellScreen screen

  signal wallpaperPickerRequested

  height: implicitHeight
  implicitHeight: Theme.panelHeight + Theme.panelRadius

  Column {
    id: barContent

    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
    }
    Rectangle {
      id: panelRect

      color: Theme.bgPanel
      height: Theme.panelHeight
      width: parent.width

      LeftSide {
        id: leftSide

        screenName: root.screen?.name ?? ""

        onWallpaperPickerRequested: root.wallpaperPickerRequested()

        anchors {
          left: parent.left
          leftMargin: Theme.panelMargin
          verticalCenter: parent.verticalCenter
        }
      }
      RightSide {
        id: rightSide

        screenName: root.screen?.name ?? ""

        anchors {
          right: parent.right
          rightMargin: Theme.panelMargin
          verticalCenter: parent.verticalCenter
        }
      }
      CenterSide {
        anchors.centerIn: parent
        opacity: root.centerShouldHide ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
          }
        }
      }
    }
    Item {
      height: Theme.panelRadius
      width: parent.width

      RoundCorner {
        id: barCornerLeft

        color: Theme.bgPanel
        height: radius
        radius: Theme.panelRadius
        width: radius
      }
      RoundCorner {
        id: barCornerRight

        anchors.right: parent.right
        color: Theme.bgPanel
        height: radius
        orientation: 1
        radius: Theme.panelRadius
        width: radius
      }
    }
  }
}
