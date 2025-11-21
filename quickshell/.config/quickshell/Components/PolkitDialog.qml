pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

    onAuthenticationRequestStarted: {
      Logger.log("PolkitDialog", `Auth started: ${agent.flow ? agent.flow.message : '<no flow>'} for ${agent.flow ? agent.flow.actionId : '<no-action>'}`);
    }
  }

  LazyLoader {
    active: agent.isActive

    component: PanelWindow {
      id: window

      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "polkit-dialog"
      color: "#80000000"
      visible: true

      anchors {
        bottom: true
        left: true
        right: true
        top: true
      }

      Rectangle {
        id: content

        anchors.centerIn: parent
        border.color: Theme.activeColor
        border.width: 1
        color: Theme.bgColor
        height: layout.implicitHeight + 40
        radius: Theme.itemRadius
        width: 450

        ColumnLayout {
          id: layout

          readonly property var flow: agent.flow

          anchors.fill: parent
          anchors.margins: 20
          spacing: 16

          RowLayout {
            spacing: 16

            IconImage {
              Layout.preferredHeight: 48
              Layout.preferredWidth: 48
              source: Utils.resolveIconSource(layout.flow ? layout.flow.iconName : "", "dialog-password")
            }

            ColumnLayout {
              spacing: 4

              OText {
                Layout.fillWidth: true
                font.bold: true
                text: layout.flow ? layout.flow.message : ""
                wrapMode: Text.Wrap
              }

              OText {
                Layout.fillWidth: true
                color: Theme.textInactiveColor
                elide: Text.ElideMiddle
                sizeMultiplier: 0.8
                text: layout.flow ? layout.flow.actionId : ""
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: layout.flow && layout.flow.isResponseRequired

            OText {
              text: layout.flow ? layout.flow.inputPrompt : ""
              visible: text !== ""
            }

            OInput {
              id: passwordField

              Layout.fillWidth: true
              autoFocus: true
              echoMode: (layout.flow && layout.flow.responseVisible) ? TextInput.Normal : TextInput.Password
              placeholderText: qsTr("Password")

              onInputAccepted: {
                if (layout.flow) {
                  layout.flow.submit(text);
                  text = "";
                }
              }
            }

            OText {
              color: Theme.critical
              text: qsTr("Authentication Failed")
              visible: layout.flow && layout.flow.failed
            }
          }

          RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 8

            OButton {
              bgColor: Theme.inactiveColor
              text: qsTr("Cancel")

              onClicked: {
                if (layout.flow) {
                  layout.flow.cancelAuthenticationRequest();
                }
              }
            }

            OButton {
              bgColor: Theme.activeColor
              isEnabled: passwordField.text.length > 0
              text: qsTr("Authenticate")

              onClicked: {
                if (layout.flow) {
                  layout.flow.submit(passwordField.text);
                  passwordField.text = "";
                }
              }
            }
          }
        }
      }

      Connections {
        function onIsActiveChanged() {
          if (agent.isActive) {
            passwordField.text = "";
            passwordField.forceActiveFocus();
          }
        }

        target: agent
      }
    }
  }
}
