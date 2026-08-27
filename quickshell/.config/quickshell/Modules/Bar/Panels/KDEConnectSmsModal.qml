pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Services.Core

OModal {
  id: root

  property bool composing: false
  readonly property var device: KDEConnectService.deviceForId(KDEConnectService.smsDeviceId)
  readonly property var filteredThreads: {
    const needle = search.text.trim().toLowerCase();
    return needle ? KDEConnectService.smsThreads.filter(thread => (`${titleFor(thread)} ${thread.body}`).toLowerCase().includes(needle)) : KDEConnectService.smsThreads;
  }
  readonly property var selectedThread: KDEConnectService.smsThreads.find(thread => thread.threadId === KDEConnectService.smsThreadId) ?? null
  property bool sending: false

  function formatTime(timestamp: real): string { return timestamp > 0 ? new Date(timestamp).toLocaleString(Qt.locale(), Locale.ShortFormat) : ""; }
  function selectThread(thread): void {
    composing = !thread;
    recipient.text = composing ? search.text.trim() : "";
    message.clear();
    KDEConnectService.loadSmsConversation(thread ? thread.threadId : "");
    if (composing)
      Qt.callLater(() => recipient.forceActiveFocus());
  }
  function submit(): void {
    const body = message.text.trim();
    const destination = recipient.text.trim();
    if (!body || sending || (composing ? !destination : !KDEConnectService.smsThreadId))
      return;
    sending = true;
    KDEConnectService.sendSms(body, destination, error => {
      root.sending = false;
      if (!error)
        message.clear();
    });
  }
  function titleFor(thread: var): string { return (thread?.addresses ?? []).join(", ") || qsTr("Unknown sender"); }

  preferredHeight: Theme.smsModalHeight
  preferredWidth: Theme.smsModalWidth
  searchInput: search

  onDismissed: KDEConnectService.closeSms()
  onFilteredThreadsChanged: if (!composing && !KDEConnectService.smsThreadId && filteredThreads.length)
    selectThread(filteredThreads[0])

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    PanelHeader {
      Layout.margins: Theme.spacingLg
      icon: "󰍦"
      subtitle: root.device?.name ?? ""
      title: qsTr("Messages")
    }
    RowLayout {
      Layout.fillHeight: true
      Layout.fillWidth: true
      spacing: 0

      Item {
        Layout.fillHeight: true
        Layout.preferredWidth: Theme.smsSidebarWidth

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Theme.spacingLg
          spacing: Theme.spacingSm

          RowLayout {
            Layout.fillWidth: true

            OText {
              Layout.fillWidth: true
              bold: true
              text: qsTr("Conversations")
            }
            OButton {
              icon: "󰐕"
              size: "sm"
              text: qsTr("New")
              variant: "secondary"

              onClicked: root.selectThread()
            }
          }
          OInput {
            id: search

            Layout.fillWidth: true
            placeholderText: qsTr("Search or enter a number")
            size: "sm"

            onInputAccepted: root.selectThread()
          }
          Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            ListView {
              id: threadList

              anchors.fill: parent
              boundsBehavior: Flickable.StopAtBounds
              clip: true
              model: root.filteredThreads

              ScrollBar.vertical: ScrollBar {}
              delegate: PanelRow {
                required property var modelData

                enabled: !KDEConnectService.smsMessagesLoading
                selected: !root.composing && KDEConnectService.smsThreadId === modelData.threadId
                subtitle: String(modelData.body).replace(/\s+/g, " ").trim()
                title: root.titleFor(modelData)
                width: threadList.width

                onClicked: root.selectThread(modelData)
              }
            }
            PanelEmptyState {
              anchors.fill: parent
              icon: "󰍦"
              text: search.text ? qsTr("No matching conversations") : qsTr("No conversations")
              visible: !KDEConnectService.smsLoading && root.filteredThreads.length === 0
            }
          }
        }
      }
      Item {
        Layout.fillHeight: true
        Layout.fillWidth: true

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Theme.spacingLg
          spacing: Theme.spacingMd
          visible: root.composing || root.selectedThread !== null

          OText {
            Layout.fillWidth: true
            bold: true
            size: "lg"
            text: root.composing ? qsTr("New message") : root.titleFor(root.selectedThread)
          }
          OInput {
            id: recipient

            Layout.fillWidth: true
            placeholderText: qsTr("Phone number")
            visible: root.composing
          }
          OText {
            Layout.fillWidth: true
            color: Theme.critical
            size: "sm"
            text: KDEConnectService.error
            visible: text !== ""
            wrapMode: Text.Wrap
          }
          Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            ListView {
              id: messageList

              anchors.fill: parent
              boundsBehavior: Flickable.StopAtBounds
              clip: true
              model: root.composing ? null : KDEConnectService.smsMessages
              spacing: Theme.spacingSm

              ScrollBar.vertical: ScrollBar {}
              delegate: ColumnLayout {
                id: messageRow

                required property var modelData

                spacing: 0
                width: messageList.width

                OText {
                  Layout.alignment: messageRow.modelData.fromMe ? Qt.AlignRight : Qt.AlignLeft
                  Layout.maximumWidth: messageRow.width * 0.72
                  color: messageRow.modelData.fromMe ? Theme.activeColor : Theme.textActiveColor
                  text: messageRow.modelData.body
                  wrapMode: Text.Wrap
                }
                OText {
                  Layout.alignment: messageRow.modelData.fromMe ? Qt.AlignRight : Qt.AlignLeft
                  color: Theme.textInactiveColor
                  size: "xs"
                  text: root.formatTime(messageRow.modelData.date)
                }
              }

              onCountChanged: Qt.callLater(() => positionViewAtEnd())
            }
            OSpinner {
              anchors.centerIn: parent
              running: KDEConnectService.smsMessagesLoading
            }
            PanelEmptyState {
              anchors.fill: parent
              icon: root.composing ? "󰐕" : "󰍦"
              text: root.composing ? qsTr("Enter a number and write a message") : qsTr("No messages loaded")
              visible: root.composing || (!KDEConnectService.smsMessagesLoading && KDEConnectService.smsMessages.length === 0)
            }
          }
          RowLayout {
            Layout.fillWidth: true

            TextArea {
              id: message

              Layout.fillWidth: true
              Layout.preferredHeight: Math.min(Math.max(Theme.controlHeightXl, contentHeight + topPadding + bottomPadding), Theme.controlHeightXl * 3)
              clip: true
              color: Theme.textActiveColor
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontMd
              placeholderText: qsTr("Message")
              placeholderTextColor: Theme.textInactiveColor
              wrapMode: TextEdit.Wrap

              background: Rectangle {
                border.color: message.activeFocus ? Theme.activeColor : Theme.glassBorderColor
                border.width: Theme.borderWidthThin
                color: Theme.glassInputColor
                radius: Theme.radiusMd
              }

              Keys.onPressed: event => {
                if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                  root.submit();
                  event.accepted = true;
                }
              }
            }
            OButton {
              Layout.alignment: Qt.AlignBottom
              icon: "󰒊"
              isEnabled: !root.sending && message.text.trim() !== "" && (KDEConnectService.smsThreadId !== "" || recipient.text.trim() !== "")
              text: root.sending ? qsTr("Sending…") : qsTr("Send")

              onClicked: root.submit()
            }
          }
        }
        OSpinner {
          anchors.centerIn: parent
          running: KDEConnectService.smsLoading
        }
        PanelEmptyState {
          anchors.centerIn: parent
          icon: "󰍦"
          subtext: qsTr("Choose a conversation or start a new message.")
          text: qsTr("Messages")
          visible: !KDEConnectService.smsLoading && !root.composing && root.selectedThread === null
        }
      }
    }
  }
}
