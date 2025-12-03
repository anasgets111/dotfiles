pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Core

OPanel {
  id: root

  readonly property var displayNetworks: buildNetworkList()
  readonly property string ethernetInterface: NetworkService.ethernetInterface
  readonly property bool ethernetOnline: NetworkService.ethernetOnline
  property int hiddenNetworkPhase: 0  // 0=hidden (not connecting), 1=enter name, 2=enter password
  property string hiddenPasswordError: ""
  property string hiddenSsid: ""
  readonly property int itemHeight: Theme.itemHeight
  readonly property int maxItems: 7
  readonly property bool networkingEnabled: NetworkService.networkingEnabled
  readonly property int padding: Theme.spacingSm
  property string passwordError: ""
  property string passwordSsid: ""
  readonly property bool ready: NetworkService.ready
  readonly property var savedConnections: NetworkService.savedWifiAps || []
  readonly property var wifiAps: NetworkService.wifiAps || []
  readonly property bool wifiEnabled: NetworkService.wifiRadioEnabled

  function buildNetworkList() {
    if (!ready || !networkingEnabled || !wifiEnabled)
      return [];

    const networks = [];

    // Handle hidden network input phases
    if (root.hiddenNetworkPhase === 1) {
      networks.push({
        type: "hidden-ssid-input",
        icon: "󰌾",
        placeholder: qsTr("Enter hidden network name"),
        hasError: false,
        errorMessage: "",
        action: "submit-hidden-ssid",
        ssid: ""
      });
    } else if (root.hiddenNetworkPhase === 2) {
      networks.push({
        type: "hidden-password-input",
        icon: "󰌾",
        placeholder: qsTr("Password for %1").arg(root.hiddenSsid),
        hasError: root.hiddenPasswordError !== "",
        errorMessage: root.hiddenPasswordError,
        action: "submit-hidden-password",
        ssid: root.hiddenSsid
      });
    } else {
      // Only show hidden network button when not in input phases
      networks.push({
        type: "action",
        icon: "󰒟",
        label: qsTr("Connect to Hidden Network"),
        action: "connect-hidden",
        actionIcon: "󰌘",
        ssid: "hidden"
      });
    }

    for (const ap of wifiAps) {
      if (!ap?.ssid)
        continue;

      if (ap.ssid === passwordSsid) {
        networks.push({
          type: "input",
          icon: "󰌾",
          placeholder: qsTr("Password for %1").arg(passwordSsid),
          hasError: passwordError !== "",
          errorMessage: passwordError,
          action: `submit-${passwordSsid}`,
          ssid: passwordSsid
        });
        continue;
      }

      const saved = findSavedConn(ap.ssid);
      networks.push({
        type: "action",
        icon: NetworkService.getWifiIcon(ap.band || "", ap.signal || 0),
        label: ap.ssid,
        action: ap.connected ? `disconnect-${ap.ssid}` : `connect-${ap.ssid}`,
        actionIcon: ap.connected ? "󱘖" : "󰌘",
        forgetIcon: saved ? "󰩺" : undefined,
        band: ap.band || "",
        bandColor: NetworkService.getBandColor(ap.band || ""),
        ssid: ap.ssid,
        connected: ap.connected,
        connectionId: saved?.connectionId,
        isSaved: !!saved
      });
    }
    return networks;
  }

  function extractInputValue(data) {
    return String(data?.value || "").trim();
  }

  function findSavedConn(ssid) {
    return savedConnections.find(c => c?.ssid === ssid);
  }

  function handleAction(action: string, data: var) {
    const wifiIface = NetworkService.wifiInterface;

    // Parse action with optional parameter
    const [verb, ...params] = action.split("-");
    const param = params.join("-");

    if (action === "connect-hidden") {
      root.hiddenNetworkPhase = 1;
      return;
    }

    if (action === "submit-hidden-ssid") {
      const ssid = extractInputValue(data);
      if (ssid) {
        hiddenSsid = ssid;
        root.hiddenNetworkPhase = 2;
      }
      return;
    }

    if (action === "submit-hidden-password") {
      const password = extractInputValue(data);
      if (wifiIface && hiddenSsid && password) {
        hiddenPasswordError = "";
        NetworkService.connectToWifi(hiddenSsid, password, wifiIface, true);
        resetHiddenNetworkState();
        root.close();
      }
      return;
    }

    if (action === "cancel-hidden") {
      resetHiddenNetworkState();
      return;
    }

    if (verb === "submit" && param) {
      const password = extractInputValue(data);
      if (wifiIface && param && password) {
        passwordError = "";
        NetworkService.connectToWifi(param, password, wifiIface);
        root.close();
      }
      return;
    }

    if (verb === "forget" && param) {
      const connId = findSavedConn(param)?.connectionId;
      if (connId)
        NetworkService.forgetWifiConnection(connId);
      return;
    }

    if (action === "cancel") {
      resetPasswordState();
      return;
    }

    if (verb === "disconnect") {
      if (wifiIface)
        NetworkService.disconnectInterface(wifiIface);
      return;
    }

    if (verb === "connect" && param) {
      const ap = wifiAps.find(a => a?.ssid === param);
      if (!ap || ap.connected)
        return;

      const saved = findSavedConn(param);
      if (saved?.connectionId) {
        NetworkService.activateConnection(saved.connectionId, wifiIface);
        root.close();
      } else {
        passwordSsid = param;
        passwordError = "";
      }
    }
  }

  function resetHiddenNetworkState() {
    hiddenSsid = "";
    hiddenPasswordError = "";
    root.hiddenNetworkPhase = 0;
  }

  function resetPasswordState() {
    passwordSsid = "";
    passwordError = "";
  }

  needsKeyboardFocus: passwordSsid !== "" || root.hiddenNetworkPhase > 0
  panelHeight: 0  // Will be updated dynamically based on content
  panelNamespace: "obelisk-network-panel"
  panelWidth: 350

  onClosed: {
    resetPasswordState();
    resetHiddenNetworkState();
  }

  Connections {
    function onConnectionError(ssid, errorMessage) {
      if (ssid === root.passwordSsid)
        root.passwordError = errorMessage;
      if (ssid === root.hiddenSsid)
        root.hiddenPasswordError = errorMessage;
    }

    function onConnectionStateChanged() {
      // Check for visible network connection
      const ap = root.wifiAps.find(a => a?.ssid === root.passwordSsid && a.connected);
      if (ap) {
        root.resetPasswordState();
        root.close();
        return;
      }

      // Check for hidden network connection (not in wifiAps since it's hidden)
      if (root.hiddenSsid && NetworkService.wifiOnline) {
        root.resetHiddenNetworkState();
        root.close();
      }
    }

    target: NetworkService
  }

  Rectangle {
    anchors.fill: parent
    border.color: Theme.borderLight
    border.width: 1
    color: Theme.bgElevatedAlt
    radius: Theme.itemRadius
  }

  ColumnLayout {
    spacing: Theme.spacingXs
    width: parent.width - root.padding * 2
    x: root.padding
    y: root.padding

    onImplicitHeightChanged: {
      root.panelHeight = implicitHeight + root.padding * 2;
    }

    // Toggle Cards Row
    RowLayout {
      Layout.bottomMargin: root.padding
      Layout.fillWidth: true
      spacing: root.padding * 1.25

      // Networking Toggle Card
      ToggleCard {
        checked: NetworkService.networkingEnabled
        disabled: !root.ready
        icon: "󱘖"
        iconColor: root.ready ? Qt.lighter(Theme.onHoverColor, 1.25) : Theme.inactiveColor
        label: "Networking"
        labelColor: root.ready ? Theme.textActiveColor : Theme.textInactiveColor
        opacityValue: root.ready ? 1 : 0.5

        onToggled: checked => NetworkService.setNetworkingEnabled(checked)
      }

      // Wi-Fi Toggle Card
      ToggleCard {
        checked: NetworkService.wifiRadioEnabled
        disabled: !root.ready || !root.networkingEnabled
        icon: "󰤨"
        iconColor: root.ready && root.networkingEnabled ? Qt.lighter(Theme.onHoverColor, 1.25) : Qt.darker(Theme.inactiveColor, 1.1)
        label: "Wi-Fi"
        labelColor: root.ready && root.networkingEnabled ? Theme.textActiveColor : Theme.textInactiveColor
        opacityValue: root.ready && root.networkingEnabled ? 1 : 0.5

        onToggled: checked => {
          NetworkService.setWifiRadioEnabled(checked);
        }
      }

      // Ethernet Toggle Card
      ToggleCard {
        checked: NetworkService.ethernetOnline
        disabled: !root.ready || !root.networkingEnabled || root.ethernetInterface === ""
        icon: "󰈀"
        iconColor: root.ready && root.networkingEnabled && root.ethernetInterface !== "" && root.ethernetOnline ? Qt.lighter(Theme.onHoverColor, 1.25) : Theme.inactiveColor
        label: "Ethernet"
        labelColor: root.ready && root.networkingEnabled && root.ethernetInterface !== "" && root.ethernetOnline ? Theme.textActiveColor : Theme.textInactiveColor
        opacityValue: root.ready && root.networkingEnabled && root.ethernetInterface !== "" && root.ethernetOnline ? 1 : 0.5
        visibleWhen: true
      }
    }

    // Network List
    Rectangle {
      Layout.bottomMargin: visible ? root.padding * 2 : 0
      Layout.fillWidth: true
      Layout.topMargin: visible ? root.padding : 0
      border.color: Theme.borderLight
      border.width: 1
      clip: true
      color: Theme.bgElevatedAlt
      implicitHeight: visible ? networkList.implicitHeight + root.padding * 1.4 : 0
      radius: Theme.itemRadius
      visible: root.ready && root.networkingEnabled && root.wifiEnabled && networkList.count > 0

      ListView {
        id: networkList

        anchors.fill: parent
        anchors.margins: root.padding * 0.8
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        implicitHeight: Math.min(contentHeight, root.maxItems * root.itemHeight + (root.maxItems - 1) * Theme.spacingXs)
        interactive: contentHeight > height
        model: root.displayNetworks
        spacing: Theme.spacingXs

        ScrollBar.vertical: ScrollBar {
          policy: networkList.contentHeight > networkList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
          width: Theme.scrollBarWidth
        }
        delegate: NetworkItem {
          id: delegateItem

          width: ListView.view.width

          onPasswordCleared: root.passwordError = ""
          onTriggered: (action, data) => root.handleAction(action, data)
        }
      }
    }
  }

  component NetworkItem: Item {
    id: networkItem

    property bool hovered: false
    readonly property bool isInput: networkItem.modelData.type === "input" || networkItem.modelData.type === "hidden-ssid-input" || networkItem.modelData.type === "hidden-password-input"
    required property var modelData
    readonly property color textColor: networkItem.hovered ? Theme.textOnHoverColor : Theme.textActiveColor

    signal passwordCleared
    signal triggered(string action, var data)

    height: networkItem.isInput ? (networkItem.modelData.hasError ? Theme.itemHeight * 1.6 : Theme.itemHeight * 0.8) : Theme.itemHeight

    Rectangle {
      anchors.fill: parent
      color: networkItem.hovered ? Theme.onHoverColor : "transparent"
      radius: Theme.itemRadius
      visible: !networkItem.isInput

      Behavior on color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }
    }

    Loader {
      anchors.fill: parent
      sourceComponent: networkItem.isInput ? inputComp : actionComp
    }

    Component {
      id: actionComp

      RowLayout {
        spacing: Theme.spacingSm

        Item {
          Layout.leftMargin: root.padding
          Layout.preferredHeight: Theme.itemHeight
          Layout.preferredWidth: Theme.fontLg

          Text {
            id: networkIcon

            anchors.centerIn: parent
            color: networkItem.modelData.bandColor || networkItem.textColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: networkItem.modelData.icon || ""

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }

          Text {
            anchors.bottom: networkIcon.bottom
            anchors.left: networkIcon.right
            anchors.leftMargin: -Theme.spacingXs / 2
            color: (networkItem.modelData.bandColor || networkItem.textColor)
            font.bold: true
            font.family: "Roboto Condensed"
            font.pixelSize: Theme.fontXs
            text: (networkItem.modelData.band === "2.4" ? "2.4" : (networkItem.modelData.band || ""))
            visible: (networkItem.modelData.band || "") !== ""

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }
        }

        OText {
          Layout.fillWidth: true
          color: networkItem.textColor
          text: networkItem.modelData.label || ""

          Behavior on color {
            ColorAnimation {
              duration: Theme.animationDuration
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: networkItem.triggered(networkItem.modelData.action || "", {})
            onEntered: networkItem.hovered = true
            onExited: networkItem.hovered = false
          }
        }

        IconButton {
          Layout.preferredHeight: Theme.itemHeight * 0.8
          Layout.preferredWidth: Theme.itemHeight * 0.8
          Layout.rightMargin: Theme.spacingXs
          colorBg: Theme.critical
          icon: networkItem.modelData.forgetIcon || ""
          tooltipText: qsTr("Forget Network")
          visible: networkItem.modelData.forgetIcon !== undefined

          onClicked: networkItem.triggered("forget-" + networkItem.modelData.ssid, {})
        }

        IconButton {
          Layout.preferredHeight: Theme.itemHeight * 0.8
          Layout.preferredWidth: Theme.itemHeight * 0.8
          Layout.rightMargin: root.padding
          colorBg: Theme.activeColor
          icon: networkItem.modelData.actionIcon || ""
          tooltipText: networkItem.modelData.connected ? qsTr("Disconnect") : qsTr("Connect")
          visible: networkItem.modelData.actionIcon !== undefined

          onClicked: networkItem.triggered(networkItem.modelData.action || "", {})
        }
      }
    }

    Component {
      id: inputComp

      RowLayout {
        spacing: Theme.spacingSm

        Text {
          Layout.leftMargin: root.padding
          color: networkItem.textColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          text: networkItem.modelData.icon || ""
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.rightMargin: root.padding
          spacing: Theme.spacingXs

          RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Theme.itemHeight * 0.8
              border.color: networkItem.modelData.hasError ? Theme.critical : (passwordField.activeFocus ? Theme.activeColor : Theme.borderColor)
              border.width: networkItem.modelData.hasError ? 2 : 1
              color: Theme.bgColor
              radius: Theme.itemRadius

              Behavior on border.color {
                ColorAnimation {
                  duration: Theme.animationDuration
                }
              }

              TextField {
                id: passwordField

                anchors.fill: parent
                anchors.leftMargin: Theme.spacingSm
                anchors.rightMargin: Theme.spacingSm
                color: Theme.textActiveColor
                echoMode: networkItem.modelData.type === "hidden-ssid-input" ? TextInput.Normal : TextInput.Password
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                placeholderText: networkItem.modelData.placeholder || ""
                selectedTextColor: Theme.textContrast(Theme.activeColor)
                selectionColor: Theme.activeColor
                text: ""  // Clear text when switching between inputs

                background: Rectangle {
                  color: "transparent"
                }

                Component.onCompleted: Qt.callLater(() => passwordField.forceActiveFocus())
                Keys.onPressed: event => {
                  if (event.key === Qt.Key_Escape) {
                    event.accepted = true;
                    const cancelAction = networkItem.modelData.type === "hidden-ssid-input" || networkItem.modelData.type === "hidden-password-input" ? "cancel-hidden" : "cancel";
                    networkItem.triggered(cancelAction, {});
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (passwordField.text !== "") {
                      event.accepted = true;
                      networkItem.triggered(networkItem.modelData.action || "", {
                        value: passwordField.text
                      });
                    }
                  }
                }
                onTextChanged: networkItem.passwordCleared()
              }
            }

            IconButton {
              Layout.preferredHeight: Theme.itemHeight * 0.8
              Layout.preferredWidth: Theme.itemHeight * 0.8
              colorBg: Theme.inactiveColor
              icon: "󰅖"
              tooltipText: qsTr("Cancel")

              onClicked: {
                const cancelAction = networkItem.modelData.type === "hidden-ssid-input" || networkItem.modelData.type === "hidden-password-input" ? "cancel-hidden" : "cancel";
                networkItem.triggered(cancelAction, {});
              }
            }

            IconButton {
              Layout.preferredHeight: Theme.itemHeight * 0.8
              Layout.preferredWidth: Theme.itemHeight * 0.8
              colorBg: networkItem.modelData.hasError ? Theme.critical : Theme.activeColor
              enabled: passwordField.text !== ""
              icon: networkItem.modelData.hasError ? "󰀦" : "󰌘"
              tooltipText: networkItem.modelData.hasError ? qsTr("Retry") : qsTr("Submit")

              onClicked: {
                if (passwordField.text !== "") {
                  networkItem.triggered(networkItem.modelData.action || "", {
                    value: passwordField.text
                  });
                }
              }
            }
          }

          OText {
            Layout.fillWidth: true
            color: Theme.critical
            opacity: visible ? 1 : 0
            size: "sm"
            text: "⚠ " + (networkItem.modelData.errorMessage || "")
            visible: networkItem.modelData.hasError && networkItem.modelData.errorMessage !== ""

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
  component ToggleCard: Rectangle {
    id: card

    required property bool checked
    required property bool disabled
    required property string icon
    required property color iconColor
    required property string label
    required property color labelColor
    required property real opacityValue
    property bool visibleWhen: true

    signal toggled(bool checked)

    Layout.fillWidth: true
    Layout.preferredHeight: cardCol.implicitHeight + root.padding * 1.2
    border.color: Theme.borderLight
    border.width: 1
    color: Theme.bgElevated
    opacity: card.opacityValue
    radius: Theme.itemRadius
    visible: card.visibleWhen

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }

    ColumnLayout {
      id: cardCol

      anchors.fill: parent
      anchors.margins: root.padding * 0.9
      spacing: root.padding * 0.4

      OText {
        bold: true
        color: card.labelColor
        text: qsTr(card.label)
      }

      RowLayout {
        spacing: root.padding * 0.3

        Rectangle {
          border.color: Qt.rgba(0, 0, 0, 0.12)
          border.width: 1
          color: card.iconColor
          implicitHeight: implicitWidth
          implicitWidth: Theme.itemHeight * 0.9
          radius: height / 2

          Behavior on color {
            ColorAnimation {
              duration: Theme.animationDuration
            }
          }

          Text {
            anchors.centerIn: parent
            color: Theme.textContrast(parent.color)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.95
            text: card.icon
          }
        }

        Item {
          Layout.fillWidth: true
        }

        OToggle {
          Layout.preferredHeight: Theme.itemHeight * 0.72
          Layout.preferredWidth: Theme.itemHeight * 1.5
          checked: card.checked
          disabled: card.disabled

          onToggled: checked => {
            card.toggled(checked);
          }
        }
      }
    }
  }
}
