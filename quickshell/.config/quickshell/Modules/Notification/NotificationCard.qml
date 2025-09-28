pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services.Utils
import qs.Config

Item {
  id: root

  required property var svc
  property var wrapper: null
  property var group: null

  signal inputFocusRequested

  readonly property bool isGroup: !!group
  readonly property var items: isGroup ? (group?.notifications || []) : (wrapper ? [wrapper] : [])
  readonly property var primaryWrapper: items.length > 0 ? items[0] : null
  readonly property bool groupExpanded: !isGroup || (svc?.expandedGroups ? (svc.expandedGroups[group.key] || false) : false)
  readonly property bool headerHasExpand: isGroup && items.length > 1
  readonly property string headerTitle: isGroup ? `${group?.appName || "app"} (${group?.count || items.length})` : (primaryWrapper?.appName || "app")
  readonly property color accentColor: primaryWrapper?.accentColor || Theme.activeColor

  readonly property real cardWidth: 380
  implicitWidth: cardWidth
  implicitHeight: frame.implicitHeight

  property var _messageExpansion: ({})
  function toggleMessageExpansion(id) {
    if (!id)
      return;
    const next = {};
    for (const key in root._messageExpansion)
      next[key] = root._messageExpansion[key];
    next[id] = !next[id];
    root._messageExpansion = next;
  }
  function messageExpanded(id) {
    return id ? !!root._messageExpansion[id] : false;
  }

  Keys.onEscapePressed: {
    if (root.isGroup)
      root.svc?.dismissGroup(root.group?.key);
    else if (root.primaryWrapper)
      root.svc?.dismissNotification(root.primaryWrapper);
  }

  property bool _animReady: false
  x: !_animReady ? width + (Theme.popupOffset || 12) : 0
  Behavior on x {
    NumberAnimation {
      duration: (Theme.animationDuration || 200) * 1.4
      easing.type: Easing.OutCubic
    }
  }
  Component.onCompleted: Qt.callLater(() => _animReady = true)

  Item {
    id: frame
    width: root.cardWidth
    implicitHeight: cardColumn.implicitHeight + 24

    CardStyling {
      anchors.fill: parent
      accentColor: root.accentColor
    }

    ColumnLayout {
      id: cardColumn
      anchors.fill: parent
      anchors.margins: 12
      spacing: 10

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Loader {
          Layout.preferredWidth: active ? 40 : 0
          Layout.preferredHeight: active ? 40 : 0
          active: !!root.primaryWrapper
          sourceComponent: Rectangle {
            width: 40
            height: 40
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
              source: Utils.resolveIconSource(root.primaryWrapper?.appName || "app", root.primaryWrapper?.appIcon, "dialog-information")
              sourceSize: Qt.size(64, 64)
              onStatusChanged: if (status === Image.Error)
                parent.parent.active = false
            }
          }
        }

        Text {
          Layout.fillWidth: true
          text: root.headerTitle
          color: "white"
          font.bold: true
          font.pixelSize: 15
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }

        RowLayout {
          spacing: 6

          Loader {
            active: root.headerHasExpand
            sourceComponent: StandardButton {
              buttonType: "control"
              text: root.groupExpanded ? "▴" : "▾"
              Accessible.name: root.groupExpanded ? "Collapse group" : "Expand group"
              onClicked: root.svc?.toggleGroupExpansion(root.group?.key)
            }
          }

          StandardButton {
            buttonType: "control"
            text: "x"
            Accessible.name: root.isGroup ? "Dismiss group" : "Dismiss notification"
            onClicked: {
              if (root.isGroup)
                root.svc?.dismissGroup(root.group?.key);
              else if (root.primaryWrapper)
                root.svc?.dismissNotification(root.primaryWrapper);
            }
          }
        }
      }

      ColumnLayout {
        id: cardContent
        Layout.fillWidth: true
        spacing: 12
        readonly property var renderedItems: root.isGroup && !root.groupExpanded ? (root.items.length > 0 ? [root.items[0]] : []) : root.items

        Repeater {
          model: cardContent.renderedItems
          delegate: Item {
            id: messageItem
            required property var modelData
            required property int index

            Layout.fillWidth: true
            implicitHeight: messageColumn.implicitHeight

            readonly property bool isMultipleItems: cardContent.renderedItems.length > 1
            readonly property bool isHovered: mouseArea.containsMouse

            Rectangle {
              id: messageBackground
              anchors.fill: parent
              radius: 6
              color: messageItem.isMultipleItems ? (messageItem.isHovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)) : "transparent"
              border.width: messageItem.isMultipleItems ? 1 : 0
              border.color: messageItem.isMultipleItems ? (messageItem.isHovered ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.4) : Qt.rgba(1, 1, 1, 0.1)) : "transparent"

              Behavior on color {
                ColorAnimation {
                  duration: 150
                }
              }
              Behavior on border.color {
                ColorAnimation {
                  duration: 150
                }
              }
            }

            ColumnLayout {
              id: messageColumn
              anchors.fill: parent
              anchors.margins: messageItem.isMultipleItems ? 8 : 0

              readonly property string summary: messageItem.modelData?.summary || "(No title)"
              readonly property string body: messageItem.modelData?.body || ""
              readonly property string messageId: messageItem.modelData?.id || String(messageItem.modelData?.notification ? messageItem.modelData.notification.id || "" : "")
              readonly property url contentImage: messageItem.modelData?.cleanImage || ""
              readonly property bool hasBody: messageItem.modelData?.hasBody === true ? true : (body && body.trim() !== "" && body.trim() !== summary.trim())
              readonly property bool expanded: root.messageExpanded(messageColumn.messageId)
              readonly property bool hasInlineReply: messageItem.modelData?.hasInlineReply === true
              readonly property string inlineReplyPlaceholder: messageItem.modelData?.inlineReplyPlaceholder || "Reply"
              readonly property var actionsModel: messageItem.modelData?.actions || []
              property bool summaryTruncated: false
              property bool bodyTruncated: false

              function prepareBody(raw) {
                if (typeof raw !== "string" || raw.length === 0)
                  return ({
                      text: "",
                      format: Qt.PlainText
                    });
                const mdUtil = typeof Markdown2Html !== "undefined" && typeof Markdown2Html.toDisplay === "function" ? Markdown2Html : null;
                if (mdUtil) {
                  const meta = mdUtil.toDisplay(raw);
                  if (meta && typeof meta === "object" && meta.text !== undefined && meta.format !== undefined)
                    return meta;
                }
                if (raw.search(/<\s*\/?\s*[a-zA-Z!][^>]*>/) !== -1)
                  return ({
                      text: raw,
                      format: Qt.RichText
                    });
                return ({
                    text: raw,
                    format: Qt.PlainText
                  });
              }
              readonly property var renderedBodyMeta: prepareBody(body)

              spacing: 6

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Loader {
                  Layout.preferredWidth: active ? 24 : 0
                  Layout.preferredHeight: active ? 24 : 0
                  active: !!messageColumn.contentImage
                  sourceComponent: Image {
                    width: 24
                    height: 24
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    source: messageColumn.contentImage
                    onStatusChanged: if (status === Image.Error)
                      parent.parent.active = false
                  }
                }

                Text {
                  id: summaryText
                  Layout.fillWidth: true
                  text: messageColumn.summary
                  color: "#dddddd"
                  font.pixelSize: 14
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                  wrapMode: Text.WordWrap
                  maximumLineCount: messageColumn.expanded ? 0 : 2
                  Component.onCompleted: messageColumn.summaryTruncated = truncated
                  onTruncatedChanged: messageColumn.summaryTruncated = truncated
                }

                Loader {
                  active: messageColumn.summaryTruncated || messageColumn.bodyTruncated || messageColumn.expanded
                  sourceComponent: StandardButton {
                    buttonType: "control"
                    text: messageColumn.expanded ? "▴" : "▾"
                    Accessible.name: messageColumn.expanded ? "Collapse message" : "Expand message"
                    onClicked: root.toggleMessageExpansion(messageColumn.messageId)
                  }
                }
              }

              Loader {
                id: bodyLoader
                Layout.fillWidth: true
                active: messageColumn.hasBody
                onActiveChanged: if (!active)
                  messageColumn.bodyTruncated = false
                sourceComponent: Text {
                  id: bodyText
                  Layout.fillWidth: true
                  color: "#bbbbbb"
                  font.pixelSize: 12
                  wrapMode: Text.WordWrap
                  textFormat: messageColumn.renderedBodyMeta.format
                  text: messageColumn.renderedBodyMeta.text
                  maximumLineCount: messageColumn.expanded ? 0 : 2
                  elide: Text.ElideRight
                  linkColor: root.accentColor
                  Component.onCompleted: messageColumn.bodyTruncated = truncated
                  onTruncatedChanged: messageColumn.bodyTruncated = truncated
                  onLinkActivated: url => Qt.openUrlExternally(url)
                }
              }

              Loader {
                Layout.fillWidth: true
                active: messageColumn.hasInlineReply
                sourceComponent: RowLayout {
                  Layout.fillWidth: true
                  spacing: 6

                  TextField {
                    id: replyField
                    Layout.fillWidth: true
                    placeholderText: messageColumn.inlineReplyPlaceholder
                    selectByMouse: true
                    activeFocusOnPress: true
                    font.pixelSize: 13
                    padding: 6
                    Keys.onReturnPressed: sendBtn.clicked()
                    Keys.onEnterPressed: sendBtn.clicked()
                    onActiveFocusChanged: if (activeFocus)
                      root.inputFocusRequested()
                    background: Rectangle {
                      anchors.fill: parent
                      radius: Theme.itemRadius
                      color: Theme.bgColor
                      border.width: 1
                      border.color: replyField.activeFocus ? Theme.activeColor : Theme.borderColor
                    }
                  }

                  StandardButton {
                    id: sendBtn
                    buttonType: "action"
                    text: "Send"
                    onClicked: {
                      const replyText = String(replyField.text || "");
                      if (replyText.length === 0)
                        return;
                      const success = messageItem.modelData && messageItem.modelData.sendInlineReply ? messageItem.modelData.sendInlineReply(replyText) : false;
                      if (success !== false)
                        replyField.text = "";
                    }
                  }
                }
              }

              Loader {
                Layout.fillWidth: true
                active: messageColumn.actionsModel.length > 0
                sourceComponent: RowLayout {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignHCenter
                  spacing: 6
                  Repeater {
                    model: messageColumn.actionsModel
                    delegate: StandardButton {
                      required property var modelData
                      buttonType: "action"
                      text: modelData.title || modelData.id || ""
                      onClicked: root.svc?.executeAction(messageItem.modelData, modelData.id, modelData._obj)
                    }
                  }
                }
              }
            }

            MouseArea {
              id: mouseArea
              anchors.fill: parent
              hoverEnabled: messageItem.isMultipleItems
              acceptedButtons: Qt.NoButton
              z: -1  // Put behind the content
            }
          }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onEntered: {
      for (const w of root.items)
        if (w?.timer?.running)
          w.timer.stop();
    }
    onExited: {
      for (const w of root.items) {
        const t = w?.timer;
        if (t && (t.interval || 0) > 0 && !t.running)
          t.start();
      }
    }
  }
}
