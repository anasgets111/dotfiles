pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Config
import qs.Services.Utils

/**
 * MenuItem - Smart context menu item component
 *
 * Renders different item types based on modelData.itemType:
 * - "action": Simple clickable item with icon + label
 * - "textInput": Text input field with action button
 * - "separator": Visual divider (future)
 * - "toggle": Toggle switch (future)
 * - "header": Section header (future)
 *
 * Required properties:
 *   - modelData: var - Item data with itemType and type-specific fields
 *   - index: int - Item index in the list
 *
 * Optional properties (with defaults):
 *   - itemHeight: real - Height of the item (default: Theme.itemHeight)
 *   - itemPadding: real - Internal padding (default: 8)
 *   - parentListView: var - Parent ListView reference (default: null)
 *
 * Common modelData properties (all types):
 *   - itemType: string
 *   - visible: bool (default true)
 *   - enabled: bool (default true)
 *
 * Action type properties:
 *   - icon: string
 *   - label: string
 *   - action: string
 *   - actionIcon: string (optional right-side action button)
 *   - forgetIcon: string (optional secondary action button)
 *   - band: string (optional - for network band indicator)
 *   - bandColor: color (optional)
 *
 * TextInput type properties:
 *   - label: string
 *   - placeholder: string
 *   - echoMode: int (TextInput.Password, Normal, NoEcho)
 *   - hasError: bool
 *   - errorMessage: string
 *   - action: string (action ID for submit)
 *   - actionButton: { text: string, icon: string }
 *   - onTextChanged: function (optional callback)
 */
Item {
  id: menuItem

  required property var modelData
  required property int index

  property real itemHeight: Theme.itemHeight
  property real itemPadding: 8
  property var parentListView: null

  readonly property bool isVisible: modelData.visible ?? true
  readonly property bool isEnabled: modelData.enabled ?? true
  readonly property string itemType: modelData.itemType || "action"
  readonly property bool isTextInput: itemType === "textInput"
  readonly property bool hasError: isTextInput && (modelData.hasError ?? false)
  readonly property color textColor: hovered && isEnabled ? Theme.textOnHoverColor : Theme.textActiveColor

  property bool hovered: false

  signal triggered(string action, var data)

  width: parentListView.width
  height: {
    if (!isVisible)
      return 0;
    if (itemType === "textInput") {
      // Compact height: just the input + button height plus some padding
      const baseHeight = itemHeight * 0.8 + itemPadding * 2;
      return hasError ? baseHeight + itemHeight * 0.6 : baseHeight;
    }
    if (itemType === "separator")
      return 4;
    return itemHeight;
  }
  visible: isVisible
  opacity: isEnabled ? 1.0 : 0.5

  // Background for action items (not for textInput)
  Rectangle {
    anchors.fill: parent
    visible: menuItem.itemType === "action"
    color: menuItem.hovered && menuItem.isEnabled ? Theme.onHoverColor : "transparent"
    radius: Theme.itemRadius

    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }
  }

  // Content based on itemType
  Loader {
    id: contentLoader
    anchors.fill: parent

    sourceComponent: {
      if (menuItem.itemType === "action")
        return actionItemComponent;
      if (menuItem.itemType === "textInput")
        return textInputItemComponent;
      if (menuItem.itemType === "separator")
        return separatorComponent;
      return null;
    }
  }

  // Action item template
  Component {
    id: actionItemComponent

    RowLayout {
      spacing: 8

      // Icon with optional band indicator
      Item {
        visible: menuItem.modelData.icon !== undefined
        Layout.preferredWidth: Theme.fontSize * 1.5
        Layout.preferredHeight: menuItem.itemHeight
        Layout.leftMargin: menuItem.itemPadding
        Layout.alignment: Qt.AlignVCenter

        Column {
          id: contentCol
          anchors.centerIn: parent
          spacing: -2

          Text {
            text: menuItem.modelData.icon || ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: menuItem.modelData.bandColor || menuItem.textColor
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }

          Text {
            text: menuItem.modelData.band ? (menuItem.modelData.band === "2.4" ? "2.4" : menuItem.modelData.band) : ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.45
            font.bold: true
            color: menuItem.modelData.bandColor || menuItem.textColor
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            visible: menuItem.modelData.band !== undefined && menuItem.modelData.band !== ""

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }
        }
      }

      Text {
        text: menuItem.modelData.label || menuItem.modelData.text || ""
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: menuItem.textColor
        verticalAlignment: Text.AlignVCenter
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: menuItem.modelData.icon === undefined ? menuItem.itemPadding : 0

        Behavior on color {
          ColorAnimation {
            duration: Theme.animationDuration
          }
        }

        MouseArea {
          id: actionMouseArea
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          onEntered: menuItem.hovered = true
          onExited: menuItem.hovered = false

          onClicked: {
            if (menuItem.isEnabled) {
              menuItem.triggered(menuItem.modelData.action || menuItem.index.toString(), {});
            }
          }
        }
      }

      // Forget button (for saved networks)
      IconButton {
        visible: menuItem.modelData.forgetIcon !== undefined
        Layout.preferredWidth: menuItem.itemHeight * 0.8
        Layout.preferredHeight: menuItem.itemHeight * 0.8
        Layout.alignment: Qt.AlignVCenter
        Layout.rightMargin: 4

        icon: menuItem.modelData.forgetIcon || ""
        colorBg: "#F38BA8"
        tooltipText: qsTr("Forget Network")

        onClicked: {
          Logger.log("MenuItem", `Forget button clicked for action: ${menuItem.modelData.action}`);
          menuItem.triggered("forget-" + (menuItem.modelData.ssid || ""), {});
        }
      }

      // Action button (connect/disconnect)
      IconButton {
        visible: menuItem.modelData.actionIcon !== undefined
        Layout.preferredWidth: menuItem.itemHeight * 0.8
        Layout.preferredHeight: menuItem.itemHeight * 0.8
        Layout.alignment: Qt.AlignVCenter
        Layout.rightMargin: menuItem.itemPadding

        icon: menuItem.modelData.actionIcon || ""
        colorBg: Theme.activeColor
        tooltipText: menuItem.modelData.connected ? qsTr("Disconnect") : qsTr("Connect")

        onClicked: {
          const action = menuItem.modelData.action || "";
          Logger.log("MenuItem", `Action button clicked: ${action}`);
          menuItem.triggered(action, {});
        }
      }
    }
  }

  // Text input item template
  Component {
    id: textInputItemComponent

    RowLayout {
      spacing: 8

      // Icon (optional, like network items)
      Item {
        visible: menuItem.modelData.icon !== undefined
        Layout.preferredWidth: Theme.fontSize * 1.5
        Layout.preferredHeight: menuItem.itemHeight
        Layout.leftMargin: menuItem.itemPadding
        Layout.alignment: Qt.AlignVCenter

        Text {
          text: menuItem.modelData.icon || ""
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: menuItem.textColor
          anchors.centerIn: parent

          Behavior on color {
            ColorAnimation {
              duration: Theme.animationDuration
            }
          }
        }
      }

      // Text input component
      TextAction {
        Layout.fillWidth: true
        Layout.rightMargin: menuItem.itemPadding

        leftMargin: 0  // No additional left margin - already in RowLayout
        rightMargin: 0

        label: menuItem.modelData.label || ""
        placeholderText: menuItem.modelData.placeholder || ""
        echoMode: menuItem.modelData.echoMode ?? TextInput.Normal
        hasError: menuItem.modelData.hasError ?? false
        errorMessage: menuItem.modelData.errorMessage || ""
        actionButtonText: menuItem.modelData.actionButton?.text || qsTr("Submit")
        actionButtonIcon: menuItem.modelData.actionButton?.icon || ""

        onTextInputChanged: {
          // Call the optional onTextChanged callback from model
          if (menuItem.modelData.onTextChanged) {
            menuItem.modelData.onTextChanged();
          }
        }

        onActionClicked: {
          const action = menuItem.modelData.action || "";
          const inputText = text;
          Logger.log("MenuItem", `TextAction submitted for action: ${action}, value: ${inputText}`);
          menuItem.triggered(action, {
            value: inputText
          });
        }
      }
    }
  }

  // Separator template (future)
  Component {
    id: separatorComponent

    Rectangle {
      anchors.fill: parent
      color: Theme.borderColor
      opacity: 0.3
    }
  }
}
