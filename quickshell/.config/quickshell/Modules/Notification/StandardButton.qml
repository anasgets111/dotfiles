pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ToolButton {
  id: btn
  property string buttonType: "control" // "control", "action", "send"

  display: (icon.source && icon.source.toString() !== "") ? AbstractButton.TextBesideIcon : AbstractButton.TextOnly
  padding: btn.buttonType === "action" ? 6 : 4
  leftPadding: btn.buttonType === "action" ? 12 : 8
  rightPadding: btn.buttonType === "action" ? 12 : 8

  background: Rectangle {
    radius: btn.buttonType === "action" ? 14 : 10
    color: btn.hovered ? Qt.rgba(1, 1, 1, btn.buttonType === "action" ? 0.12 : 0.16) : Qt.rgba(1, 1, 1, btn.buttonType === "action" ? 0.08 : 0.10)
    border.width: 1
    border.color: Qt.rgba(255, 255, 255, btn.buttonType === "action" ? 0.07 : 0.08)
  }

  // Let ToolButton handle its own contentItem for proper icon support
  palette.buttonText: btn.buttonType === "action" ? "#e0e0e0" : "white"
  font.pixelSize: btn.buttonType === "action" ? 12 : 12
}
