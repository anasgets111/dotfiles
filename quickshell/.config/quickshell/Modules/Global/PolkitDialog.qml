pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Polkit
import qs.Components
import qs.Config
import qs.Services.Utils

Item {
  id: root

  PolkitAgent {
    id: agent

    onAuthenticationRequestStarted: Logger.log("PolkitDialog", `Auth started: ${flow?.message ?? '<no flow>'} for ${flow?.actionId ?? '<no-action>'}`)
  }

  PanelWindow {
    id: window

    readonly property var flow: agent.flow

    function submit(): void {
      if (flow && passwordField.text) {
        flow.submit(passwordField.text);
        passwordField.text = "";
      }
    }

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "polkit-dialog"
    color: Theme.bgOverlay
    visible: agent.isActive

    onVisibleChanged: if (!visible)
      background.forceActiveFocus()

    anchors {
      bottom: true
      left: true
      right: true
      top: true
    }

    Connections {
      function onAuthenticationRequestStarted(): void {
        passwordField.text = "";
        Qt.callLater(passwordField.forceActiveFocus);
      }

      target: agent
    }

    Rectangle {
      id: background

      anchors.centerIn: parent
      border.color: Theme.activeColor
      border.width: 1
      color: Theme.bgColor
      height: layout.implicitHeight + Theme.dialogPadding * 2
      radius: Theme.itemRadius
      width: 450

      ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Theme.dialogPadding
        spacing: Theme.spacingLg

        RowLayout {
          spacing: Theme.spacingLg

          IconImage {
            Layout.preferredHeight: Theme.panelHeight
            Layout.preferredWidth: Theme.panelHeight
            source: Utils.resolveIconSource(window.flow?.iconName ?? "", "dialog-password")
          }

          ColumnLayout {
            spacing: Theme.spacingXs

            OText {
              Layout.fillWidth: true
              bold: true
              text: window.flow?.message ?? ""
              wrapMode: Text.Wrap
            }

            OText {
              Layout.fillWidth: true
              elide: Text.ElideMiddle
              muted: true
              size: "xs"
              text: window.flow?.actionId ?? ""
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Theme.spacingSm
          visible: window.flow?.isResponseRequired ?? false

          OText {
            text: window.flow?.inputPrompt ?? ""
            visible: text !== ""
          }

          OInput {
            id: passwordField

            Layout.fillWidth: true
            echoMode: window.flow?.responseVisible ? TextInput.Normal : TextInput.Password
            placeholderText: qsTr("Password")

            Keys.onEscapePressed: window.flow?.cancelAuthenticationRequest()
            onInputAccepted: window.submit()
          }

          OText {
            color: Theme.critical
            text: qsTr("Authentication Failed")
            visible: window.flow?.failed ?? false
          }
        }

        RowLayout {
          Layout.alignment: Qt.AlignRight
          spacing: Theme.spacingSm

          OButton {
            bgColor: Theme.inactiveColor
            text: qsTr("Cancel")

            onClicked: window.flow?.cancelAuthenticationRequest()
          }

          OButton {
            bgColor: Theme.activeColor
            isEnabled: passwordField.text.length > 0
            text: qsTr("Authenticate")

            onClicked: window.submit()
          }
        }
      }
    }
  }
}
