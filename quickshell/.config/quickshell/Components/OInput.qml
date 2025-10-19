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

  property bool autoFocus: false
  property alias echoMode: textField.echoMode
  property string errorMessage: ""
  property bool hasError: false
  property real inputHeight: Theme.itemHeight
  property alias placeholderText: textField.placeholderText
  property alias text: textField.text

  signal inputAccepted
  signal inputChanged
  signal inputFinished

  spacing: 4

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: root.inputHeight
    border.color: root.hasError ? Theme.critical : (textField.activeFocus ? Theme.activeColor : Theme.borderColor)
    border.width: root.hasError ? 2 : 1
    color: Theme.bgColor
    radius: Theme.itemRadius

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

    TextField {
      id: textField

      anchors.bottomMargin: 4
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      anchors.topMargin: 4
      color: Theme.textActiveColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      selectedTextColor: Theme.textContrast(Theme.activeColor)
      selectionColor: Theme.activeColor

      background: Rectangle {
        color: "transparent"
      }

      Component.onCompleted: {
        if (root.autoFocus)
          Qt.callLater(() => {
            textField.forceActiveFocus();
          });
      }
      onAccepted: root.inputAccepted()
      onEditingFinished: root.inputFinished()
      onTextChanged: root.inputChanged()
    }
  }

  // Error message
  OText {
    Layout.fillWidth: true
    color: Theme.critical
    opacity: visible ? 1 : 0
    sizeMultiplier: 0.85
    text: "⚠ " + root.errorMessage
    visible: root.hasError && root.errorMessage !== ""

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }
  }
}
