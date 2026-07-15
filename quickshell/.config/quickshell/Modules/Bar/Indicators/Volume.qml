pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Services.Core
import qs.Services.UI

Rectangle {
  id: root

  readonly property real displayValue: volumeSlider.dragging ? volumeSlider.pending : sliderValue
  readonly property real effectiveVolume: displayValue * maxVolume
  readonly property bool expanded: hoverHandler.hovered || volumeSlider.dragging
  readonly property bool isMuted: AudioService.muted
  readonly property real maxVolume: AudioService.maxVolume
  readonly property string percentText: {
    if (!ready)
      return "--";
    if (isMuted)
      return qsTr("Muted");
    return Math.round(effectiveVolume * 100) + "%";
  }
  readonly property bool ready: AudioService.sinkControllable
  required property string screenName
  readonly property real sliderValue: AudioService.volume / maxVolume
  readonly property color trackColor: isMuted ? Theme.inactiveColor : Theme.activeColor
  readonly property string volumeIcon: {
    if (!ready)
      return "--";
    if (isMuted)
      return "󰝟";
    if (AudioService.sinkIcon)
      return AudioService.sinkIcon;
    if (effectiveVolume < 0.01)
      return "󰖁";
    if (effectiveVolume < 0.33)
      return "󰕿";
    if (effectiveVolume < 0.66)
      return "󰖀";
    return "󰕾";
  }

  function foregroundAt(item: Item): color {
    const center = contentRow.x + item.x + item.width / 2;
    if (!expanded || displayValue * width < center)
      return Theme.textContrast(color);
    return Theme.textContrast(center > width * volumeSlider.splitAt ? Theme.critical : trackColor);
  }

  border.color: isMuted ? Theme.borderLight : "transparent"
  border.width: Theme.borderWidthThin
  clip: true
  color: isMuted ? Theme.bgElevated : Theme.inactiveColor
  height: Theme.itemHeight
  radius: Theme.itemRadius
  width: expanded ? Theme.volumeExpandedWidth : Theme.itemHeight

  Behavior on border.color {
    ColorAnimation {
      duration: Theme.animationDuration
    }
  }
  Behavior on width {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }

  onSliderValueChanged: if (!volumeSlider.dragging)
    volumeSlider.value = sliderValue

  HoverHandler {
    id: hoverHandler
  }
  Slider {
    id: volumeSlider

    anchors.fill: parent
    animMs: 0
    fillColor: root.trackColor
    headroomColor: Theme.critical
    interactive: root.ready
    opacity: root.expanded ? 1 : 0
    radius: root.radius
    splitAt: 1.0 / root.maxVolume
    steps: 30
    wheelStep: 1 / steps

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }

    onCommitted: normalizedValue => AudioService.setVolume(normalizedValue * root.maxVolume)
  }
  MouseArea {
    acceptedButtons: Qt.MiddleButton | Qt.RightButton
    anchors.fill: parent

    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton && root.ready)
        AudioService.toggleMute();
      else if (mouse.button === Qt.RightButton)
        ShellUiState.togglePanelForItem("audio", root.screenName, root);
    }
  }
  RowLayout {
    id: contentRow

    anchors.centerIn: parent
    spacing: Theme.spacingSm

    OText {
      id: iconText

      bold: true
      color: root.foregroundAt(iconText)
      font.pixelSize: Theme.iconSizeXl
      horizontalAlignment: Text.AlignHCenter
      text: root.volumeIcon
    }
    OText {
      id: percentageText

      bold: true
      color: root.foregroundAt(percentageText)
      horizontalAlignment: Text.AlignHCenter
      text: root.percentText
      verticalAlignment: Text.AlignVCenter
      visible: root.expanded
    }
  }
}
