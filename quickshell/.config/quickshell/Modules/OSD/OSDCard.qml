pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Config
import qs.Components

Item {
  id: root

  // Calculate width: fixed for percentage, dynamic for toggle based on text + icon + padding
  readonly property int calculatedWidth: {
    if (root.isPercentage)
      return 300;

    // For toggle: icon (48) + spacing (16) + text width + horizontal padding (48)
    const textWidth = labelText.implicitWidth;
    return Math.max(220, 48 + 16 + textWidth + 48);
  }
  property string icon: ""
  readonly property bool isPercentage: typeof root.value === "number" && root.value >= 0
  property string label: ""
  property int maxValue: 100
  property bool showing: false
  property string type: ""
  property var value: null

  implicitHeight: 80
  implicitWidth: calculatedWidth
  opacity: root.showing ? 1 : 0
  y: root.showing ? 0 : 60

  Behavior on opacity {
    NumberAnimation {
      duration: 160
      easing.type: Easing.InOutQuad
    }
  }
  Behavior on y {
    NumberAnimation {
      duration: 260
      easing.type: Easing.OutCubic
    }
  }

  // Shadow
  RectangularShadow {
    anchors.fill: bg
    blur: 20
    color: Qt.rgba(0, 0, 0, 0.5)
    offset: Qt.vector2d(0, 2)
    radius: 40
  }

  // Background
  Rectangle {
    id: bg

    anchors.fill: parent
    border.color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.3)
    border.width: 1
    color: Theme.bgColor
    radius: 40
  }

  // Percentage layout (volume, brightness)
  RowLayout {
    anchors.centerIn: parent
    spacing: 16
    visible: root.isPercentage
    width: parent.width - 48

    Text {
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
        splitAt: root.type === "volume-output" ? 2 / 3 : 1.0
        value: {
          const divisor = root.type === "volume-output" ? 150 : 100;
          return Math.min(root.value / divisor, 1);
        }
      }
    }

    Text {
      color: "#eeeeee"
      font.bold: true
      font.pixelSize: 16
      text: `${Math.round(root.value)}%`
    }
  }

  // Toggle layout (wifi, bluetooth, etc.)
  RowLayout {
    anchors.centerIn: parent
    spacing: 16
    visible: !root.isPercentage

    Rectangle {
      Layout.preferredHeight: 48
      Layout.preferredWidth: 48
      border.color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.4)
      border.width: 1.5
      color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.25)
      radius: 14

      Text {
        anchors.centerIn: parent
        color: Theme.activeColor
        font.family: "JetBrainsMono Nerd Font Mono"
        font.pixelSize: 28
        text: root.icon || "󰋽"
      }
    }

    Text {
      id: labelText

      color: "#eeeeee"
      font.bold: true
      font.pixelSize: 16
      text: root.label || ""
      visible: text.length > 0
    }
  }
}
