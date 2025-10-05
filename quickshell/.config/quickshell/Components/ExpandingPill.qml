pragma ComponentBehavior: Bound

import QtQuick
import qs.Config

Item {
  id: pill

  // Layout
  property int slotW: Theme.itemWidth
  property int slotH: Theme.itemHeight
  property int spacing: 8
  property int count: 0
  property int animMs: Theme.animationDuration

  // Behavior
  property bool expandOnHover: true
  property bool expanded: false
  property int collapsedIndex: 0
  property Component delegate // receives required property int index
  // New: delay collapse (ms) and an optional external “hold open” flag
  property int collapseDelayMs: Theme.animationDuration
  property bool holdOpen: false  // e.g. counting
  // New: control alignment of the pill's content. Defaults to right, like PowerMenu.
  property bool rightAligned: true
  // Clamp collapsed index to valid range
  readonly property int effectiveCollapsedIndex: Math.max(0, Math.min(pill.collapsedIndex, Math.max(0, pill.count - 1)))
  // Precompute full expanded width
  readonly property int expandedWidth: (pill.count * pill.slotW) + (Math.max(0, pill.count - 1) * pill.spacing)

  // When collapsed and the collapsedIndex changes, animate content offset for a sliding effect
  onCollapsedIndexChanged: if (!pill.expanded) {
    viewport.animOnIndexChange = true;
    indexSlideGuard.restart();
  }

  height: slotH
  width: expanded ? (count * slotW + Math.max(0, count - 1) * spacing) : slotW
  clip: true

  Behavior on width {
    NumberAnimation {
      duration: pill.animMs
      easing.type: Easing.InOutQuad
    }
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

  // Absolute positioning inside a clipped viewport for precise collapsed alignment
  Item {
    id: viewport
    anchors.fill: parent
    clip: true

    // Progress of width animation from collapsed (slotW) to expanded (expandedWidth)
    readonly property real progress: Math.max(0, Math.min(1, (pill.width - pill.slotW) / Math.max(1, (pill.expandedWidth - pill.slotW))))
    // Expanded positions are left-based; alignment handled via contentOffset
    function expandedX(idx) {
      const step = pill.slotW + pill.spacing;
      return idx * step;
    }
    // Offsets for collapsed and expanded alignment (handle rightAligned too)
    readonly property real collapsedOffset: (pill.rightAligned ? (pill.width - pill.slotW) : 0) - expandedX(pill.effectiveCollapsedIndex)
    readonly property real expandedOffset: (pill.rightAligned ? (pill.width - pill.expandedWidth) : 0)
    // Interpolate offset so container growth and content motion stay in sync
    property real contentOffset: collapsedOffset * (1 - progress) + expandedOffset * progress

    // Enable a one-shot animation when index changes while collapsed
    property bool animOnIndexChange: false
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
        width: (pill.expanded || cell.index === pill.effectiveCollapsedIndex) ? pill.slotW : 0
        // Base expanded position plus the shared contentOffset
        x: viewport.expandedX(cell.index) + viewport.contentOffset
        opacity: width > 0 ? 1 : 0

        Behavior on width {
          NumberAnimation {
            duration: pill.animMs
            easing.type: Easing.InOutQuad
          }
        }
        Behavior on opacity {
          NumberAnimation {
            duration: pill.animMs
            easing.type: Easing.InOutQuad
          }
        }

        // Instantiate the delegate manually so we can pass 'index' at creation time
        property var __child
        Component.onCompleted: {
          __child = pill.delegate && pill.delegate.createObject(cell, {
            index: cell.index
          });
          if (__child && __child.anchors)
            __child.anchors.fill = cell;
        }
        Component.onDestruction: {
          if (__child)
            __child.destroy();
        }
      }
    }
  }

  // Guard to auto-disable the sliding animation
  Timer {
    id: indexSlideGuard
    interval: pill.animMs
    repeat: false
    onTriggered: viewport.animOnIndexChange = false
  }
}
