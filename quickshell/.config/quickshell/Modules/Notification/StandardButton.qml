pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Config

ToolButton {
  id: btn

  // "control" (default), "action", "send"
  property string buttonType: "control"

  display: {
    const hasIcon = !!(icon.source && icon.source.toString() !== "");
    const hasText = !!String(text || "");
    if (hasIcon && hasText)
      return AbstractButton.TextBesideIcon;
    if (hasIcon)
      return AbstractButton.IconOnly;
    return AbstractButton.TextOnly;
  }
  font.pixelSize: Theme.fontSm
  leftPadding: btn.buttonType === "action" ? Theme.spacingMd : Theme.spacingSm

  // Spacing and paddings tuned per role
  padding: btn.buttonType === "action" ? Theme.spacingXs + 2 : Theme.spacingXs
  palette.buttonText: Theme.textActiveColor
  rightPadding: btn.buttonType === "action" ? Theme.spacingMd : Theme.spacingSm

  background: Rectangle {
    border.color: Theme.borderSubtle
    border.width: Theme.borderWidthThin
    color: btn.hovered ? Theme.bgCardHover : Theme.bgCard
    radius: btn.buttonType === "action" ? Theme.radiusMd : Theme.radiusSm
  }
}
