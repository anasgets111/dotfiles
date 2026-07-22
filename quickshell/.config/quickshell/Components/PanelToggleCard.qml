pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config

Rectangle {
  id: card

  property bool active: true
  property bool checked: false
  readonly property bool compact: width < Theme.panelToggleCompactThreshold
  property string detail: ""
  required property string icon
  required property string label
  property bool spinning: false

  signal toggled(bool checked)

  Layout.fillWidth: true
  Layout.preferredHeight: Theme.panelToggleCardHeight
  Layout.preferredWidth: 0
  border.color: card.checked && card.active ? Theme.withOpacity(Theme.activeColor, Theme.opacityMedium) : Theme.glassBorderColor
  border.width: Theme.borderWidthThin
  color: card.checked && card.active ? Theme.activeSubtle : Theme.glassContentColor
  opacity: card.active ? 1.0 : Theme.opacityDisabled
  radius: Theme.radiusLg

  Behavior on border.color {
    ColorAnimation {
      duration: Theme.animationDuration
    }
  }
  Behavior on color {
    ColorAnimation {
      duration: Theme.animationDuration
    }
  }
  Behavior on opacity {
    NumberAnimation {
      duration: Theme.animationDuration
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: card.active ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: card.active

    onClicked: card.toggled(!card.checked)
  }
  LabelContent {
    anchors.centerIn: parent
    visible: card.compact || card.detail === ""
  }
  RowLayout {
    anchors.fill: parent
    anchors.margins: Theme.spacingMd
    spacing: Theme.spacingSm
    visible: !card.compact && card.detail !== ""

    LabelContent {
    }
    DetailText {
      Layout.fillWidth: true
    }
  }

  component DetailText: OText {
    color: card.checked && card.active ? Theme.textActiveColor : Theme.textInactiveColor
    elide: Text.ElideRight
    size: "xs"
    text: card.detail

    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }
  }
  component LabelContent: ColumnLayout {
    spacing: Theme.spacingXs

    Item {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredHeight: Theme.iconSizeMd
      Layout.preferredWidth: Theme.iconSizeMd

      Text {
        anchors.centerIn: parent
        color: card.checked && card.active ? Theme.activeColor : Theme.textInactiveColor
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSizeMd
        text: card.icon
        visible: !card.spinning

        Behavior on color {
          ColorAnimation {
            duration: Theme.animationDuration
          }
        }
      }
      OSpinner {
        anchors.centerIn: parent
        color: card.checked && card.active ? Theme.activeColor : Theme.textInactiveColor
        running: card.spinning
        spinnerSize: Theme.iconSizeMd
      }
    }
    OText {
      Layout.alignment: Qt.AlignHCenter
      bold: card.checked
      color: card.checked && card.active ? Theme.activeColor : Theme.textInactiveColor
      size: "xs"
      text: card.label

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }
    DetailText {
      Layout.alignment: Qt.AlignHCenter
      Layout.maximumWidth: card.width - Theme.spacingMd * 2
      visible: card.compact && card.detail !== ""
    }
  }
}
