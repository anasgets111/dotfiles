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
  border.color: card.checked && card.active ? Theme.withOpacity(Theme.activeColor, Theme.opacityMedium) : "transparent"
  border.width: Theme.borderWidthThin
  color: card.checked && card.active ? Theme.activeSubtle : Theme.bgCard
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
  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: card.detail !== "" ? Theme.spacingMd : 0
    anchors.rightMargin: card.detail !== "" ? Theme.spacingMd : 0
    spacing: Theme.spacingSm

    Item {
      Layout.fillWidth: true
      visible: card.detail === "" && !card.compact
    }
    ColumnLayout {
      spacing: Theme.spacingXs

      Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: Theme.iconSizeMd
        Layout.preferredWidth: Theme.iconSizeMd

        Text {
          anchors.centerIn: parent
          color: card.checked && card.active ? Theme.activeColor : Theme.textInactiveColor
          font.family: Theme.fontFamily
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
      OText {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: card.width - Theme.spacingMd * 2
        color: card.checked && card.active ? Theme.textActiveColor : Theme.textInactiveColor
        elide: Text.ElideRight
        size: "xs"
        text: card.detail
        visible: card.compact && card.detail !== ""
      }
    }
    Item {
      Layout.fillWidth: true
    }
    OText {
      Layout.maximumWidth: card.width / 2
      color: card.checked && card.active ? Theme.textActiveColor : Theme.textInactiveColor
      elide: Text.ElideRight
      size: "xs"
      text: card.detail
      visible: !card.compact && card.detail !== ""

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }
  }
}
