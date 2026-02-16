import QtQuick
import Quickshell
import qs.Components
import qs.Config

Item {
  id: root

  readonly property bool centerShouldHide: workspacesExpanded || rightSideExpanded
  property bool rightSideExpanded: false
  required property ShellScreen screen
  property bool workspacesExpanded: false

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

      color: Theme.bgColor
      height: Theme.panelHeight
      width: parent.width

      LeftSide {
        normalWorkspacesExpanded: root.workspacesExpanded
        screenName: root.screen?.name ?? ""

        onNormalWorkspacesExpandedChanged: root.workspacesExpanded = normalWorkspacesExpanded
        onWallpaperPickerRequested: root.wallpaperPickerRequested()

        anchors {
          left: parent.left
          leftMargin: Theme.panelMargin
          verticalCenter: parent.verticalCenter
        }
      }

      RightSide {
        normalWorkspacesExpanded: root.rightSideExpanded
        screenName: root.screen?.name ?? ""

        onNormalWorkspacesExpandedChanged: root.rightSideExpanded = normalWorkspacesExpanded

        anchors {
          right: parent.right
          rightMargin: Theme.panelMargin
          verticalCenter: parent.verticalCenter
        }
      }

      CenterSide {
        anchors.centerIn: parent
        normalWorkspacesExpanded: root.centerShouldHide
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
        color: Theme.bgColor
        height: radius
        radius: Theme.panelRadius
        width: radius
      }

      RoundCorner {
        anchors.right: parent.right
        color: Theme.bgColor
        height: radius
        orientation: 1
        radius: Theme.panelRadius
        width: radius
      }
    }
  }
}
