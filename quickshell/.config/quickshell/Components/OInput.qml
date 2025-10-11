import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Config

/**
 * OInput - Obelisk themed text input component
 *
 * A TextField wrapper with error states, placeholder support,
 * and Theme-based styling including focus indicators.
 */
ColumnLayout {
  id: root

  property alias text: textField.text
  property alias placeholderText: textField.placeholderText
  property alias echoMode: textField.echoMode
  property bool hasError: false
  property string errorMessage: ""
  property bool autoFocus: false
  property real inputHeight: Theme.itemHeight * 0.8

  signal inputChanged
  signal inputFinished
  signal inputAccepted

  spacing: 4

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: root.inputHeight
    color: Theme.bgColor
    border.color: root.hasError ? Theme.critical : (textField.activeFocus ? Theme.activeColor : Theme.borderColor)
    border.width: root.hasError ? 2 : 1
    radius: Theme.itemRadius

    TextField {
      id: textField

      anchors.fill: parent
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      color: Theme.textActiveColor
      selectionColor: Theme.activeColor
      selectedTextColor: Theme.textContrast(Theme.activeColor)
      onTextChanged: root.inputChanged()
      onEditingFinished: root.inputFinished()
      onAccepted: root.inputAccepted()
      Component.onCompleted: {
        if (root.autoFocus)
          Qt.callLater(() => {
            textField.forceActiveFocus();
          });
      }

      background: Rectangle {
        color: "transparent"
      }
    }

    Behavior on border.color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }

    Behavior on border.width {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }
  }

  // Error message
  OText {
    visible: root.hasError && root.errorMessage !== ""
    text: "⚠ " + root.errorMessage
    sizeMultiplier: 0.85
    color: Theme.critical
    Layout.fillWidth: true
    opacity: visible ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }
  }
}
