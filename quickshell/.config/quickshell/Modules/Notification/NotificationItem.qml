pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.Services.Utils
import qs.Config

Item {
  id: item
  required property var wrapper
  property string mode: "card" // "card" or "list"

  signal actionTriggeredEx(string id, var actionObject)
  signal dismiss
  signal inputFocusRequested // Signal when text input needs focus

  // Normalized accessors
  readonly property var notification: item.wrapper?.notification ?? item.wrapper
  readonly property string appName: notification?.appName || item.wrapper?.appName || ""
  readonly property string appIcon: notification?.appIcon || item.wrapper?.appIcon || ""
  readonly property string summaryText: notification?.summary || item.wrapper?.summary || "(No title)"
  readonly property string bodyText: notification?.body || item.wrapper?.body || ""
  readonly property bool hasInlineReply: !!notification?.hasInlineReply
  readonly property bool hasBodyText: bodyText && bodyText.trim() !== "" && bodyText.trim() !== summaryText.trim()
  readonly property url contentImageSource: item.wrapper?.cleanImage || item.notification?.image || ""

  property bool bodyExpanded: false
  readonly property bool canExpandBody: hasBodyText && bodyText.length > 100

  // Urgency styling
  readonly property string urgency: (function () {
      const u = notification?.urgency ?? NotificationUrgency.Normal;
      switch (u) {
      case NotificationUrgency.Low:
        return "low";
      case NotificationUrgency.Critical:
        return "critical";
      default:
        return "normal";
      }
    })()
  readonly property color accentColor: urgency === "critical" ? "#ff4d4f" : urgency === "low" ? Qt.rgba(Theme.disabledColor.r, Theme.disabledColor.g, Theme.disabledColor.b, 0.9) : Theme.activeColor

  // Actions model (flat, stable id/title)
  readonly property var actionsModel: (function () {
      const list = notification?.actions || item.wrapper?.actions || [];
      return (list && list.length) ? list.map(a => ({
            id: String(a.identifier || a.id || a.name || ""),
            title: String(a.text || a.title || ""),
            iconSource: (notification?.hasActionIcons && (a.identifier || "")) ? Utils.resolveIconSource(String(a.identifier)) : "",
            _obj: a
          })) : [];
    })()

  implicitWidth: mode === "card" ? 380 : parent?.width ?? 380
  implicitHeight: content.implicitHeight + (mode === "card" ? 20 : 0)

  // Card shell + slide-in
  Loader {
    active: item.mode === "card"
    anchors.fill: parent
    sourceComponent: Item {
      property bool _animReady: false
      x: !_animReady ? width + (Theme.popupOffset || 12) : 0
      Behavior on x {
        NumberAnimation {
          duration: (Theme.animationDuration || 200) * 1.4
          easing.type: Easing.OutCubic
        }
      }
      Component.onCompleted: Qt.callLater(() => _animReady = true)
      CardStyling {
        anchors.fill: parent
        accentColor: item.accentColor
      }
    }
  }

  // Hover highlight for list
  Rectangle {
    anchors.fill: parent
    radius: 6
    color: Qt.rgba(1, 1, 1, 0.04)
    visible: item.mode === "list" && mouseArea.containsMouse
  }

  ColumnLayout {
    id: content
    width: parent.width - (item.mode === "card" ? 20 : 0)
    x: item.mode === "card" ? 10 : 0
    y: item.mode === "card" ? 10 : 0
    spacing: item.mode === "card" ? 6 : 4

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      // App icon (card)
      Rectangle {
        Layout.preferredWidth: visible ? 40 : 0
        Layout.preferredHeight: visible ? 40 : 0
        visible: item.mode === "card" && !!(item.appIcon || item.appName)
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.05)
        Image {
          anchors.centerIn: parent
          width: 30
          height: 30
          fillMode: Image.PreserveAspectFit
          smooth: true
          source: Utils.resolveIconSource(item.appName, item.appIcon, "dialog-information")
          sourceSize: Qt.size(64, 64)
          onStatusChanged: if (status === Image.Error)
            parent.visible = false
        }
      }

      // Content icon (list, small)
      Image {
        Layout.preferredWidth: visible ? 16 : 0
        Layout.preferredHeight: visible ? 16 : 0
        visible: item.mode === "list" && !!item.contentImageSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        source: item.contentImageSource
        onStatusChanged: if (status === Image.Error)
          visible = false
      }

      // Summary text (both card and list mode)
      Text {
        Layout.fillWidth: true
        color: item.mode === "card" ? "white" : "#dddddd"
        font.bold: item.mode === "card"
        font.pixelSize: item.mode === "card" ? 14 : 13
        elide: Text.ElideRight
        text: item.summaryText
        wrapMode: Text.Wrap
        maximumLineCount: item.mode === "card" ? 1 : 2
        horizontalAlignment: item.mode === "card" ? Text.AlignHCenter : Text.AlignLeft
      }

      // Expand toggle
      StandardButton {
        buttonType: "control"
        visible: item.canExpandBody
        text: item.bodyExpanded ? "▴" : "▾"
        Accessible.name: item.bodyExpanded ? "Collapse" : "Expand"
        onClicked: item.bodyExpanded = !item.bodyExpanded
        padding: item.mode === "list" ? 2 : 4
        leftPadding: item.mode === "list" ? 4 : 8
        rightPadding: item.mode === "list" ? 4 : 8
        font.pixelSize: item.mode === "list" ? 10 : 12
      }

      // Dismiss
      StandardButton {
        buttonType: "control"
        text: "×"
        Accessible.name: "Dismiss notification"
        onClicked: item.dismiss()
        padding: item.mode === "list" ? 2 : 4
        leftPadding: item.mode === "list" ? 6 : 8
        rightPadding: item.mode === "list" ? 6 : 8
      }
    }

    // Content image (card mode only, if present)
    Image {
      Layout.preferredWidth: visible ? 32 : 0
      Layout.preferredHeight: visible ? 32 : 0
      Layout.alignment: Qt.AlignHCenter
      visible: item.mode === "card" && !!item.contentImageSource
      fillMode: Image.PreserveAspectFit
      smooth: true
      source: item.contentImageSource
      onStatusChanged: if (status === Image.Error)
        visible = false
    }

    // Body
    Text {
      Layout.fillWidth: true
      Layout.preferredWidth: parent.width - (item.mode === "list" ? 24 : 0)
      Layout.leftMargin: item.mode === "list" ? 24 : 0
      visible: item.hasBodyText
      color: "#bbbbbb"
      font.pixelSize: 12
      wrapMode: Text.WrapAnywhere
      textFormat: Text.PlainText
      text: item.bodyText
      maximumLineCount: item.bodyExpanded ? 0 : 2
      elide: Text.ElideRight
      onLinkActivated: url => Qt.openUrlExternally(url)
    }

    // Actions
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: item.mode === "list" ? 24 : 0
      Layout.alignment: item.mode === "card" ? Qt.AlignHCenter : Qt.AlignLeft
      visible: item.actionsModel.length > 0
      spacing: item.mode === "card" ? 6 : 4

      Flow {
        spacing: 4
        Repeater {
          model: item.actionsModel
          delegate: StandardButton {
            required property var modelData
            buttonType: "action"
            text: modelData.title || modelData.id || ""
            onClicked: {
              item.actionTriggeredEx(modelData.id, modelData._obj);
              if (item.mode === "card")
                item.dismiss();
            }
            padding: item.mode === "list" ? 4 : 6
            leftPadding: item.mode === "list" ? 8 : 12
            rightPadding: item.mode === "list" ? 8 : 12
            font.pixelSize: item.mode === "list" ? 11 : 12
          }
        }
      }
    }

    // Inline reply
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: item.mode === "list" ? 24 : 0
      visible: item.hasInlineReply
      spacing: 6

      TextField {
        id: replyField
        Layout.fillWidth: true
        placeholderText: item.notification?.inlineReplyPlaceholder || "Reply"
        selectByMouse: true
        activeFocusOnPress: true
        font.pixelSize: item.mode === "list" ? 12 : 14
        padding: item.mode === "list" ? 6 : 8
        Keys.onReturnPressed: sendBtn.clicked()
        Keys.onEnterPressed: sendBtn.clicked()

        onActiveFocusChanged: {
          if (activeFocus) {
            item.inputFocusRequested();
          }
        }
      }

      StandardButton {
        id: sendBtn
        buttonType: "action"
        text: "Send"
        font.pixelSize: item.mode === "list" ? 11 : 12
        padding: item.mode === "list" ? 4 : 6
        onClicked: {
          const replyText = String(replyField.text || "");
          try {
            if (item.notification?.hasInlineReply && item.notification.sendInlineReply) {
              item.notification.sendInlineReply(replyText);
            }
          } catch (e) {
            console.log("Error sending reply:", e);
          }
          replyField.text = "";
        }
      }
    }
  }

  // Interaction and hover timer pause
  Keys.onEscapePressed: item.dismiss()
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    hoverEnabled: true
    propagateComposedEvents: true
    onClicked: item.dismiss()
    onEntered: if (item.wrapper?.timer?.running)
      item.wrapper.timer.stop()
    onExited: if ((item.wrapper?.timer?.interval || 0) > 0 && !(item.wrapper?.timer?.running))
      item.wrapper.timer.start()
  }
}
