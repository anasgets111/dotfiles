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

  signal actionTriggered(string id)
  signal actionTriggeredEx(string id, var actionObject)
  signal dismiss

  // Common properties
  readonly property var notification: item.wrapper?.notification ?? item.wrapper
  readonly property string appName: notification?.appName || item.wrapper?.appName || ""
  readonly property string appIcon: notification?.appIcon || item.wrapper?.appIcon || ""
  readonly property string summaryText: notification?.summary || item.wrapper?.summary || "(No title)"
  readonly property string bodyText: notification?.body || item.wrapper?.body || ""
  readonly property bool hasInlineReply: !!notification?.hasInlineReply
  readonly property bool hasBodyText: bodyText && bodyText.trim() !== "" && bodyText.trim() !== summaryText.trim()

  property bool bodyExpanded: false
  property bool canExpandBody: hasBodyText && bodyText.length > 100 // Simple heuristic instead of hidden text

  // Common urgency and styling
  function urgencyToColor(urgency) {
    switch (urgency) {
    case NotificationUrgency.Critical:
      return "#ff4d4f";
    case NotificationUrgency.Low:
      return Qt.rgba(Theme.disabledColor.r, Theme.disabledColor.g, Theme.disabledColor.b, 0.9);
    default:
      return Theme.activeColor;
    }
  }

  readonly property color accentColor: urgencyToColor(notification?.urgency ?? NotificationUrgency.Normal)

  // Common actions model
  readonly property var actionsModel: (function () {
      const list = notification?.actions || item.wrapper?.actions || [];
      if (!list || !list.length)
        return [];
      return list.map(a => ({
            id: String(a.identifier || a.id || a.name || ""),
            title: String(a.text || a.title || ""),
            iconSource: (notification?.hasActionIcons && (a.identifier || "") ? Quickshell.iconPath(String(a.identifier), true) : ""),
            _obj: a
          }));
    })()

  implicitWidth: mode === "card" ? 380 : parent?.width ?? 380
  implicitHeight: content.implicitHeight + (mode === "card" ? 20 : 0)

  // Card mode: Use CardBase-like styling with animation
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

      // Card styling
      CardStyling {
        anchors.fill: parent
        accentColor: item.accentColor
      }
    }
  }

  // List mode: Simple hover background
  Rectangle {
    anchors.fill: parent
    radius: 6
    color: Qt.rgba(1, 1, 1, 0.04)
    visible: item.mode === "list" && mouseArea.containsMouse
  }

  ColumnLayout {
    id: content
    width: parent.width - (item.mode === "card" ? 20 : 0) // Account for CardBase padding
    x: item.mode === "card" ? 10 : 0
    y: item.mode === "card" ? 10 : 0
    spacing: item.mode === "card" ? 6 : 4

    // Row 1: Icons and controls (different layout for card vs list)
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      // Card mode: App icon on left
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

      // List mode: Small content icon on left
      Image {
        Layout.preferredWidth: visible ? 16 : 0
        Layout.preferredHeight: visible ? 16 : 0
        visible: item.mode === "list" && !!(item.wrapper?.cleanImage || item.notification?.image)
        fillMode: Image.PreserveAspectFit
        smooth: true
        source: item.wrapper?.cleanImage || item.notification?.image || ""
        onStatusChanged: if (status === Image.Error)
          visible = false
      }

      // Card mode: Large content icon (in row 2 content area)
      // List mode: Summary text
      Text {
        Layout.fillWidth: true
        visible: item.mode === "list"
        color: Theme.textActiveColor
        font.pixelSize: 13
        elide: Text.ElideRight
        text: item.summaryText
        wrapMode: Text.Wrap
        maximumLineCount: 2
      }

      // Spacer for card mode
      Item {
        Layout.fillWidth: true
        visible: item.mode === "card"
      }

      // Expand button
      StandardButton {
        buttonType: "control"
        visible: item.canExpandBody
        text: item.bodyExpanded ? "▴" : "▾"
        Accessible.name: item.bodyExpanded ? "Collapse" : "Expand"
        onClicked: item.bodyExpanded = !item.bodyExpanded

        // Smaller for list mode
        padding: item.mode === "list" ? 2 : 4
        leftPadding: item.mode === "list" ? 4 : 8
        rightPadding: item.mode === "list" ? 4 : 8
        font.pixelSize: item.mode === "list" ? 10 : 12
      }

      // Dismiss button
      StandardButton {
        buttonType: "control"
        text: "×"
        Accessible.name: "Dismiss notification"
        onClicked: item.dismiss()

        // Smaller for list mode
        padding: item.mode === "list" ? 2 : 4
        leftPadding: item.mode === "list" ? 6 : 8
        rightPadding: item.mode === "list" ? 6 : 8
      }
    }

    // Row 2: Card mode content (content icon + summary + expand arrow)
    RowLayout {
      Layout.fillWidth: true
      visible: item.mode === "card"
      spacing: 8

      // Content icon for card mode
      Image {
        Layout.preferredWidth: visible ? 32 : 0
        Layout.preferredHeight: visible ? 32 : 0
        visible: !!(item.wrapper?.cleanImage || item.notification?.image)
        fillMode: Image.PreserveAspectFit
        smooth: true
        source: item.wrapper?.cleanImage || item.notification?.image || ""
        onStatusChanged: if (status === Image.Error)
          visible = false
      }

      // Summary text for card mode
      Text {
        Layout.fillWidth: true
        color: Theme.textActiveColor
        font.bold: true
        elide: Text.ElideRight
        text: item.summaryText
      }
    }

    // Body text (both modes)
    Text {
      Layout.fillWidth: true
      Layout.preferredWidth: parent.width - (item.mode === "list" ? 24 : 0) // List mode left margin
      Layout.leftMargin: item.mode === "list" ? 24 : 0
      visible: item.hasBodyText
      color: Theme.textInactiveColor
      font.pixelSize: 12
      wrapMode: Text.WrapAnywhere
      textFormat: Text.PlainText
      text: item.bodyText
      maximumLineCount: item.bodyExpanded ? 0 : 2
      elide: Text.ElideRight
      onLinkActivated: url => Qt.openUrlExternally(url)
    }

    // Actions row
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
            }

            // Smaller for list mode
            padding: item.mode === "list" ? 4 : 6
            leftPadding: item.mode === "list" ? 8 : 12
            rightPadding: item.mode === "list" ? 8 : 12
            font.pixelSize: item.mode === "list" ? 11 : 12
          }
        }
      }
    }

    // Inline reply row
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

        MouseArea {
          anchors.fill: parent
          onClicked: parent.forceActiveFocus()
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
            if (item.notification && item.notification.hasInlineReply && item.notification.sendInlineReply) {
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

  // Common interaction handling
  Keys.onEscapePressed: item.dismiss()

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    hoverEnabled: true
    propagateComposedEvents: true

    onClicked: item.dismiss() // Middle-click dismiss
    onEntered: if (item.wrapper?.timer?.running)
      item.wrapper.timer.stop()
    onExited: if ((item.wrapper?.timer?.interval || 0) > 0 && !(item.wrapper?.timer?.running))
      item.wrapper.timer.start()
  }
}
