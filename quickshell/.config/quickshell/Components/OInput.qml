import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config

ColumnLayout {
  id: root

  readonly property int _fontSize: Theme.fontSizeFor(size)
  readonly property int _height: Theme.controlHeightFor(size)
  readonly property int _padding: Theme.spacingFor(size)

  property bool autoFocus: false
  property alias echoMode: textField.echoMode
  property string errorMessage: ""

  property bool hasError: false
  property alias placeholderText: textField.placeholderText

  property string size: "md"
  property alias text: textField.text

  signal inputAccepted
  signal inputChanged
  signal keyPressed(var event)

  function clear(): void {
    textField.clear();
  }
  function forceActiveFocus(): void {
    textField.forceActiveFocus();
  }

  opacity: enabled ? 1 : Theme.opacityDisabled
  spacing: Theme.spacingXs

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: root._height
    border.color: root.hasError ? Theme.critical : (textField.activeFocus ? Theme.activeColor : Theme.glassBorderColor)
    border.width: root.hasError ? Theme.borderWidthMedium : Theme.borderWidthThin
    color: Theme.glassInputColor
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
      background: null
      color: Theme.textActiveColor
      font.family: Theme.fontFamily
      font.pixelSize: root._fontSize
      selectedTextColor: Theme.textContrast(Theme.activeColor)
      selectionColor: Theme.activeColor
      verticalAlignment: Text.AlignVCenter

      Component.onCompleted: {
        if (root.autoFocus)
          Qt.callLater(() => {
            textField.forceActiveFocus();
          });
      }
      Keys.onPressed: event => root.keyPressed(event)
      onAccepted: root.inputAccepted()
      onTextChanged: root.inputChanged()
    }
  }

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
