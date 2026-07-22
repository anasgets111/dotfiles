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
  PolkitAgent {
    id: polkitAgent

    onAuthenticationRequestStarted: Logger.log("PolkitDialog", `Auth started: ${polkitAgent.flow?.message ?? '<no flow>'} for ${polkitAgent.flow?.actionId ?? '<no-action>'}`)
  }
  LazyLoader {
    active: polkitAgent.isActive

    component: DialogWindow {
    }
  }

  component DialogWindow: PanelWindow {
    id: window

    readonly property Region blurRegion: Region {
      item: dialogCard
      radius: dialogCard.radius
    }
    readonly property var flow: polkitAgent.flow

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
    PanelCard {
      id: dialogCard

      anchors.centerIn: parent
      color: Theme.glassSurfaceColor
      focus: true
      height: layout.implicitHeight + Theme.dialogPadding * 2
      padding: 0
      tone: "active"
      width: Theme.dialogWidth

      Keys.onEnterPressed: if (!(window.flow?.isResponseRequired ?? false))
        window.submit()
      Keys.onEscapePressed: window.flow?.cancelAuthenticationRequest()
      Keys.onReturnPressed: if (!(window.flow?.isResponseRequired ?? false))
        window.submit()

      ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Theme.dialogPadding
        spacing: Theme.spacingLg

        RowLayout {
          Layout.fillWidth: true
          spacing: Theme.spacingLg

          IconImage {
            Layout.preferredHeight: Theme.panelHeight
            Layout.preferredWidth: Theme.panelHeight
            source: Utils.resolveIconSource(window.flow?.iconName ?? "", "dialog-password")
          }
          ColumnLayout {
            Layout.fillWidth: true
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
