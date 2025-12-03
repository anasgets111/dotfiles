pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Config

ToolButton {
  id: btn

  // "control" (default), "action", "send"
  property string buttonType: "control"

  display: (icon.source && icon.source.toString() !== "") ? AbstractButton.TextBesideIcon : AbstractButton.TextOnly
  font.pixelSize: Theme.fontSm
  leftPadding: btn.buttonType === "action" ? Theme.spacingMd : Theme.spacingSm

  // Spacing and paddings tuned per role
  padding: btn.buttonType === "action" ? Theme.spacingXs + 2 : Theme.spacingXs
  palette.buttonText: btn.buttonType === "action" ? "#e0e0e0" : "white"
  rightPadding: btn.buttonType === "action" ? Theme.spacingMd : Theme.spacingSm

  background: Rectangle {
    border.color: Qt.rgba(255, 255, 255, btn.buttonType === "action" ? 0.07 : 0.08)
    border.width: 1
    color: btn.hovered ? Qt.rgba(1, 1, 1, btn.buttonType === "action" ? 0.12 : 0.16) : Qt.rgba(1, 1, 1, btn.buttonType === "action" ? 0.08 : 0.10)
    radius: btn.buttonType === "action" ? Theme.radiusMd : Theme.radiusSm
  }
}
