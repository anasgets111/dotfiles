pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Components
import qs.Modules.Bar
import qs.Services.Core
import qs.Services.Utils

PanelWindow {
  id: root

  // Network state properties
  property bool ready: false
  property string link: "disconnected"
  property var ap: null

  // Password input state
  property string passwordInputSsid: ""
  property string passwordInputError: ""

  // Menu configuration
  property int maxScrollableItems: 7
  property real itemHeight: Theme.itemHeight
  property real itemPadding: 8
  property int menuWidth: 350
  property int textInputMenuWidth: 350
  property int screenMargin: 8

  property bool useButtonPosition: false
  property point buttonPosition: Qt.point(0, 0)
  property int buttonWidth: 0
  property int buttonHeight: 0

  property bool isClosing: false
  property bool isOpen: false

  // Calculate if keyboard focus is needed
  readonly property bool needsKeyboardFocus: passwordInputSsid !== ""

  // Calculate effective menu width
  readonly property int effectiveMenuWidth: needsKeyboardFocus ? textInputMenuWidth : menuWidth

  color: "transparent"
  visible: isOpen || isClosing

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "context-menu"
  WlrLayershell.keyboardFocus: needsKeyboardFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.exclusiveZone: -1

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  // Check for successful connection whenever WiFi APs update
  onApChanged: {
    if (!passwordInputSsid || !ap)
      return;
    if (ap.ssid === passwordInputSsid && ap.connected) {
      Logger.log("NetworkPanel", `Successfully connected to ${ap.ssid}, closing menu`);
      passwordInputSsid = "";
      passwordInputError = "";
      close();
    }
  }

  Connections {
    target: NetworkService

    function onConnectionError(ssid, errorMessage) {
      if (ssid === root.passwordInputSsid)
        root.passwordInputError = errorMessage;
    }

    function onConnectionStateChanged() {
      if (!root.passwordInputSsid)
        return;
      const aps = NetworkService.wifiAps || [];
      const connectedAp = aps.find(ap => ap?.ssid === root.passwordInputSsid && ap.connected);
      if (connectedAp) {
        Logger.log("NetworkPanel", `Connection state changed, connected to ${connectedAp.ssid}, closing menu`);
        root.passwordInputSsid = "";
        root.passwordInputError = "";
        root.close();
      }
    }
  }

  component MenuAnimation: NumberAnimation {
    duration: Theme.animationDuration
    easing.type: Easing.OutQuad
  }

  Timer {
    id: hideTimer
    interval: Theme.animationDuration
    repeat: false
    onTriggered: {
      root.closeCompleted();
    }
  }

  function openAt(x, y) {
    buttonPosition = Qt.point(x, y);
    buttonWidth = 0;
    buttonHeight = 0;
    open();
  }

  function openAtItem(item, mouseX, mouseY) {
    if (!item)
      return;
    buttonPosition = item.mapToItem(null, mouseX || 0, mouseY || 0);
    buttonWidth = item.width;
    buttonHeight = item.height;
    open();
  }

  function open() {
    if (isClosing) {
      hideTimer.stop();
      isClosing = false;
    }
    useButtonPosition = true;
    isOpen = true;
  }

  function close() {
    if (!isOpen)
      return;
    isClosing = true;
    isOpen = false;
    hideTimer.start();
  }

  function closeCompleted() {
    isClosing = false;
    useButtonPosition = false;
    passwordInputSsid = "";
    passwordInputError = "";
  }

  function calculateX() {
    if (!useButtonPosition)
      return 0;
    const centerX = buttonPosition.x + buttonWidth / 2 - menuBackground.width / 2;
    const maxX = root.width - menuBackground.width - screenMargin;
    return Math.max(screenMargin, Math.min(centerX, maxX));
  }

  function calculateY() {
    if (!useButtonPosition)
      return Math.round((root.height - menuBackground.height) / 2);
    const belowY = Theme.panelHeight;
    const aboveY = buttonPosition.y - menuBackground.height - 4;
    const maxY = root.height - menuBackground.height - 8;

    if (belowY + menuBackground.height <= root.height - 8)
      return Math.round(belowY);
    if (aboveY >= 8)
      return Math.round(aboveY);
    return Math.round(Math.min(belowY, maxY));
  }

  function handleAction(action, data) {
    const saved = NetworkService.savedWifiAps || [];
    const findSaved = ssid => saved.find(conn => conn?.ssid === ssid);

    if (action === "toggle-radio") {
      NetworkService.toggleWifiRadio();
    } else if (action.startsWith("password-submit-")) {
      const ssid = action.substring(16);
      const dataObj = data || {};
      const password = dataObj.value || "";
      if (NetworkService.wifiInterface && ssid && password) {
        root.passwordInputError = "";
        NetworkService.connectToWifi(ssid, password, NetworkService.wifiInterface, false, "");
      }
    } else if (action.startsWith("forget-")) {
      const ssid = action.substring(7);
      const connId = findSaved(ssid)?.connectionId;
      if (connId)
        NetworkService.forgetWifiConnection(connId);
    } else if (action.startsWith("disconnect-")) {
      const ssid = action.substring(11);
      const aps = NetworkService.wifiAps || [];
      const connectedAp = aps.find(ap => ap?.ssid === ssid && ap.connected);
      if (connectedAp && NetworkService.wifiInterface) {
        NetworkService.disconnectInterface(NetworkService.wifiInterface);
      }
    } else if (action.startsWith("connect-")) {
      const ssid = action.substring(8);
      const aps = NetworkService.wifiAps || [];
      const selectedAp = aps.find(ap => ap?.ssid === ssid);
      if (!selectedAp || selectedAp.connected)
        return;

      const savedConn = findSaved(ssid);
      if (savedConn?.connectionId) {
        NetworkService.activateConnection(savedConn.connectionId, NetworkService.wifiInterface);
        root.close();
      } else {
        root.passwordInputSsid = ssid;
      }
    }
  }

  Shortcut {
    sequences: ["Escape"]
    enabled: root.isOpen && !root.isClosing
    onActivated: root.close()
    context: Qt.WindowShortcut
  }

  MouseArea {
    id: dismissArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: false
    enabled: root.isOpen && !root.isClosing

    onPressed: function (mouse) {
      if (!menuBackground)
        return;
      const local = menuBackground.mapFromItem(dismissArea, mouse.x, mouse.y);
      const inside = local.x >= 0 && local.y >= 0 && local.x <= menuBackground.width && local.y <= menuBackground.height;

      if (inside) {
        mouse.accepted = false;
        return;
      }

      root.close();
    }
  }

  // Clip container to prevent menu from appearing above the bar
  Item {
    id: clipContainer
    anchors.fill: parent
    anchors.topMargin: Theme.panelHeight
    clip: true

    Rectangle {
      id: menuBackground

      readonly property real fixedHeight: fixedList.contentHeight + (scrollableList.count > 0 ? 4 : 0)
      readonly property real scrollableHeight: Math.min(scrollableList.contentHeight, root.maxScrollableItems * root.itemHeight + (root.maxScrollableItems - 1) * 4)
      readonly property real totalContentHeight: fixedHeight + scrollableHeight + root.itemPadding * 2
      readonly property real targetY: root.calculateY() - Theme.panelHeight
      readonly property real hiddenY: -totalContentHeight

      width: root.effectiveMenuWidth
      height: totalContentHeight

      color: Theme.bgColor
      radius: Theme.itemRadius

      topLeftRadius: 0
      topRightRadius: 0
      bottomLeftRadius: Theme.itemRadius
      bottomRightRadius: Theme.itemRadius

      x: root.calculateX()
      y: root.isOpen ? targetY : hiddenY

      Behavior on y {
        MenuAnimation {}
      }

      clip: true

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.itemPadding
        spacing: 4

        // Fixed items (Toggle Wi-Fi Radio)
        ListView {
          id: fixedList
          Layout.fillWidth: true
          Layout.preferredHeight: contentHeight
          spacing: 4
          interactive: false
          clip: true
          model: [
            {
              itemType: "action",
              icon: "󰒓",
              label: "Toggle Wi-Fi Radio",
              action: "toggle-radio"
            }
          ]

          delegate: NetworkMenuItem {
            itemHeight: root.itemHeight
            itemPadding: root.itemPadding
            parentListView: fixedList
            isEnabled: root.ready

            onTriggered: (action, data) => {
              root.handleAction(action, data);
              root.close();
            }
          }
        }

        // Scrollable section (networks)
        ListView {
          id: scrollableList
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(contentHeight, root.maxScrollableItems * root.itemHeight + (root.maxScrollableItems - 1) * 4)
          visible: count > 0
          spacing: 4
          interactive: contentHeight > height
          clip: true
          model: {
            const networks = [];
            if (!NetworkService.wifiRadioEnabled || !NetworkService.wifiAps)
              return networks;

            const saved = NetworkService.savedWifiAps || [];
            const findSaved = ssid => saved.find(conn => conn?.ssid === ssid);

            for (const ap of NetworkService.wifiAps) {
              if (!ap?.ssid)
                continue;

              // Password input mode for this network
              if (ap.ssid === root.passwordInputSsid) {
                networks.push({
                  itemType: "textInput",
                  icon: "󰌾",
                  placeholder: qsTr("Password for %1").arg(root.passwordInputSsid),
                  echoMode: TextInput.Password,
                  hasError: root.passwordInputError !== "",
                  errorMessage: root.passwordInputError,
                  action: `password-submit-${root.passwordInputSsid}`,
                  actionIcon: "󰌘"
                });
                continue;
              }

              const signal = typeof ap.signal === "number" ? ap.signal : 0;
              const band = ap.band || "";
              const savedConn = findSaved(ap.ssid);

              networks.push({
                itemType: "action",
                icon: NetworkService.getWifiIcon(band, signal),
                label: ap.ssid,
                action: ap.connected ? `disconnect-${ap.ssid}` : `connect-${ap.ssid}`,
                actionIcon: ap.connected ? "󱘖" : "󰌘",
                forgetIcon: savedConn ? "󰩺" : undefined,
                band,
                bandColor: NetworkService.getBandColor(band),
                ssid: ap.ssid,
                signal,
                connected: ap.connected,
                connectionId: savedConn?.connectionId,
                isSaved: !!savedConn
              });
            }
            return networks;
          }

          ScrollBar.vertical: ScrollBar {
            policy: scrollableList.contentHeight > scrollableList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 8
          }

          delegate: NetworkMenuItem {
            itemHeight: root.itemHeight
            itemPadding: root.itemPadding
            parentListView: scrollableList
            isEnabled: root.ready
            passwordError: root.passwordInputError

            onTriggered: (action, data) => {
              const shouldClose = modelData.itemType !== "textInput" && !action.startsWith("connect-") || (action.startsWith("connect-") && (modelData.connected || modelData.isSaved));
              root.handleAction(action, data);
              if (shouldClose) {
                root.close();
              }
            }

            onPasswordCleared: {
              root.passwordInputError = "";
            }
          }
        }
      }
    }

    // Left inverse corner
    RoundCorner {
      anchors.right: menuBackground.left
      anchors.rightMargin: -1
      y: menuBackground.y
      color: Theme.bgColor
      orientation: 1
      radius: Theme.panelRadius * 3
    }

    // Right inverse corner
    RoundCorner {
      anchors.left: menuBackground.right
      anchors.leftMargin: -1
      y: menuBackground.y
      color: Theme.bgColor
      orientation: 0
      radius: Theme.panelRadius * 3
    }
  }

  // Inlined MenuItem Component
  component NetworkMenuItem: Item {
    id: menuItem

    required property var modelData
    required property int index

    property real itemHeight: Theme.itemHeight
    property real itemPadding: 8
    property var parentListView: null
    property bool isEnabled: true
    property string passwordError: ""

    readonly property string itemType: modelData.itemType || "action"
    readonly property bool isTextInput: itemType === "textInput"
    readonly property bool hasError: isTextInput && (modelData.hasError ?? false)
    readonly property color textColor: hovered && isEnabled ? Theme.textOnHoverColor : Theme.textActiveColor

    property bool hovered: false

    signal triggered(string action, var data)
    signal passwordCleared

    width: parentListView.width
    height: {
      if (itemType === "textInput") {
        const baseHeight = itemHeight * 0.8 + itemPadding * 2;
        return hasError ? baseHeight + itemHeight * 0.6 : baseHeight;
      }
      return itemHeight;
    }
    opacity: isEnabled ? 1.0 : 0.5

    // Background for action items
    Rectangle {
      anchors.fill: parent
      visible: menuItem.itemType === "action"
      color: menuItem.hovered && menuItem.isEnabled ? Theme.onHoverColor : "transparent"
      radius: Theme.itemRadius

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }

    // Content loader
    Loader {
      anchors.fill: parent
      sourceComponent: menuItem.itemType === "action" ? actionItemComponent : textInputItemComponent
    }

    // Action item
    Component {
      id: actionItemComponent

      RowLayout {
        spacing: 8

        // Icon with band indicator
        Item {
          visible: menuItem.modelData.icon !== undefined
          Layout.preferredWidth: Theme.fontSize * 1.5
          Layout.preferredHeight: menuItem.itemHeight
          Layout.leftMargin: menuItem.itemPadding
          Layout.alignment: Qt.AlignVCenter

          Text {
            id: menuIcon
            text: menuItem.modelData.icon || ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: menuItem.modelData.bandColor || menuItem.textColor
            anchors.centerIn: parent

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }

          Text {
            text: menuItem.modelData.band ? (menuItem.modelData.band === "2.4" ? "2.4" : menuItem.modelData.band) : ""
            font.family: "Roboto Condensed"
            font.pixelSize: Theme.fontSize * 0.5
            font.bold: true
            font.letterSpacing: -0.5
            color: menuItem.modelData.bandColor || menuItem.textColor
            anchors.left: menuIcon.right
            anchors.leftMargin: -2
            anchors.bottom: menuIcon.bottom
            anchors.bottomMargin: 0
            visible: menuItem.modelData.band !== undefined && menuItem.modelData.band !== ""

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }
        }

        Text {
          text: menuItem.modelData.label || menuItem.modelData.text || ""
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: menuItem.textColor
          verticalAlignment: Text.AlignVCenter
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          Layout.leftMargin: menuItem.modelData.icon ? 0 : menuItem.itemPadding

          Behavior on color {
            ColorAnimation {
              duration: Theme.animationDuration
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onEntered: menuItem.hovered = true
            onExited: menuItem.hovered = false

            onClicked: {
              if (menuItem.isEnabled) {
                menuItem.triggered(menuItem.modelData.action || menuItem.index.toString(), {});
              }
            }
          }
        }

        // Forget button
        IconButton {
          visible: menuItem.modelData.forgetIcon !== undefined
          Layout.preferredWidth: menuItem.itemHeight * 0.8
          Layout.preferredHeight: menuItem.itemHeight * 0.8
          Layout.alignment: Qt.AlignVCenter
          Layout.rightMargin: 4

          icon: menuItem.modelData.forgetIcon || ""
          colorBg: "#F38BA8"
          tooltipText: qsTr("Forget Network")

          onClicked: {
            menuItem.triggered("forget-" + (menuItem.modelData.ssid || ""), {});
          }
        }

        // Action button
        IconButton {
          visible: menuItem.modelData.actionIcon !== undefined
          Layout.preferredWidth: menuItem.itemHeight * 0.8
          Layout.preferredHeight: menuItem.itemHeight * 0.8
          Layout.alignment: Qt.AlignVCenter
          Layout.rightMargin: menuItem.itemPadding

          icon: menuItem.modelData.actionIcon || ""
          colorBg: Theme.activeColor
          tooltipText: menuItem.modelData.connected ? qsTr("Disconnect") : qsTr("Connect")

          onClicked: {
            menuItem.triggered(menuItem.modelData.action || "", {});
          }
        }
      }
    }

    // Text input item
    Component {
      id: textInputItemComponent

      RowLayout {
        spacing: 8

        Item {
          visible: menuItem.modelData.icon !== undefined
          Layout.preferredWidth: Theme.fontSize * 1.5
          Layout.preferredHeight: menuItem.itemHeight
          Layout.leftMargin: menuItem.itemPadding
          Layout.alignment: Qt.AlignVCenter

          Text {
            text: menuItem.modelData.icon || ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: menuItem.textColor
            anchors.centerIn: parent

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }
        }

        // Inlined TextAction
        ColumnLayout {
          id: textInputContainer
          Layout.fillWidth: true
          Layout.rightMargin: menuItem.itemPadding
          spacing: 4

          Timer {
            id: focusTimer
            interval: 100
            repeat: true
            running: false
            property int attempts: 0
            onTriggered: {
              if (textField) {
                textField.forceActiveFocus();
                attempts++;
                if (textField.activeFocus || attempts >= 5) {
                  stop();
                  attempts = 0;
                }
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            readonly property real buttonSize: Theme.itemHeight * 0.8
            readonly property real inputHeight: Theme.itemHeight * 0.8

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: parent.inputHeight
              color: Theme.bgColor
              border.color: menuItem.hasError ? "#F38BA8" : textField.activeFocus ? Theme.activeColor : Theme.borderColor
              border.width: menuItem.hasError ? 2 : 1
              radius: Theme.itemRadius

              Behavior on border.color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }

              TextField {
                id: textField
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 2
                anchors.bottomMargin: 2

                placeholderText: menuItem.modelData.placeholder || ""
                echoMode: menuItem.modelData.echoMode ?? TextInput.Normal

                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.textActiveColor
                selectionColor: Theme.activeColor
                selectedTextColor: Theme.textContrast(Theme.activeColor)

                background: Rectangle {
                  color: "transparent"
                }

                onTextChanged: {
                  menuItem.passwordCleared();
                }

                Keys.onPressed: event => {
                  if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (text !== "") {
                      event.accepted = true;
                      menuItem.triggered(menuItem.modelData.action || "", {
                        value: text
                      });
                    }
                  }
                }

                Component.onCompleted: {
                  focusTimer.start();
                }
              }
            }

            IconButton {
              Layout.preferredWidth: parent.buttonSize
              Layout.preferredHeight: parent.buttonSize
              Layout.alignment: Qt.AlignVCenter

              icon: menuItem.hasError ? "󰀦" : (menuItem.modelData.actionIcon || "")
              colorBg: menuItem.hasError ? "#F38BA8" : Theme.activeColor
              enabled: textField.text !== ""
              tooltipText: menuItem.hasError ? qsTr("Retry") : qsTr("Submit")

              onClicked: {
                if (textField.text !== "") {
                  menuItem.triggered(menuItem.modelData.action || "", {
                    value: textField.text
                  });
                }
              }
            }
          }

          Text {
            visible: menuItem.hasError && menuItem.modelData.errorMessage !== ""
            text: "⚠ " + (menuItem.modelData.errorMessage || "")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.85
            color: "#F38BA8"
            Layout.fillWidth: true
            opacity: visible ? 1 : 0

            Behavior on opacity {
              NumberAnimation {
                duration: Theme.animationDuration
              }
            }
          }
        }
      }
    }
  }
}
