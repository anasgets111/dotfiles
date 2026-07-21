pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Components
import qs.Config
import qs.Services.Utils

Scope {
  id: root

  readonly property var flow: polkitAgent.flow

  PolkitAgent {
    id: polkitAgent

    onAuthenticationRequestStarted: Logger.log("PolkitDialog", `Auth started: ${root.flow?.message ?? '<no flow>'} for ${root.flow?.actionId ?? '<no-action>'}`)
  }
  LazyLoader {
    active: polkitAgent.isActive

    component: DialogWindow {
      agent: polkitAgent
    }
  }

  component DialogWindow: PanelWindow {
    id: window

    required property var agent
    readonly property Region blurRegion: Region {
      item: dialogCard
      radius: dialogCard.radius
    }
    readonly property var flow: agent.flow

    function submit(): void {
      if (flow && (passwordField.text || !flow.isResponseRequired)) {
        flow.submit(passwordField.text);
        passwordField.text = "";
      }
    }

    BackgroundEffect.blurRegion: window.blurRegion
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "polkit-dialog"
    color: Theme.bgOverlay

    anchors {
      bottom: true
      left: true
      right: true
      top: true
    }
    Rectangle {
      id: dialogCard

      anchors.centerIn: parent
      border.color: Theme.activeColor
      border.width: Theme.borderWidthThin
      color: Theme.bgPanel
      height: layout.implicitHeight + Theme.dialogPadding * 2
      radius: Theme.itemRadius
      width: Theme.dialogWidth

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

          onVisibleChanged: if (visible)
            passwordField.forceActiveFocus()

          OText {
            text: window.flow?.inputPrompt ?? ""
            visible: text !== ""
          }
          OInput {
            id: passwordField

            Layout.fillWidth: true
            autoFocus: true
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
            text: qsTr("Cancel")
            variant: "secondary"

            onClicked: window.flow?.cancelAuthenticationRequest()
          }
          OButton {
            isEnabled: !(window.flow?.isResponseRequired ?? false) || passwordField.text.length > 0
            text: qsTr("Authenticate")

            onClicked: window.submit()
          }
        }
      }
    }
  }
}
