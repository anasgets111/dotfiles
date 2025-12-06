pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Config
import qs.Components

Item {
  id: root

  readonly property int horizontalPadding: Theme.spacingXl
  // Computed width for toggle layout (icon container + spacing + label)
  readonly property int _toggleWidth: Theme.osdToggleIconContainerSize + Theme.spacingLg * 2 + labelText.implicitWidth + horizontalPadding * 2

  property string icon: ""
  readonly property bool isSlider: typeof value === "number" && value >= 0
  property string label: ""
  property int maxValue: 100
  property bool showing: false
  property string type: ""
  property var value: null

  implicitHeight: Theme.osdCardHeight
  implicitWidth: isSlider ? Theme.osdSliderWidth : Math.max(Theme.osdToggleMinWidth, _toggleWidth)
  opacity: showing ? 1 : 0
  y: showing ? 0 : Theme.osdAnimationOffset

  Behavior on opacity {
    NumberAnimation {
      duration: Theme.animationDuration
      easing.type: Easing.InOutQuad
    }
  }
  Behavior on y {
    NumberAnimation {
      duration: Theme.animationDuration * 1.5
      easing.type: Easing.OutCubic
    }
  }

  RectangularShadow {
    anchors.fill: bg
    blur: Theme.shadowBlurMd
    color: Theme.bgOverlay
    offset: Qt.vector2d(0, Theme.shadowOffsetY)
    radius: Theme.radiusXl
  }

  Rectangle {
    id: bg

    anchors.fill: parent
    border.color: Theme.withOpacity(Theme.activeColor, 0.3)
    border.width: 1
    color: Theme.bgColor
    radius: Theme.radiusXl
  }

  // Slider layout (volume, brightness)
  RowLayout {
    anchors.centerIn: parent
    spacing: Theme.spacingLg
    visible: root.isSlider
    width: parent.width - horizontalPadding * 2

    OText {
      color: Theme.activeColor
      font.family: Theme.iconFontFamily
      font.pixelSize: Theme.fontXxl
      text: root.icon || "󰕾"
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Theme.osdSliderTrackHeight
      color: Qt.rgba(1, 1, 1, Theme.opacityLight)
      radius: Theme.radiusSm

      Slider {
        anchors.fill: parent
        animMs: 0
        fillColor: Theme.activeColor
        headroomColor: Theme.critical
        interactive: false
        radius: Theme.radiusSm
        splitAt: root.type === "volume-output" ? 2 / 3 : 1
        value: Math.min(root.value / (root.type === "volume-output" ? 150 : 100), 1)
      }
    }

    OText {
      bold: true
      size: "lg"
      text: `${Math.round(root.value)}%`
    }
  }

  // Toggle layout
  RowLayout {
    anchors.centerIn: parent
    spacing: Theme.spacingLg
    visible: !root.isSlider

    Rectangle {
      Layout.preferredHeight: Theme.osdToggleIconContainerSize
      Layout.preferredWidth: Theme.osdToggleIconContainerSize
      border.color: Theme.activeMedium
      border.width: Theme.borderWidthThin
      color: Theme.activeLight
      radius: Theme.radiusMd

      OText {
        anchors.centerIn: parent
        color: Theme.activeColor
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.fontXl
        text: root.icon || "󰣽"
      }
    }

    OText {
      id: labelText

      bold: true
      size: "lg"
      text: root.label || ""
      visible: text.length > 0
    }
  }
}
