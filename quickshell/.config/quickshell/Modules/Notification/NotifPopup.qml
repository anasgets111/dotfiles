import QtQuick
import qs.Config
import qs.Services.Utils
import qs.Services.SystemInfo

Item {
  id: popupRoot
  required property var notification

  // Collapsing state and overflow flag
  property bool bodyCollapsed: true
  property bool bodyIsOverflowing: false
  property bool pointerHovering: false

  width: parent ? parent.width : 480
  implicitHeight: contentColumn.implicitHeight + Theme.panelMargin * 2

  // Slide-in on creation
  Component.onCompleted: NotificationService.enterAnimation(popupRoot)

  // Background
  Rectangle {
    anchors.fill: parent
    radius: Theme.itemRadius
    color: NotificationService.style.background
    border.color: NotificationService.style.border
    border.width: 1
  }

  // Hover pauses auto-dismiss
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: popupRoot.pointerHovering = true
    onExited: popupRoot.pointerHovering = false
    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton)
        NotificationService.dismissNotification(popupRoot.notification);
    }
  }

  // Auto-dismiss
  Timer {
    id: autoDismissTimer
    interval: {
      const explicitMs = typeof popupRoot.notification?.expireTimeout === "number" ? popupRoot.notification.expireTimeout : -1;
      if (explicitMs > 0)
        return explicitMs;
      const seconds = NotificationService.recommendedExpireSeconds(popupRoot.notification);
      return seconds > 0 ? Math.round(seconds * 1000) : 0;
    }
    repeat: false
    running: interval > 0
    onTriggered: {
      if (!popupRoot.pointerHovering && interval > 0) {
        NotificationService.dismissNotification(popupRoot.notification);
      } else if (interval > 0) {
        start();
      }
    }
  }

  // Content
  Column {
    id: contentColumn
    anchors {
      left: parent.left
      right: parent.right
      leftMargin: NotificationService.style.padding
      rightMargin: NotificationService.style.padding
      top: parent.top
      topMargin: NotificationService.style.padding
      bottom: parent.bottom
      bottomMargin: NotificationService.style.padding
    }
    spacing: NotificationService.style.spacing

    // Header
    Row {
      id: headerRow
      spacing: NotificationService.style.spacing
      width: parent.width

      // App icon
      Image {
        id: appIconImage
        width: NotificationService.style.iconSize
        height: NotificationService.style.iconSize
        fillMode: Image.PreserveAspectFit
        cache: false
        asynchronous: true
        sourceSize: Qt.size(width, height)
        // Resolve themed icon names to file paths with a sensible fallback
        source: Utils.resolveIconSource(String(popupRoot.notification?.appName || ""), popupRoot.notification?.appIcon, "dialog-information")
        visible: source.toString().length > 0
      }

      // Summary + app name
      Column {
        spacing: Math.round(NotificationService.style.spacing * 0.5)
        width: parent.width - (appIconImage.visible ? appIconImage.width + headerRow.spacing : 0) - closeButton.width - headerRow.spacing

        Text {
          id: summaryText
          text: String(popupRoot.notification?.summary || "")
          color: NotificationService.style.summary
          font.family: NotificationService.style.fontFamily
          font.pointSize: NotificationService.style.summaryPointSize
          font.bold: true
          wrapMode: Text.WordWrap
        }

        Text {
          id: appNameText
          text: String(popupRoot.notification?.appName || "")
          color: NotificationService.style.muted
          font.family: NotificationService.style.fontFamily
          font.pointSize: Math.max(9, NotificationService.style.bodyPointSize - 1)
          visible: text.length > 0
          elide: Text.ElideRight
        }
      }

      // Close
      Text {
        id: closeButton
        text: "×"
        color: NotificationService.style.summary
        font.family: NotificationService.style.fontFamily
        font.pointSize: NotificationService.style.summaryPointSize + 2
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        width: NotificationService.style.iconSize
        height: NotificationService.style.iconSize
        opacity: 0.8
        MouseArea {
          anchors.fill: parent
          onClicked: {
            const anim = NotificationService.exitAnimation(popupRoot);
            if (anim)
              anim.finished.connect(() => NotificationService.dismissNotification(popupRoot.notification));
            else
              NotificationService.dismissNotification(popupRoot.notification);
          }
        }
      }
    }

    // Optional banner image (content image)
    Image {
      id: contentImage
      width: parent.width
      asynchronous: true
      fillMode: Image.PreserveAspectFit
      source: String(popupRoot.notification?.image || "")
      visible: source.toString().length > 0
      // height bound to painted size for aspect fit
      height: visible ? Math.min(width * 0.75, paintedHeight > 0 ? paintedHeight : width * 0.56) : 0
      cache: false
      sourceSize: Qt.size(width, Math.round(width * 0.75))
    }

    // Body (wrapping-aware collapse)
    function formatForBodyText(rawText) {
      const bodyString = String(rawText || "");
      // Avoid RegExp.test lint: simple heuristic for markup
      const hasMarkup = bodyString.indexOf("<") !== -1 && bodyString.indexOf(">") !== -1;
      return {
        text: bodyString,
        isRich: hasMarkup
      };
    }
    readonly property var __fmt: formatForBodyText(popupRoot.notification?.body)

    Text {
      id: bodyText
      width: parent.width
      text: contentColumn.__fmt.text
      textFormat: contentColumn.__fmt.isRich ? Text.RichText : Text.PlainText
      wrapMode: Text.WordWrap
      color: NotificationService.style.body
      font.family: NotificationService.style.fontFamily
      font.pointSize: NotificationService.style.bodyPointSize

      maximumLineCount: popupRoot.bodyCollapsed ? NotificationService.style.bodyCollapsedLines : -1
      onLineCountChanged: popupRoot.bodyIsOverflowing = (lineCount > NotificationService.style.bodyCollapsedLines)
      onWidthChanged: popupRoot.bodyIsOverflowing = (lineCount > NotificationService.style.bodyCollapsedLines)
      onTextChanged: popupRoot.bodyIsOverflowing = (lineCount > NotificationService.style.bodyCollapsedLines)
      visible: text.length > 0
    }

    // Show more / less
    Row {
      spacing: NotificationService.style.spacing
      visible: bodyText.visible && popupRoot.bodyCollapsed && popupRoot.bodyIsOverflowing

      Text {
        text: popupRoot.bodyCollapsed ? "Show more" : "Show less"
        color: NotificationService.style.accent
        font.family: NotificationService.style.fontFamily
        font.pointSize: NotificationService.style.bodyPointSize
        MouseArea {
          anchors.fill: parent
          onClicked: popupRoot.bodyCollapsed = !popupRoot.bodyCollapsed
        }
      }
    }

    // Actions
    NotifActionsRow {
      id: actionsRow
      notification: popupRoot.notification
      visible: (popupRoot.notification?.actions || []).length > 0
    }

    // Inline reply
    NotifInlineReply {
      id: inlineReply
      notification: popupRoot.notification
      visible: !!popupRoot.notification && NotificationService.server.inlineReplySupported && !!popupRoot.notification.hasInlineReply
    }
  }
}
