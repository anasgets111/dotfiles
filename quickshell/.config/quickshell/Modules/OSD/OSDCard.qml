pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Config
import qs.Components

Item {
  id: root

  property string icon: ""
  readonly property bool isSlider: typeof value === "number" && value >= 0
  property string label: ""
  property int maxValue: 100
  property bool showing: false
  property string type: ""
  property var value: null

  implicitHeight: 80
  implicitWidth: isSlider ? 300 : Math.max(220, 112 + labelText.implicitWidth)
  opacity: showing ? 1 : 0
  y: showing ? 0 : 60

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
    blur: 20
    color: Qt.rgba(0, 0, 0, 0.5)
    offset: Qt.vector2d(0, 2)
    radius: 40
  }

  Rectangle {
    id: bg

    anchors.fill: parent
    border.color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.3)
    border.width: 1
    color: Theme.bgColor
    radius: 40
  }

  // Slider layout (volume, brightness)
  RowLayout {
    anchors.centerIn: parent
    spacing: 16
    visible: root.isSlider
    width: parent.width - 48

    OText {
      color: Theme.activeColor
      font.family: "JetBrainsMono Nerd Font Mono"
      font.pixelSize: 32
      text: root.icon || "󰕾"
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 12
      color: Qt.rgba(1, 1, 1, 0.25)
      radius: 6

      Slider {
        anchors.fill: parent
        animMs: 0
        fillColor: Theme.activeColor
        headroomColor: Theme.critical
        interactive: false
        radius: 6
        splitAt: root.type === "volume-output" ? 2 / 3 : 1
        value: Math.min(root.value / (root.type === "volume-output" ? 150 : 100), 1)
      }
    }

    OText {
      font.bold: true
      font.pixelSize: 16
      text: `${Math.round(root.value)}%`
    }
  }

  // Toggle layout
  RowLayout {
    anchors.centerIn: parent
    spacing: 16
    visible: !root.isSlider

    Rectangle {
      Layout.preferredHeight: 48
      Layout.preferredWidth: 48
      border.color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.4)
      border.width: 1.5
      color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.25)
      radius: 14

      OText {
        anchors.centerIn: parent
        color: Theme.activeColor
        font.family: "JetBrainsMono Nerd Font Mono"
        font.pixelSize: 28
        text: root.icon || "󰋽"
      }
    }

    OText {
      id: labelText

      font.bold: true
      font.pixelSize: 16
      text: root.label || ""
      visible: text.length > 0
    }
  }
}
