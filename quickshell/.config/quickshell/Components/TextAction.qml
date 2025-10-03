pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Utils

/**
 * TextAction - Generic text input component with action button
 *
 * A flexible text input component that can be used for passwords, PINs,
 * text fields, or any scenario requiring user text input with an action.
 *
 * Properties:
 *   - label: string - Optional label above the input field
 *   - description: string - Optional description below input (when no error)
 *   - placeholderText: string - Placeholder text in the input field
 *   - text: string - The input text value (bindable)
 *   - echoMode: int - TextInput.Password, TextInput.Normal, or TextInput.NoEcho
 *   - actionButtonText: string - Text on the action button (default: "Submit")
 *   - actionButtonIcon: string - Icon on the action button (empty to hide)
 *   - actionButtonEnabled: bool - Whether action button is enabled
 *   - hasError: bool - Whether to show error state
 *   - errorMessage: string - Error message to display
 *   - autoFocus: bool - Whether to auto-focus the input field (default: true)
 *   - leftMargin: real - Left margin for alignment (default: 0)
 *   - rightMargin: real - Right margin for alignment (default: 0)
 *
 * Signals:
 *   - textChanged() - Emitted when text changes
 *   - editingFinished() - Emitted when editing is finished
 *   - actionClicked() - Emitted when action button is clicked
 */
ColumnLayout {
  id: root

  // Public properties
  property string label: ""
  property string description: ""
  property string placeholderText: ""
  property string text: ""
  property int echoMode: TextInput.Normal
  property string actionButtonText: qsTr("Submit")
  property string actionButtonIcon: ""
  property bool actionButtonEnabled: text !== ""
  property bool hasError: false
  property string errorMessage: ""
  property bool autoFocus: true
  property real leftMargin: 0
  property real rightMargin: 0

  // Signals
  signal textInputChanged
  signal editingFinished
  signal actionClicked

  spacing: 4

  // Timer for delayed focus (gives layer shell time to grant keyboard focus)
  Timer {
    id: focusTimer
    interval: 100
    repeat: true
    running: false
    property int attempts: 0
    onTriggered: {
      if (root.autoFocus && textField) {
        textField.forceActiveFocus();
        attempts++;
        if (textField.activeFocus || attempts >= 5) {
          stop();
          attempts = 0;
        }
      }
    }
  }

  // Label (optional)
  Text {
    visible: root.label !== ""
    text: root.label
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.textActiveColor
    Layout.fillWidth: true
    Layout.leftMargin: root.leftMargin
    Layout.rightMargin: root.rightMargin
  }

  // Input field + Action button row
  RowLayout {
    Layout.fillWidth: true
    Layout.leftMargin: root.leftMargin
    Layout.rightMargin: root.rightMargin
    spacing: 8

    readonly property real buttonSize: Theme.itemHeight * 0.8
    readonly property real inputHeight: Theme.itemHeight * 0.8

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: parent.inputHeight
      color: Theme.bgColor
      border.color: root.hasError ? "#F38BA8" : textField.activeFocus ? Theme.activeColor : Theme.borderColor
      border.width: root.hasError ? 2 : 1
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
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 2
        anchors.bottomMargin: 2

        placeholderText: root.placeholderText
        echoMode: root.echoMode

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.textActiveColor
        selectionColor: Theme.activeColor
        selectedTextColor: Theme.textContrast(Theme.activeColor)

        background: Rectangle {
          color: "transparent"
        }

        onTextChanged: {
          root.text = text;
          root.textInputChanged();
        }

        onEditingFinished: root.editingFinished()

        Keys.onPressed: event => {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.actionButtonEnabled) {
              event.accepted = true;
              root.actionClicked();
            }
          }
        }

        Component.onCompleted: {
          if (root.autoFocus) {
            focusTimer.start();
          }
        }
      }
    }

    // Action button using IconButton
    IconButton {
      Layout.preferredWidth: parent.buttonSize
      Layout.preferredHeight: parent.buttonSize
      Layout.alignment: Qt.AlignVCenter

      icon: root.hasError ? "󰀦" : (root.actionButtonIcon || "")
      colorBg: root.hasError ? "#F38BA8" : Theme.activeColor
      enabled: root.actionButtonEnabled
      tooltipText: root.hasError ? qsTr("Retry") : (root.actionButtonText || qsTr("Submit"))

      onClicked: {
        if (root.actionButtonEnabled) {
          root.actionClicked();
        }
      }
    }
  }

  // Error message
  Text {
    visible: root.hasError && root.errorMessage !== ""
    text: "⚠ " + root.errorMessage
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize * 0.85
    color: "#F38BA8"
    Layout.fillWidth: true
    Layout.leftMargin: root.leftMargin
    Layout.rightMargin: root.rightMargin
    opacity: visible ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }
  }

  // Description text (shown when no error)
  Text {
    visible: !root.hasError && root.description !== ""
    text: root.description
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize * 0.85
    color: Theme.textInactiveColor
    opacity: 0.7
    Layout.fillWidth: true
    Layout.leftMargin: root.leftMargin
    Layout.rightMargin: root.rightMargin
  }
}
