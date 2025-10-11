pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Config

Item {
  id: root

  property string icon: ""
  property string label: ""
  property var value: null
  property bool showing: false

  readonly property bool isPercentage: typeof root.value === "number" && root.value >= 0 && root.value <= 100

  // Calculate width: fixed for percentage, dynamic for toggle based on text + icon + padding
  readonly property int calculatedWidth: {
    if (root.isPercentage)
      return 300;

    // For toggle: icon (48) + spacing (16) + text width + horizontal padding (48)
    const textWidth = labelText.implicitWidth;
    return Math.max(220, 48 + 16 + textWidth + 48);
  }

  implicitWidth: calculatedWidth
  implicitHeight: 80

  y: root.showing ? 0 : 60
  opacity: root.showing ? 1 : 0

  Behavior on y {
    NumberAnimation {
      duration: 260
      easing.type: Easing.OutCubic
    }
  }

  Behavior on opacity {
    NumberAnimation {
      duration: 160
      easing.type: Easing.InOutQuad
    }
  }

  // Shadow
  RectangularShadow {
    anchors.fill: bg
    radius: 40
    color: Qt.rgba(0, 0, 0, 0.5)
    offset: Qt.vector2d(0, 2)
    blur: 20
  }

  // Background
  Rectangle {
    id: bg
    anchors.fill: parent
    radius: 40
    color: Theme.bgColor
    border.width: 1
    border.color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.3)
  }

  // Percentage layout (volume, brightness)
  RowLayout {
    anchors.centerIn: parent
    width: parent.width - 48
    spacing: 16
    visible: root.isPercentage

    Text {
      text: root.icon || "󰕾"
      color: Theme.activeColor
      font.pixelSize: 32
      font.family: "Symbols Nerd Font"
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 12
      radius: 6
      color: Qt.rgba(1, 1, 1, 0.25)

      Rectangle {
        width: parent.width * (root.value / 100)
        height: parent.height
        radius: parent.radius
        color: Theme.activeColor

        Behavior on width {
          NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }

  // Toggle layout (wifi, bluetooth, etc.)
  RowLayout {
    id: toggleLayout
    anchors.centerIn: parent
    spacing: 16
    visible: !root.isPercentage

    Rectangle {
      Layout.preferredWidth: 48
      Layout.preferredHeight: 48
      radius: 14
      color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.25)
      border.width: 1.5
      border.color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.4)

      Text {
        anchors.centerIn: parent
        text: root.icon || "󰋽"
        color: Theme.activeColor
        font.pixelSize: 28
        font.family: "Symbols Nerd Font"
      }
    }

    Text {
      id: labelText
      text: root.label || ""
      color: "#eeeeee"
      font.pixelSize: 16
      font.bold: true
      visible: text.length > 0
    }
  }
}
