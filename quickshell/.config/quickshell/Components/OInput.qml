import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config

/**
 * OInput - Obelisk themed text input component
 *
 * A TextField wrapper with error states, placeholder support,
 * and Theme-based styling including focus indicators.
 *
 * Size presets: "sm", "md" (default), "lg"
 *
 * Examples:
 *   OInput { placeholderText: "Enter name" }
 *   OInput { size: "sm"; placeholderText: "Search..." }
 *   OInput { size: "lg"; hasError: true; errorMessage: "Invalid" }
 */
ColumnLayout {
  id: root

  // Computed from size using Theme helper functions
  readonly property int _fontSize: Theme.fontSizeFor(size)
  readonly property int _height: Theme.controlHeightFor(size)
  readonly property int _padding: Theme.spacingFor(size)

  // Input properties
  property bool autoFocus: false
  property alias echoMode: textField.echoMode
  property string errorMessage: ""

  // Error state
  property bool hasError: false
  property alias placeholderText: textField.placeholderText

  // Size preset: "sm", "md", "lg"
  property string size: "md"
  property alias text: textField.text

  signal inputAccepted
  signal inputChanged
  signal inputFinished

  function forceActiveFocus(): void {
    textField.forceActiveFocus();
  }

  spacing: Theme.spacingXs

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: root._height
    border.color: root.hasError ? Theme.critical : (textField.activeFocus ? Theme.activeColor : Theme.borderColor)
    border.width: root.hasError ? Theme.borderWidthMedium : Theme.borderWidthThin
    color: Theme.bgColor
    radius: Theme.radiusMd

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

      anchors.bottomMargin: Theme.spacingXs
      anchors.fill: parent
      anchors.leftMargin: root._padding
      anchors.rightMargin: root._padding
      anchors.topMargin: Theme.spacingXs
      color: Theme.textActiveColor
      font.family: Theme.fontFamily
      font.pixelSize: root._fontSize
      selectedTextColor: Theme.textContrast(Theme.activeColor)
      selectionColor: Theme.activeColor
      verticalAlignment: Text.AlignVCenter

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
    size: "sm"
    text: "⚠ " + root.errorMessage
    visible: root.hasError && root.errorMessage !== ""

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }
  }
}
