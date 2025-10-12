pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ToolButton {
  id: btn

  // "control" (default), "action", "send"
  property string buttonType: "control"

  display: (icon.source && icon.source.toString() !== "") ? AbstractButton.TextBesideIcon : AbstractButton.TextOnly
  font.pixelSize: 12
  leftPadding: btn.buttonType === "action" ? 12 : 8

  // Spacing and paddings tuned per role
  padding: btn.buttonType === "action" ? 6 : 4
  palette.buttonText: btn.buttonType === "action" ? "#e0e0e0" : "white"
  rightPadding: btn.buttonType === "action" ? 12 : 8

  background: Rectangle {
    border.color: Qt.rgba(255, 255, 255, btn.buttonType === "action" ? 0.07 : 0.08)
    border.width: 1
    color: btn.hovered ? Qt.rgba(1, 1, 1, btn.buttonType === "action" ? 0.12 : 0.16) : Qt.rgba(1, 1, 1, btn.buttonType === "action" ? 0.08 : 0.10)
    radius: btn.buttonType === "action" ? 14 : 10
  }
}
