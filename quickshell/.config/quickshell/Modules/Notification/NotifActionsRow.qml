pragma ComponentBehavior: Bound
import QtQuick
import qs.Config
import qs.Services.SystemInfo

Row {
  id: actionsRowRoot
  required property var notification
  spacing: Math.max(6, Math.round(Theme.panelMargin * 0.5))
  width: parent ? parent.width : implicitWidth

  Repeater {
    id: actionsRepeater
    model: (actionsRowRoot.notification && actionsRowRoot.notification.actions) ? actionsRowRoot.notification.actions : []
    delegate: Rectangle {
      id: actionDelegate
      required property var modelData
      property var notification: actionsRowRoot.notification

      radius: NotificationService.style.actionRadius
      color: NotificationService.style.actionBg
      border.color: NotificationService.style.actionBorder
      height: NotificationService.style.actionHeight
      implicitWidth: contentRow.implicitWidth + NotificationService.style.actionPadding * 2

      Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Math.round(Theme.panelMargin * 0.5)

        // Optional action icon if provided by the action entry
        Image {
          id: actionIconImage
          width: Math.max(16, Math.round(NotificationService.style.bodyPointSize * 1.6))
          height: width
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          source: String(actionDelegate.modelData?.icon || actionDelegate.modelData?.iconName || "")
          visible: source.toString().length > 0
        }

        Text {
          id: actionLabel
          text: String(actionDelegate.modelData?.title || actionDelegate.modelData?.text || actionDelegate.modelData?.label || "")
          color: NotificationService.style.actionFg
          font.family: NotificationService.style.fontFamily
          font.pointSize: NotificationService.style.bodyPointSize
          elide: Text.ElideRight
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.color = NotificationService.style.actionHoverBg
        onExited: parent.color = NotificationService.style.actionBg
        onClicked: {
          const actionIdentifier = String(actionDelegate.modelData?.identifier || actionDelegate.modelData?.id || actionDelegate.modelData?.action || "");
          NotificationService.invokeAction(actionDelegate.notification, actionIdentifier);
        }
      }
    }
  }
}
