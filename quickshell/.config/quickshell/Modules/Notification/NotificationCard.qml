pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.Config
import qs.Services.Utils

Item {
  id: root

  property bool _animReady: root.isGroup || root.groupScope !== "popup" || !(root.svc?.isPopupNew(root.group?.key || "") ?? false)
  readonly property bool _isDismissing: root._isGroupDismissing || (root.primaryWrapper?.isHidingPopup ?? false) || (root.primaryWrapper?.isDismissing ?? false)
  readonly property bool _isGroupDismissing: root.items.length > 0 && root.items.every(wrapper => (wrapper?.isDismissing ?? false) || (root.groupScope === "popup" && (wrapper?.isHidingPopup ?? false)))
  property var _messageExpansion: ({})
  property var _shownMessageIds: ({})
  readonly property color accentColor: root.primaryWrapper?.accentColor || Theme.activeColor
  readonly property alias blurInsetItem: blurInset
  required property var group
  readonly property bool groupExpanded: !root.isGroup || (root.svc?.expandedGroups ? (root.svc.expandedGroups[root.group?.key] || false) : false)
  property string groupScope: "history"
  readonly property string headerTitle: root.isGroup ? `${root.group?.displayName || "app"} (${root.group?.count || root.items.length})` : (root.primaryWrapper?.displayName || "app")
  readonly property bool isGroup: root.group?.count > 1
  readonly property var items: root.group?.notifications || []
  readonly property int messagePadding: Theme.spacingSm
  readonly property int paddingHorizontal: Theme.spacingMd
  readonly property int paddingVertical: Theme.spacingMd
  property Region popupBlurRegion: null
  readonly property var primaryWrapper: root.items[0] ?? null
  property bool showTimestamp: false
  readonly property int slideAnimDuration: root.svc?.animationDuration ?? 0
  readonly property int spacingContent: Theme.spacingXs + 2
  required property var svc

  signal inputFocusReleased
  signal inputFocusRequested

  function openBodyLink(url) {
    const safeUrl = NotificationText.safeUrl(String(url || ""));
    if (safeUrl)
      Qt.openUrlExternally(safeUrl);
  }
  function resetReuseState(): void {
    _messageExpansion = {};
    _shownMessageIds = {};
  }
  function toggleMessageExpansion(id) {
    if (!id)
      return;
    const next = Object.assign({}, root._messageExpansion);
    next[id] = !next[id];
    root._messageExpansion = next;
  }

  implicitHeight: cardColumn.implicitHeight + (root.paddingVertical * 2)
  implicitWidth: Theme.notificationCardWidth
  x: ((root._isDismissing && (!root.isGroup || root._isGroupDismissing)) || !root._animReady) ? root.width + (Theme.popupOffset || 12) : 0

  Behavior on x {
    NumberAnimation {
      duration: root.slideAnimDuration
      easing.type: Easing.OutCubic
    }
  }

  Component.onCompleted: {
    if (root.groupScope === "popup" && root.group?.key)
      root.svc?.markPopupShown(root.group.key);
    if (!root._animReady)
      Qt.callLater(() => root._animReady = true);
  }
  Keys.onEscapePressed: event => {
    if (root.groupScope === "history") {
      event.accepted = false;
      return;
    }
    if (root.isGroup)
      root.svc?.dismissGroup(root.group?.key);
    else if (root.primaryWrapper)
      root.svc?.dismissNotification(root.primaryWrapper);
  }

  Item {
    id: blurInset

    anchors.fill: parent
    anchors.margins: 2
  }
  RectangularShadow {
    anchors.fill: parent
    antialiasing: true
    blur: Theme.shadowBlurLg
    color: Theme.shadowColorStrong
    offset: Qt.vector2d(0, 3)
    radius: Theme.panelRadius
    spread: 0
    visible: root.groupScope === "popup"
  }
  Rectangle {
    anchors.fill: parent
    border.color: Theme.withOpacity(root.accentColor, Theme.opacityMedium)
    border.width: Theme.borderWidthMedium
    color: root.groupScope === "popup" ? Theme.glassSurfaceColor : Theme.glassContentColor
    radius: Theme.panelRadius
  }
  ColumnLayout {
    id: cardColumn

    spacing: root.spacingContent

    anchors {
      bottomMargin: root.paddingVertical
      fill: parent
      leftMargin: root.paddingHorizontal
      rightMargin: root.paddingHorizontal
      topMargin: root.paddingVertical
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.cardPadding

      Rectangle {
        Layout.preferredHeight: Theme.notificationAppIconSize
        Layout.preferredWidth: Theme.notificationAppIconSize
        border.color: Theme.borderSubtle
        border.width: Theme.borderWidthThin
        color: Theme.bgSubtle
        radius: Theme.radiusSm
        visible: !!root.primaryWrapper

        Image {
          anchors.centerIn: parent
          fillMode: Image.PreserveAspectFit
          height: Theme.itemHeight
          smooth: true
          source: root.primaryWrapper ? Utils.resolveIconSource(root.primaryWrapper.notification?.appName || "app", root.primaryWrapper.notification?.appIcon || "", "dialog-information") : ""
          sourceSize: Qt.size(Theme.itemHeight, Theme.itemHeight)
          width: Theme.itemHeight
        }
      }
      OText {
        Layout.fillWidth: true
        bold: true
        color: Theme.textActiveColor
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        text: root.headerTitle
      }
      RowLayout {
        Layout.alignment: Qt.AlignTop
        spacing: Theme.spacingXs

        ControlButton {
          Accessible.name: root.groupExpanded ? "Collapse group" : "Expand group"
          text: root.groupExpanded ? "▴" : "▾"
          visible: root.isGroup && root.items.length > 1

          onClicked: root.svc?.toggleGroupExpansion(root.group?.key)
        }
        ControlButton {
          Accessible.name: root.isGroup ? "Dismiss group" : "Dismiss notification"
          text: "x"

          onClicked: root.isGroup ? root.svc?.dismissGroup(root.group?.key) : root.svc?.dismissNotification(root.primaryWrapper)
        }
      }
    }
    ColumnLayout {
      id: messagesLayout

      readonly property var renderedItems: root.isGroup && !root.groupExpanded ? (root.items.length > 0 ? [root.items[0]] : []) : root.items

      Layout.fillWidth: true
      spacing: Theme.spacingSm

      Repeater {
        model: parent.renderedItems

        delegate: Item {
          id: messageItem

          property bool _animReady: !messageColumn.messageId || !!root._shownMessageIds[messageColumn.messageId]
          readonly property real _contentHeight: messageColumn.implicitHeight + messageColumn.topPadding + messageColumn.bottomPadding
          readonly property bool _isDismissing: messageItem.modelData?.isDismissing ?? false
          required property int index
          readonly property bool isHovered: hoverHandler.hovered
          readonly property bool isMultipleItems: messagesLayout.renderedItems.length > 1
          required property var modelData

          Layout.fillWidth: true
          Layout.preferredHeight: messageItem._isDismissing ? 0 : messageItem._contentHeight
          clip: true

          Behavior on Layout.preferredHeight {
            NumberAnimation {
              duration: root.slideAnimDuration
              easing.type: Easing.OutCubic
            }
          }

          Component.onCompleted: {
            if (messageColumn.messageId)
              root._shownMessageIds[messageColumn.messageId] = true;
            if (!messageItem._animReady)
              Qt.callLater(() => messageItem._animReady = true);
          }

          HoverHandler {
            id: hoverHandler

            enabled: messageItem.isMultipleItems
          }
          Item {
            id: messageContent

            height: parent.height
            width: parent.width
            x: messageItem._isDismissing || !messageItem._animReady ? parent.width + (Theme.popupOffset || 12) : 0

            Behavior on x {
              NumberAnimation {
                duration: root.slideAnimDuration
                easing.type: Easing.OutCubic
              }
            }

            MouseArea {
              anchors.fill: parent
              enabled: messageColumn.wrapper?.hasDefaultAction ?? false

              onClicked: root.svc?.invokeDefaultAction(messageColumn.wrapper)
            }
            Rectangle {
              anchors.fill: parent
              border.color: messageItem.isMultipleItems ? (messageItem.isHovered ? Theme.withOpacity(root.accentColor, 0.4) : Theme.borderSubtle) : "transparent"
              border.width: messageItem.isMultipleItems ? 1 : 0
              color: messageItem.isMultipleItems ? (messageItem.isHovered ? Theme.activeSubtle : Theme.bgSubtle) : "transparent"
              radius: Theme.radiusSm

              Behavior on border.color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }
              Behavior on color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }
            }
            ColumnLayout {
              id: messageColumn

              property bool bodyTruncated: false
              readonly property int bottomPadding: messageItem.isMultipleItems ? root.messagePadding : 0
              readonly property bool expanded: !!root._messageExpansion[messageColumn.messageId]
              readonly property int horizontalPadding: messageItem.isMultipleItems ? root.messagePadding : 0
              readonly property string messageId: wrapper?.messageId || ""
              property bool summaryTruncated: false
              readonly property int topPadding: messageItem.isMultipleItems ? root.messagePadding : 0
              readonly property var wrapper: messageItem.modelData

              spacing: root.spacingContent

              anchors {
                bottomMargin: bottomPadding
                left: parent.left
                leftMargin: horizontalPadding
                right: parent.right
                rightMargin: horizontalPadding
                top: parent.top
                topMargin: topPadding
              }
              RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Image {
                  Layout.preferredHeight: visible ? Theme.notificationInlineImageSize : 0
                  Layout.preferredWidth: visible ? Theme.notificationInlineImageSize : 0
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                  source: messageColumn.wrapper?.contentImage || ""
                  sourceSize: Qt.size(Theme.notificationInlineImageSize, Theme.notificationInlineImageSize)
                  visible: String(messageColumn.wrapper?.contentImage || "") !== "" && status !== Image.Error
                }
                Text {
                  id: summaryText

                  function updateTruncation() {
                    messageColumn.summaryTruncated = truncated || lineCount > 2;
                  }

                  Layout.fillWidth: true
                  color: Theme.textActiveColor
                  elide: Text.ElideRight
                  font.pixelSize: Theme.fontMd
                  horizontalAlignment: messageItem.isMultipleItems ? Text.AlignLeft : Text.AlignHCenter
                  maximumLineCount: messageColumn.expanded ? 0 : 2
                  text: messageColumn.wrapper?.renderedSummary.text || ""
                  textFormat: messageColumn.wrapper?.renderedSummary.format ?? Text.PlainText
                  wrapMode: Text.WordWrap

                  Component.onCompleted: Qt.callLater(updateTruncation)
                  onLineCountChanged: updateTruncation()
                  onTruncatedChanged: updateTruncation()
                }
                OText {
                  color: Theme.textInactiveColor
                  opacity: 0.7
                  size: "xs"
                  text: messageItem.modelData?.timestampText || ""
                  visible: root.showTimestamp && text
                }
                RowLayout {
                  spacing: Theme.spacingXs

                  ControlButton {
                    Accessible.name: messageColumn.expanded ? "Collapse message" : "Expand message"
                    text: messageColumn.expanded ? "▴" : "▾"
                    visible: messageColumn.summaryTruncated || messageColumn.bodyTruncated || messageColumn.expanded

                    onClicked: root.toggleMessageExpansion(messageColumn.messageId)
                  }
                  ControlButton {
                    Accessible.name: "Dismiss notification"
                    text: "x"
                    visible: messageItem.isMultipleItems

                    onClicked: root.svc?.dismissNotification(messageItem.modelData)
                  }
                }
              }
              Loader {
                Layout.fillWidth: true
                active: messageColumn.wrapper?.hasBody ?? false

                sourceComponent: Item {
                  Layout.fillWidth: true
                  clip: !messageColumn.expanded
                  implicitHeight: messageColumn.expanded ? bodyText.implicitHeight : Math.min(bodyText.implicitHeight, bodyText.font.pixelSize * 2 * 1.5)

                  Text {
                    id: bodyText

                    function updateTruncation() {
                      messageColumn.bodyTruncated = truncated || lineCount > 2 || (messageColumn.wrapper?.bodyHasMultipleLines ?? false) || implicitHeight > font.pixelSize * 3;
                    }

                    color: Theme.textInactiveColor
                    font.pixelSize: Theme.fontSm
                    linkColor: root.accentColor
                    text: messageColumn.wrapper?.renderedBody.text || ""
                    textFormat: messageColumn.wrapper?.renderedBody.format ?? Text.PlainText
                    width: parent.width
                    wrapMode: Text.WordWrap

                    Component.onCompleted: Qt.callLater(updateTruncation)
                    onLineCountChanged: updateTruncation()
                    onTruncatedChanged: updateTruncation()
                  }
                  HoverHandler {
                    id: linkHover

                    cursorShape: bodyText.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                  }
                  TapHandler {
                    acceptedButtons: Qt.LeftButton

                    onTapped: function (eventPoint) {
                      const link = bodyText.linkAt(eventPoint.position.x, eventPoint.position.y);
                      if (link) {
                        root.openBodyLink(link);
                      }
                    }
                  }
                }

                onActiveChanged: if (!active)
                  messageColumn.bodyTruncated = false
              }
              Loader {
                Layout.bottomMargin: Theme.spacingXs
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingXs
                active: messageColumn.wrapper?.hasInlineReply ?? false
                visible: active

                sourceComponent: RowLayout {
                  spacing: Theme.spacingSm

                  TextField {
                    id: replyField

                    Layout.fillWidth: true
                    activeFocusOnPress: true
                    font.pixelSize: Theme.fontSm
                    padding: Theme.spacingSm
                    placeholderText: messageColumn.wrapper?.inlineReplyPlaceholder || "Reply"
                    selectByMouse: true

                    background: Rectangle {
                      anchors.fill: parent
                      border.color: replyField.activeFocus ? Theme.activeColor : Theme.glassBorderColor
                      border.width: Theme.borderWidthThin
                      color: Theme.glassInputColor
                      radius: Theme.itemRadius
                    }

                    Keys.onEnterPressed: sendBtn.clicked()
                    Keys.onEscapePressed: event => {
                      replyField.text = "";
                      replyField.focus = false;
                      event.accepted = true;
                    }
                    Keys.onReturnPressed: sendBtn.clicked()
                    onActiveFocusChanged: {
                      if (activeFocus)
                        root.inputFocusRequested();
                      else
                        root.inputFocusReleased();
                    }
                  }
                  ActionButton {
                    id: sendBtn

                    text: "Send"

                    onClicked: {
                      if (root.svc?.sendReply(messageColumn.wrapper, replyField.text))
                        replyField.text = "";
                    }
                  }
                }
              }
              ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? implicitHeight : 0
                Layout.topMargin: Theme.spacingXs
                implicitHeight: actionsRow.implicitHeight
                visible: (messageColumn.wrapper?.visibleActions.length || 0) > 0

                RowLayout {
                  id: actionsRow

                  Layout.alignment: Qt.AlignHCenter
                  Layout.fillWidth: true
                  implicitHeight: childrenRect.height
                  spacing: Theme.spacingSm

                  Repeater {
                    model: messageColumn.wrapper?.visibleActions || []

                    delegate: ActionButton {
                      required property var modelData

                      icon.source: modelData?.icon || ""
                      text: modelData?.label || ""

                      onClicked: root.svc?.invokeAction(messageColumn.wrapper, modelData?.identifier || "")
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  HoverHandler {
    onHoveredChanged: hovered ? root.svc?.pauseTimers(root.items) : root.svc?.resumeTimers(root.items)
  }

  component ActionButton: ToolButton {
    id: button

    display: icon.source && text ? AbstractButton.TextBesideIcon : icon.source ? AbstractButton.IconOnly : AbstractButton.TextOnly
    font.pixelSize: Theme.fontSm
    leftPadding: Theme.spacingMd
    padding: Theme.spacingXs + 2
    palette.buttonText: Theme.textActiveColor
    rightPadding: Theme.spacingMd

    background: Rectangle {
      border.color: Theme.activeMedium
      border.width: Theme.borderWidthThin
      color: button.hovered ? Theme.activeLight : Theme.activeSubtle
      radius: Theme.radiusMd
    }
  }
  component ControlButton: OButton {
    bgColor: Theme.glassContentColor
    hoverColor: Theme.glassContentHoverColor
    radius: Theme.radiusSm
    size: "xs"
    textColor: Theme.textActiveColor
  }
}
