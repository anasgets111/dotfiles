pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Services.SystemInfo
import qs.Config
import "./"

CardBase {
  id: card

  // Use a generic type to avoid static analysis errors when reading fields
  required property var wrapper

  signal actionTriggered(string id)
  signal dismiss
  signal replySubmitted(string text)

  implicitWidth: 360
  shown: !!(card.wrapper?.popup)

  // Urgency -> accent color
  readonly property string _urgency: NotificationService._urgencyToString(wrapper?.urgency)
  accentColor: _urgency === "critical" ? "#ff4d4f" : _urgency === "low" ? Qt.rgba(Theme.disabledColor.r, Theme.disabledColor.g, Theme.disabledColor.b, 0.9) : Theme.activeColor

  ColumnLayout {
    id: content
    spacing: 6

    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Rectangle {
        // Icon container
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        implicitWidth: 40
        implicitHeight: 40
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.05)
        visible: !!(card.wrapper?.iconSource)

        Image {
          anchors.centerIn: parent
          width: 30
          height: 30
          fillMode: Image.PreserveAspectFit
          smooth: true
          source: card.wrapper?.iconSource || ""
          sourceSize.height: 64
          sourceSize.width: 64
          visible: !!(card.wrapper?.iconSource)

          onStatusChanged: function () {
            if (status !== Image.Error)
              return;
            if (String(source).startsWith("image://qsimage/")) {
              try {
                if (typeof Quickshell !== "undefined" && Quickshell.iconPath) {
                  const fb = Quickshell.iconPath("dialog-information", true);
                  if (fb && fb !== source) {
                    source = fb;
                    return;
                  }
                }
              } catch (_) {}
            }
            parent.visible = false;
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Text {
            Layout.fillWidth: true
            color: "white"
            elide: Text.ElideRight
            font.bold: true
            text: card.wrapper?.summary || "(No title)"
          }

          Text {
            color: "#bbbbbb"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
            text: card.wrapper?.timeStr || ""
          }
        }

        Text {
          Layout.fillWidth: true
          color: "#dddddd"
          elide: Text.ElideRight
          maximumLineCount: 6
          text: card.wrapper?.bodySafe || ""
          textFormat: card.wrapper?.bodyFormat === "markup" ? Text.RichText : Text.PlainText
          wrapMode: Text.Wrap

          onLinkActivated: url => Qt.openUrlExternally(url)
        }
      }

      // Keep space; toggle via opacity only
      ToolButton {
        id: closeBtn
        icon.name: "window-close"
        display: AbstractButton.IconOnly
        Accessible.name: "Dismiss notification"
        opacity: (hoverArea.hovered || closeBtn.hovered) ? 1 : 0.0
        Behavior on opacity {
          NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
          }
        }
        onClicked: card.dismiss()
      }
    }

    Image {
      Layout.fillWidth: true
      Layout.preferredHeight: visible ? implicitHeight : 0
      antialiasing: true
      fillMode: Image.PreserveAspectFit
      smooth: true
      source: card.wrapper?.imageSource || ""
      sourceSize.height: 256
      sourceSize.width: 512
      visible: !!(card.wrapper?.imageSource)

      onStatusChanged: function () {
        if (status === Image.Error)
          visible = false;
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 6
      visible: !!(card.wrapper?.replyModel?.enabled) && !(card.wrapper?.replyModel?.submitted)

      function sendReply() {
        card.replySubmitted(replyField.text);
      }

      TextField {
        id: replyField
        Layout.fillWidth: true
        maximumLength: Math.max(0, Number(card.wrapper?.replyModel?.maxLength || 0))
        placeholderText: card.wrapper?.replyModel?.placeholder || "Reply..."
        onAccepted: parent.sendReply()
      }

      Button {
        enabled: {
          const min = Math.max(0, Number(card.wrapper?.replyModel?.minLength || 0));
          return replyField.text.length >= min;
        }
        text: "Send"
        Accessible.name: "Send reply"
        onClicked: parent.sendReply()
      }
    }

    Flow {
      Layout.fillWidth: true
      spacing: 6
      visible: (card.wrapper?.actionsModel || []).length > 0

      Repeater {
        model: card.wrapper?.actionsModel || []

        delegate: Button {
          id: actionBtn
          required property var modelData
          icon.source: modelData.iconSource || ""
          text: modelData.title || modelData.id
          padding: 6
          leftPadding: 12
          rightPadding: 12
          background: Rectangle {
            radius: 14
            color: actionBtn.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.07)
          }
          contentItem: Text {
            text: actionBtn.text
            color: "#e0e0e0"
            font.pixelSize: 12
            elide: Text.ElideRight
          }
          onClicked: card.actionTriggered(String(modelData.id))
        }
      }
    }
  }

  // Slim top progress bar
  Rectangle {
    id: progressBar
    visible: (card.wrapper?.timer?.interval || 0) > 0 && !!(card.wrapper?.timer?.running)
    height: 2
    radius: 1
    color: card.accentColor
    anchors.top: parent.top
    anchors.left: parent.left
    width: parent.width * (card.wrapper?.timer && card.wrapper.timer.interval > 0 ? Math.max(0, Math.min(1, card.wrapper.timer.remainingTime / card.wrapper.timer.interval)) : 0)
    Behavior on width {
      NumberAnimation {
        duration: Theme.animationDuration
        easing.type: Easing.OutCubic
      }
    }
  }

  HoverHandler {
    id: hoverArea
    acceptedDevices: PointerDevice.Mouse
  }

  Keys.onEscapePressed: card.dismiss()

  MouseArea {
    acceptedButtons: Qt.NoButton
    anchors.fill: parent
    hoverEnabled: true
    propagateComposedEvents: true
    onEntered: if (card.wrapper?.timer?.running)
      card.wrapper.timer.stop()
    onExited: if ((card.wrapper?.timer?.interval || 0) > 0 && !(card.wrapper?.timer?.running))
      card.wrapper.timer.start()
  }

  MouseArea {
    acceptedButtons: Qt.MiddleButton
    anchors.fill: parent
    onClicked: card.dismiss()
  }
}
