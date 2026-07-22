pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Item {
  id: pill

  property int animMs: Theme.animationDuration
  property int collapseDelayMs: Theme.animationDuration
  property int collapsedIndex: 0
  property int count: 0
  property Component delegate // receives required property int index
  readonly property int effectiveCollapsedIndex: Math.max(0, Math.min(pill.collapsedIndex, Math.max(0, pill.count - 1)))

  property bool expandOnHover: true
  property bool expanded: false
  readonly property int expandedWidth: (pill.count * pill.slotW) + (Math.max(0, pill.count - 1) * pill.spacing)
  property bool holdOpen: false
  property bool rightAligned: true
  property int slotH: Theme.itemHeight

  property int slotW: Theme.itemWidth
  property int spacing: Theme.spacingSm

  clip: true
  height: slotH
  width: expanded ? (count * slotW + Math.max(0, count - 1) * spacing) : slotW

  Behavior on width {
    NumberAnimation {
      duration: pill.animMs
      easing.type: Easing.InOutQuad
    }
  }

  onCollapsedIndexChanged: if (!pill.expanded) {
    viewport.animOnIndexChange = true;
    indexSlideGuard.restart();
  }

  HoverHandler {
    enabled: pill.expandOnHover

    onHoveredChanged: {
      if (hovered) {
        collapseTimer.stop();
        pill.expanded = true;
      } else {
        if (!pill.holdOpen)
          collapseTimer.restart();
      }
    }
  }
  Timer {
    id: collapseTimer

    interval: pill.collapseDelayMs

    onTriggered: {
      if (!pill.holdOpen)
        pill.expanded = false;
    }
  }

  Item {
    id: viewport

    property bool animOnIndexChange: false
    readonly property real collapsedOffset: (pill.rightAligned ? (pill.width - pill.slotW) : 0) - expandedX(pill.effectiveCollapsedIndex)
    property real contentOffset: collapsedOffset * (1 - progress) + expandedOffset * progress
    readonly property real expandedOffset: (pill.rightAligned ? (pill.width - pill.expandedWidth) : 0)

    readonly property real progress: Math.max(0, Math.min(1, (pill.width - pill.slotW) / Math.max(1, (pill.expandedWidth - pill.slotW))))

    function expandedX(idx) {
      const step = pill.slotW + pill.spacing;
      return idx * step;
    }

    anchors.fill: parent
    clip: true

    Behavior on contentOffset {
      enabled: (!pill.expanded && viewport.animOnIndexChange)

      NumberAnimation {
        duration: pill.animMs
        easing.type: Easing.InOutQuad
      }
    }

    Repeater {
      model: pill.count

      delegate: Item {
        id: cell

        required property int index

        height: pill.slotH
        opacity: width > 0 ? 1 : 0
        width: (pill.expanded || cell.index === pill.effectiveCollapsedIndex) ? pill.slotW : 0
        x: viewport.expandedX(cell.index) + viewport.contentOffset

        Behavior on opacity {
          NumberAnimation {
            duration: pill.animMs
            easing.type: Easing.InOutQuad
          }
        }
        Behavior on width {
          NumberAnimation {
            duration: pill.animMs
            easing.type: Easing.InOutQuad
          }
        }

        Component.onCompleted: {
          const child = (pill.delegate && pill.delegate.createObject(cell, {
              index: cell.index
            })) as Item;
          if (child)
            child.anchors.fill = cell;
        }
      }
    }
  }

  Timer {
    id: indexSlideGuard

    interval: pill.animMs
    repeat: false

    onTriggered: viewport.animOnIndexChange = false
  }
}
