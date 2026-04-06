pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Components
import qs.Services.SystemInfo

PanelWindow {
  id: root

  function positionToRatios(): var {
    const availableWidth = Math.max(0, root.width - card.width);
    const availableHeight = Math.max(0, root.height - card.height);
    return {
      x: availableWidth > 0 ? Math.max(0, Math.min(1, card.x / availableWidth)) : 0,
      y: availableHeight > 0 ? Math.max(0, Math.min(1, card.y / availableHeight)) : 0
    };
  }

  function syncCardToSavedPosition(): void {
    if (dragArea.drag.active)
      return;
    const availableWidth = Math.max(0, root.width - card.width);
    const availableHeight = Math.max(0, root.height - card.height);
    card.x = availableWidth > 0 ? Math.round(InputDisplayService.positionXRatio * availableWidth) : 0;
    card.y = availableHeight > 0 ? Math.round(InputDisplayService.positionYRatio * availableHeight) : 0;
  }

  required property var modelData
  readonly property var visibleTokens: InputDisplayService.visibleKeys.concat(InputDisplayService.visibleMouseButtons)
  readonly property string pressedSignature: visibleTokens.join("+")
  readonly property bool showComboLabel: InputDisplayService.comboDisplayLabel.length > 0 && InputDisplayService.comboLabel !== pressedSignature
  readonly property bool shouldStayVisible: InputDisplayService.visible || dragArea.drag.active

  WlrLayershell.exclusiveZone: -1
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "obelisk-input-display-overlay-" + (screen?.name || "unknown")
  color: "transparent"
  screen: modelData
  surfaceFormat.opaque: false
  visible: true

  mask: Region {
    item: root.shouldStayVisible ? card : null
  }

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }

  Component.onCompleted: Qt.callLater(root.syncCardToSavedPosition)
  onHeightChanged: Qt.callLater(root.syncCardToSavedPosition)
  onWidthChanged: Qt.callLater(root.syncCardToSavedPosition)

  Rectangle {
    id: card

    readonly property int hpad: Theme.spacingLg
    readonly property int vpad: Theme.spacingMd

    HoverHandler {
      id: cardHover
    }

    Binding {
      target: InputDisplayService
      property: "overlayHovered"
      value: cardHover.hovered
    }

    border.color: Theme.borderColor
    border.width: Theme.borderWidthThin
    color: Theme.bgElevated
    height: content.implicitHeight + vpad * 2
    opacity: root.shouldStayVisible ? 1 : 0
    radius: Theme.radiusMd
    width: Math.max(Theme.s(150), content.implicitWidth + hpad * 2)
    x: 0
    y: 0

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.InOutQuad
      }
    }

    Behavior on width {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.InOutQuad
      }
    }

    RectangularShadow {
      anchors.fill: parent
      blur: Theme.shadowBlurMd
      color: Theme.bgOverlay
      offset: Qt.vector2d(0, Theme.shadowOffsetY)
      radius: parent.radius
      z: -1
    }

    onHeightChanged: Qt.callLater(root.syncCardToSavedPosition)
    onWidthChanged: Qt.callLater(root.syncCardToSavedPosition)

    ColumnLayout {
      id: content

      anchors {
        fill: parent
        topMargin: card.vpad
        bottomMargin: card.vpad
        leftMargin: card.hpad
        rightMargin: card.hpad
      }
      spacing: Theme.spacingSm

      // ── Drag strip ─────────────────────────────────────────────
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.spacingMd

        MouseArea {
          id: dragArea

          anchors.fill: parent
          cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          drag.axis: Drag.XAndYAxis
          drag.maximumX: Math.max(0, root.width - card.width)
          drag.maximumY: Math.max(0, root.height - card.height)
          drag.minimumX: 0
          drag.minimumY: 0
          drag.target: card

          onPressed: mouse => mouse.accepted = true
          onReleased: {
            const ratios = root.positionToRatios();
            InputDisplayService.persistPositionRatios(ratios.x, ratios.y);
          }
        }

        Row {
          anchors.centerIn: parent
          spacing: Theme.spacingXs

          Repeater {
            model: 3

            Rectangle {
              height: Theme.spacingXs
              radius: height / 2
              width: Theme.spacingMd
              color: dragArea.containsMouse || dragArea.drag.active ? Theme.activeMedium : Theme.borderColor

              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationFast
                }
              }
            }
          }
        }
      }

      // ── Combo label ────────────────────────────────────────────
      OText {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        accent: true
        bold: true
        horizontalAlignment: Text.AlignHCenter
        size: "xl"
        text: InputDisplayService.comboDisplayLabel
        visible: root.showComboLabel
        wrapMode: Text.Wrap
      }

      // ── Held key chips ─────────────────────────────────────────
      Flow {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        spacing: Theme.spacingXs
        visible: root.visibleTokens.length > 0

        Repeater {
          model: root.visibleTokens

          Rectangle {
            id: chip

            required property string modelData

            clip: true
            color: Theme.bgElevatedAlt
            border.color: Theme.borderColor
            border.width: Theme.borderWidthThin
            radius: Theme.radiusSm
            height: keyLabel.implicitHeight + Theme.spacingXs * 2
            width: keyLabel.implicitWidth + Theme.spacingSm * 2

            // Keycap depth: accent bar along the bottom edge
            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Theme.borderWidthThin
              color: Theme.activeMedium
              height: Theme.borderWidthMedium
            }

            OText {
              id: keyLabel

              anchors.centerIn: parent
              bold: true
              size: "sm"
              text: chip.modelData
            }
          }
        }
      }
    }
  }
}
