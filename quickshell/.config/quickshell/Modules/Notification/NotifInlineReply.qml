import QtQuick
import QtQuick.Controls
import qs.Config
import qs.Services.SystemInfo

Column {
  id: inlineReplyRoot
  required property var notification
  spacing: Math.round(Theme.panelMargin * 0.5)
  width: parent ? parent.width : implicitWidth

  TextField {
    id: replyTextField
    width: parent.width
    height: Theme.itemHeight
    placeholderText: "Reply…"
    color: NotificationService.style.actionFg
    selectionColor: NotificationService.style.accent
    font.family: NotificationService.style.fontFamily
    font.pointSize: Theme.fontSize
    background: Rectangle {
      radius: Theme.itemRadius
      color: NotificationService.style.actionBg
      border.color: NotificationService.style.actionBorder
      border.width: 1
    }
    onAccepted: inlineReplyRoot.sendReply()
  }

  Rectangle {
    id: sendButton
    radius: NotificationService.style.actionRadius
    color: NotificationService.style.actionBg
    border.color: NotificationService.style.actionBorder
    height: NotificationService.style.actionHeight
    width: Math.max(72, sendLabel.implicitWidth + NotificationService.style.actionPadding * 2)

    Text {
      id: sendLabel
      anchors.centerIn: parent
      text: "Send"
      color: NotificationService.style.actionFg
      font.family: NotificationService.style.fontFamily
      font.pointSize: NotificationService.style.bodyPointSize
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: sendButton.color = NotificationService.style.actionHoverBg
      onExited: sendButton.color = NotificationService.style.actionBg
      onClicked: inlineReplyRoot.sendReply()
    }
  }

  function sendReply() {
    const textValue = String(replyTextField.text || "")
    if (!textValue.length) return
    const result = NotificationService.sendInlineReply(notification, textValue)
    if (result?.ok) {
      NotificationService.dismissNotification(notification)
    }
  }
}
