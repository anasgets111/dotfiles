import QtQuick
import Quickshell
import qs.Components
import qs.Config

Item {
  id: root

  readonly property Region blurRegion: Region {
    item: panelRect
    regions: [barCornerLeft.region, barCornerRight.region]
  }
  // The center is centred, so both sides have the same room. Yield only when a neighbour would
  // actually reach it, rather than whenever one happens to be expanded.
  readonly property bool centerShouldHide: (panelRect.width - centerSide.width) / 2 - Theme.spacingMd < Theme.panelMargin + Math.max(leftSide.width, rightSide.width)
  required property ShellScreen screen

  signal wallpaperPickerRequested

  implicitHeight: Theme.panelHeight + Theme.panelRadius

  Column {
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
    }
    Rectangle {
      id: panelRect

      color: Theme.glassSurfaceColor
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
        id: centerSide

        anchors.centerIn: parent
        opacity: root.centerShouldHide ? 0 : 1
        screenName: root.screen?.name ?? ""
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

        height: radius
        radius: Theme.panelRadius
        width: radius
      }
      RoundCorner {
        id: barCornerRight

        anchors.right: parent.right
        height: radius
        orientation: 1
        radius: Theme.panelRadius
        width: radius
      }
    }
  }
}
