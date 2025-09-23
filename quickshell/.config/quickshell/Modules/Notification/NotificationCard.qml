pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.Services.SystemInfo
import qs.Services.Utils  // For resolveIconSource
import qs.Config
import "./"

CardBase {
  id: card

  // Use a generic type to avoid static analysis errors when reading fields
  required property var wrapper

  signal actionTriggered(string id)
  signal dismiss
  // signal replySubmitted(string text)  // Omitted; not implemented in new API

  implicitWidth: 360
  shown: !!(card.wrapper?.popup)

  // Local urgency string (old service._urgencyToString removed)
  readonly property string _urgency: (function () {
      const u = card.wrapper?.urgency ?? 0;
      switch (u) {
      case NotificationUrgency.Low:
        return "low";
      case NotificationUrgency.Critical:
        return "critical";
      default:
        return "normal";
      }
    })()
  accentColor: _urgency === "critical" ? "#ff4d4f" : _urgency === "low" ? Qt.rgba(Theme.disabledColor.r, Theme.disabledColor.g, Theme.disabledColor.b, 0.9) : Theme.activeColor

  // Computed actionsModel from notification.actions (fallback to wrapper.actions)
  readonly property var actionsModel: (function () {
      let raw = [];
      try {
        const a = card.wrapper && card.wrapper.notification && card.wrapper.notification.actions;
        if (a && a.length !== undefined)
          raw = a;
      } catch (e) {}
      if (!raw || raw.length === undefined)
        raw = card.wrapper?.actions || [];
      if (!raw.length)
        return [];
      const out = [];
      if (typeof raw[0] === "string") {
        // Alternating id/title strings
        for (let i = 0; i < raw.length; i += 2) {
          if (i + 1 < raw.length) {
            out.push({
              id: String(raw[i]),
              title: String(raw[i + 1]),
              iconSource: ""  // No icons in string mode
              ,
              trigger: function () {
                card.actionTriggered(String(raw[i]));
              }
            });
          }
        }
      } else {
        // Object array
        raw.forEach(a => {
          if (a) {
            const id = String(a.id || a.key || a.name || a.action || "");
            const title = String(a.title || a.label || a.text || "");
            const icon = String(a.icon || a.iconName || a.icon_id || "");
            out.push({
              id: id,
              title: title,
              iconSource: icon ? Quickshell.iconPath(icon, true) : "",
              _actionObj: a,
              trigger: function () {
                card.actionTriggered(id);
              }
            });
          }
        });
      }
      return out;
    })()

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
        visible: !!(card.wrapper?.appIcon || card.wrapper?.appName)

        Image {
          anchors.centerIn: parent
          width: 30
          height: 30
          fillMode: Image.PreserveAspectFit
          smooth: true
          source: Utils.resolveIconSource(card.wrapper?.appName || "", card.wrapper?.appIcon || "", "dialog-information")
          sourceSize.height: 64
          sourceSize.width: 64

          onStatusChanged: function () {
            if (status !== Image.Error)
              return;
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
          text: card.wrapper?.htmlBody || ""  // Adapted to new htmlBody (Markdown/HTML)
          textFormat: Text.RichText  // Always RichText for htmlBody
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
      source: card.wrapper?.cleanImage || ""  // Adapted to new cleanImage
      sourceSize.height: 256
      sourceSize.width: 512
      visible: !!(card.wrapper?.cleanImage)

      onStatusChanged: function () {
        if (status === Image.Error)
          visible = false;
      }
    }

    // Reply omitted; add back if reply API is restored (e.g., wrapper.notification.hasInlineReply, etc.)
    /*
    RowLayout {
      // ... (similar to old, but use wrapper.notification.hasInlineReply for visible,
      // placeholder: wrapper.notification.replyPlaceholder || "",
      // on send: wrapper.notification.sendReply(replyField.text); card.dismiss()
    }
    */

    Flow {
      Layout.fillWidth: true
      spacing: 6
      visible: (card.actionsModel || []).length > 0

      Repeater {
        model: card.actionsModel

        delegate: Button {
          id: actionBtn
          required property var modelData
          icon.source: modelData.iconSource || ""
          text: modelData.title || modelData.id || ""
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
          onClicked: (modelData.trigger || function () {
              card.actionTriggered(modelData.id);
            })()
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
