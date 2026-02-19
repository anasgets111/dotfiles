pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Rectangle {
  id: root

  property color activeBgColor: Theme.activeColor
  property int animMs: 130
  property color baseColor: Qt.rgba(1, 1, 1, 0.04)
  property color borderColor: Qt.rgba(1, 1, 1, 0.08)
  property color inactiveBgColor: "transparent"
  property int collapseDelayMs: 220
  property int currentIndex: 0
  property int fontSize: 11
  property int minSlotWidth: 56
  property var options: []
  property int slotHeight: 24

  readonly property int safeCurrentIndex: Math.max(0, Math.min(currentIndex, Math.max(0, (options?.length ?? 0) - 1)))
  readonly property int slotWidth: {
    let maxWidth = 0;
    for (const option of options ?? [])
      maxWidth = Math.max(maxWidth, Math.ceil(metrics.advanceWidth(option?.label ?? "")));
    return Math.max(minSlotWidth, maxWidth + 16);
  }

  signal selected(var value)

  border.color: root.borderColor
  color: root.baseColor
  implicitHeight: 30
  implicitWidth: pill.width + 12
  radius: 15
  visible: (options?.length ?? 0) > 0

  FontMetrics {
    id: metrics

    font.family: Theme.fontFamily
    font.pixelSize: root.fontSize
  }

  ExpandingPill {
    id: pill

    anchors.centerIn: parent
    animMs: root.animMs
    collapseDelayMs: root.collapseDelayMs
    collapsedIndex: root.safeCurrentIndex
    count: root.options?.length ?? 0
    rightAligned: false
    slotH: root.slotHeight
    slotW: root.slotWidth
    spacing: 2

    delegate: Component {
      Rectangle {
        required property int index
        readonly property bool isActive: index === root.safeCurrentIndex
        readonly property var modelData: root.options[index] ?? {}

        color: isActive ? root.activeBgColor : root.inactiveBgColor
        radius: 12

        Behavior on color {
          ColorAnimation {
            duration: root.animMs
          }
        }

        OText {
          anchors.centerIn: parent
          font.bold: isActive
          font.pixelSize: root.fontSize
          opacity: isActive ? 1 : 0.5
          text: modelData?.label ?? ""

          Behavior on opacity {
            NumberAnimation {
              duration: root.animMs
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor

          onClicked: root.selected(modelData?.value ?? "")
        }
      }
    }
  }
}
