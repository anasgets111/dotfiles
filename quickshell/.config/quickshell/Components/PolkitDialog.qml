pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Polkit
import qs.Config
import qs.Components
import qs.Services.Utils

Item {
  id: root

  PolkitAgent {
    id: agent

    onAuthenticationRequestStarted: Logger.log("PolkitDialog", `Auth started: ${agent.flow?.message ?? '<no flow>'} for ${agent.flow?.actionId ?? '<no-action>'}`)
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
    color: "#80000000"
    visible: agent.isActive

    anchors {
      bottom: true
      left: true
      right: true
      top: true
    }

    Rectangle {
      anchors.centerIn: parent
      border.color: Theme.activeColor
      border.width: 1
      color: Theme.bgColor
      height: layout.implicitHeight + 40
      radius: Theme.itemRadius
      width: 450

      ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        RowLayout {
          spacing: 16

          IconImage {
            Layout.preferredHeight: 48
            Layout.preferredWidth: 48
            source: Utils.resolveIconSource(window.flow?.iconName ?? "", "dialog-password")
          }

          ColumnLayout {
            spacing: 4

            OText {
              Layout.fillWidth: true
              font.bold: true
              text: window.flow?.message ?? ""
              wrapMode: Text.Wrap
            }

            OText {
              Layout.fillWidth: true
              color: Theme.textInactiveColor
              elide: Text.ElideMiddle
              sizeMultiplier: 0.8
              text: window.flow?.actionId ?? ""
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 8
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
          spacing: 8

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

    Connections {
      function onAuthenticationRequestStarted(): void {
        passwordField.text = "";
        passwordField.forceActiveFocus();
      }

      target: agent
    }
  }
}
