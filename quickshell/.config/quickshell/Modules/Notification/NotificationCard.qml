pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Services.SystemInfo
// Utils singleton may not expose resolveIconSource at runtime in this context; avoid hard dependency
import Qt5Compat.GraphicalEffects

Control {
  id: card

  // Use project service to resolve urgency to avoid importing backend enums
  readonly property bool critical: NotificationService._urgencyToString(wrapper?.urgency) === "critical"
  readonly property bool low: NotificationService._urgencyToString(wrapper?.urgency) === "low"
  // Use a generic type to avoid static analysis errors when reading custom fields
  required property var wrapper

  signal actionTriggered(string id)
  signal dismiss
  signal replySubmitted(string text)

  implicitWidth: 360
  // Drive opacity directly instead of states for simpler parsing
  opacity: card.wrapper?.popup ? 1.0 : 0.0
  padding: 10

  background: Rectangle {
    border.color: card.critical ? "#ff5555" : "#2a2a2a"
    border.width: 1
    color: card.critical ? Qt.rgba(0.35, 0.05, 0.05, 0.96) : card.low ? Qt.rgba(0.12, 0.12, 0.12, 0.96) : Qt.rgba(0.16, 0.16, 0.16, 0.96)
    layer.enabled: true
    radius: 8

    layer.effect: DropShadow {
      color: Qt.rgba(0, 0, 0, 0.5)
      radius: 16
      samples: 25
      transparentBorder: true
    }
  }
  contentItem: ColumnLayout {
    spacing: 8

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Image {
        Layout.preferredHeight: 32
        Layout.preferredWidth: 32
        fillMode: Image.PreserveAspectFit
        smooth: true
        source: card.wrapper?.iconSource || ""
        sourceSize.height: 64
        sourceSize.width: 64
        visible: !!(card.wrapper?.iconSource)

        // Hide or fallback if the dynamic provider handle becomes invalid
        onStatusChanged: function () {
          if (status !== Image.Error)
            return;
          if (String(source).startsWith("image://qsimage/")) {
            // Attempt themed fallback via Quickshell.iconPath if available
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
          visible = false;
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
            text: (card.wrapper?.summary || "(No title)")
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

      ToolButton {
  icon.name: "window-close"
  display: AbstractButton.IconOnly
  // Accessible label without showing duplicate text
  Accessible.name: "Dismiss notification"
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

      TextField {
        id: replyField

        Layout.fillWidth: true
        maximumLength: Math.max(0, Number(card.wrapper?.replyModel?.maxLength || 0))
        placeholderText: (card.wrapper?.replyModel?.placeholder || "Reply...")
      }

      Button {
        enabled: {
          const min = Math.max(0, Number(card.wrapper?.replyModel?.minLength || 0));
          return replyField.text.length >= min;
        }
        text: "Send"

        onClicked: card.replySubmitted(replyField.text)
      }
    }

    Flow {
      Layout.fillWidth: true
      spacing: 6
      visible: (card.wrapper?.actionsModel || []).length > 0

      Repeater {
        model: card.wrapper?.actionsModel || []

        delegate: Button {
          required property var modelData

          icon.source: modelData.iconSource || ""
          text: modelData.title || modelData.id

          onClicked: card.actionTriggered(String(modelData.id))
        }
      }
    }

    Rectangle {
      property real cardTimeout: Number(card.wrapper?.timer?.interval || 0)

      Layout.fillWidth: true
      Layout.preferredHeight: 3
      color: "#333333"
      radius: 2
      visible: cardTimeout > 0

      Rectangle {
        property real progress

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: card.critical ? "#ff5555" : "#5aa0ff"
        height: parent.height
        radius: parent.radius
        width: (progress === undefined ? parent.width : progress * parent.width)

        NumberAnimation on progress {
          id: anim

          duration: Number(card.wrapper?.timer?.interval || 0)
          easing.type: Easing.Linear
          from: 1.0
          running: (card.wrapper?.timer?.interval || 0) > 0
          to: 0.0
        }
      }
    }
  }
  Behavior on opacity {
    NumberAnimation {
      duration: 150
    }
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
    hoverEnabled: false
    propagateComposedEvents: true

    onClicked: card.dismiss()
  }
}
