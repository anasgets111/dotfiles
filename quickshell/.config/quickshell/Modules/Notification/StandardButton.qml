pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Config

ToolButton {
  id: btn
  property string buttonType: "control" // "control", "action", "send"

  display: (icon.source && icon.source.toString() !== "") ? AbstractButton.TextBesideIcon : AbstractButton.TextOnly

  // Theme-based styling
  readonly property int baseRadius: Theme.panelRadius || 10
  readonly property int basePadding: 4
  readonly property int actionPadding: 6
  readonly property int actionMargin: 4

  padding: btn.buttonType === "action" ? actionPadding : basePadding
  leftPadding: btn.buttonType === "action" ? basePadding * 3 : basePadding * 2
  rightPadding: btn.buttonType === "action" ? basePadding * 3 : basePadding * 2

  background: Rectangle {
    radius: btn.buttonType === "action" ? btn.baseRadius + btn.actionMargin : btn.baseRadius
    color: btn.hovered ? Qt.rgba(Theme.textActiveColor.r, Theme.textActiveColor.g, Theme.textActiveColor.b, btn.buttonType === "action" ? 0.12 : 0.16) : Qt.rgba(Theme.textActiveColor.r, Theme.textActiveColor.g, Theme.textActiveColor.b, btn.buttonType === "action" ? 0.08 : 0.10)
    border.width: 1
    border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, btn.buttonType === "action" ? 0.07 : 0.08)
  }

  palette.buttonText: btn.buttonType === "action" ? Qt.rgba(Theme.textActiveColor.r, Theme.textActiveColor.g, Theme.textActiveColor.b, 0.88) : Theme.textActiveColor
  font.pixelSize: Theme.fontSize
}
