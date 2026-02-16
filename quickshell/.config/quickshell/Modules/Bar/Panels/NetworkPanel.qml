pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Core

PanelContentBase {
  id: root

  property string activeConnectionTarget: ""
  readonly property var availableNetworks: processedWifiAps.available
  property string connectionError: ""
  readonly property string ethernetInterface: NetworkService.ethernetInterface
  property bool hiddenConnectStartedOnline: false
  readonly property bool isConnecting: activeConnectionTarget !== ""
  property bool isHiddenTarget: false
  readonly property int itemHeight: Theme.itemHeight
  readonly property int maxItems: 7
  readonly property bool networkingEnabled: NetworkService.networkingEnabled
  readonly property int padding: Theme.spacingSm
  readonly property real preferredHeight: mainLayout.implicitHeight + root.padding * 2
  readonly property real preferredWidth: 350
  readonly property var processedWifiAps: {
    if (!ready || !networkingEnabled || !wifiEnabled)
      return {
        available: [],
        saved: []
      };

    const saved = savedConnections || [];
    const apMap = new Map();
    for (const ap of (wifiAps || [])) {
      const ssid = ap?.ssid;
      if (!ssid)
        continue;
      const current = apMap.get(ssid);
      const apSignal = ap?.signal || 0;
      const currentSignal = current?.signal || 0;
      if (!current || (ap?.connected && !current?.connected) || (ap?.connected === current?.connected && apSignal > currentSignal))
        apMap.set(ssid, ap);
    }
    const savedSsids = new Set(saved.map(s => s.ssid));

    const available = wifiAps.filter(ap => ap?.ssid && !savedSsids.has(ap.ssid)).map(ap => ({
          ssid: ap.ssid,
          signal: ap.signal || 0,
          band: root.getBand(ap),
          security: ap.security || "",
          connected: ap.connected || false
        })).sort((a, b) => (b.signal || 0) - (a.signal || 0));

    const savedMapped = saved.map(conn => {
      const ap = apMap.get(conn.ssid);
      return {
        ssid: conn.ssid,
        connectionId: conn.connectionId,
        connected: ap?.connected || false,
        signal: ap?.signal || 0,
        band: root.getBand(ap),
        security: ap?.security || "",
        available: !!ap && (ap.signal || 0) > 0
      };
    }).filter(n => n.available || n.connected).sort((a, b) => (b.connected - a.connected) || (b.signal - a.signal));

    return {
      available,
      saved: savedMapped
    };
  }
  readonly property bool ready: NetworkService.ready
  readonly property var savedConnections: NetworkService.savedWifiAps || []
  readonly property var savedNetworks: processedWifiAps.saved
  readonly property bool showNetworkLists: !isConnecting || (isHiddenTarget && !showSsidInput && !showPasswordInput)
  readonly property bool showPasswordInput: isConnecting && (!isHiddenTarget || targetSsid !== "")
  readonly property bool showSsidInput: isHiddenTarget && targetSsid === ""
  property string targetSsid: ""
  readonly property var wifiAps: NetworkService.wifiAps || []
  readonly property bool wifiEnabled: NetworkService.wifiRadioEnabled
  readonly property string wifiInterface: NetworkService.wifiInterface

  function connectToNetwork(ssid) {
    const ap = findAp(ssid);
    if (!ap || ap.connected)
      return;
    const saved = findSavedConn(ssid);
    if (saved?.connectionId) {
      NetworkService.activateConnection(saved.connectionId, wifiInterface);
      root.closeRequested();
    } else {
      activeConnectionTarget = ssid;
      isHiddenTarget = false;
      targetSsid = "";
      connectionError = "";
    }
  }

  function disconnectNetwork() {
    NetworkService.disconnectWifi();
  }

  function findAp(ssid) {
    const matches = wifiAps.filter(a => a?.ssid === ssid);
    return matches.find(a => a?.connected) || matches[0] || null;
  }

  function findSavedConn(ssid) {
    return savedConnections.find(c => c?.ssid === ssid);
  }

  function forgetNetwork(ssid) {
    const connId = findSavedConn(ssid)?.connectionId;
    if (connId)
      NetworkService.forgetWifiConnection(connId);
  }

  function getBand(ap) {
    return root.normalizeBand(ap?.band);
  }

  function handleWifiConnectionUpdate() {
    if (activeConnectionTarget && activeConnectionTarget !== "hidden") {
      const ap = findAp(activeConnectionTarget);
      if (ap?.connected) {
        resetConnectionState();
        root.closeRequested();
        return;
      }
    }
    if (isHiddenTarget && targetSsid && NetworkService.wifiOnline) {
      const ap = findAp(targetSsid);
      if (ap?.connected || !hiddenConnectStartedOnline) {
        resetConnectionState();
        root.closeRequested();
      }
    }
  }

  function normalizeBand(b) {
    const s = String(b || "").trim();
    if (s.startsWith("2"))
      return "2.4";
    if (s.startsWith("5"))
      return "5";
    if (s.startsWith("6"))
      return "6";
    return "";
  }

  function resetConnectionState() {
    activeConnectionTarget = "";
    isHiddenTarget = false;
    hiddenConnectStartedOnline = false;
    targetSsid = "";
    ssidInput.text = "";
    passwordInput.text = "";
    connectionError = "";
  }

  function setHiddenSsid(ssid) {
    ssid = String(ssid || "").trim();
    if (ssid) {
      targetSsid = ssid;
      connectionError = "";
    }
  }

  function startHiddenConnection() {
    activeConnectionTarget = "hidden";
    isHiddenTarget = true;
    targetSsid = "";
    connectionError = "";
  }

  function submitPassword(password) {
    password = String(password || "").trim();
    if (!wifiInterface || !password)
      return;

    if (isHiddenTarget) {
      if (targetSsid) {
        connectionError = "";
        hiddenConnectStartedOnline = NetworkService.wifiOnline;
        NetworkService.connectToWifi(targetSsid, password, wifiInterface, true);
      }
    } else if (activeConnectionTarget) {
      connectionError = "";
      NetworkService.connectToWifi(activeConnectionTarget, password, wifiInterface, false);
    }
  }

  needsKeyboardFocus: showSsidInput || showPasswordInput

  onIsOpenChanged: if (!isOpen)
    resetConnectionState()

  Timer {
    interval: 10000
    repeat: true
    running: root.isOpen

    onTriggered: NetworkService.refreshAll()
  }

  Connections {
    function onConnectionError(ssid, errorMessage) {
      if (ssid === root.activeConnectionTarget || (root.isHiddenTarget && ssid === root.targetSsid))
        root.connectionError = errorMessage;
    }

    function onWifiApsChanged() {
      root.handleWifiConnectionUpdate();
    }

    function onWifiOnlineChanged() {
      root.handleWifiConnectionUpdate();
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
    id: mainLayout

    anchors.fill: parent
    spacing: Theme.spacingMd

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingMd
      visible: root.showNetworkLists

      RowLayout {
        Layout.fillWidth: true
        spacing: root.padding * 1.25

        ToggleCard {
          active: root.ready
          checked: NetworkService.networkingEnabled
          icon: "󱘖"
          label: "Networking"

          onToggled: c => NetworkService.setNetworkingEnabled(c)
        }

        ToggleCard {
          active: root.ready && root.networkingEnabled
          checked: NetworkService.wifiRadioEnabled
          icon: "󰤨"
          label: "Wi-Fi"

          onToggled: c => NetworkService.setWifiRadioEnabled(c)
        }

        ToggleCard {
          checked: NetworkService.ethernetOnline
          disabled: !root.ready || !root.networkingEnabled || root.ethernetInterface === ""
          icon: "󰈀"
          label: "Ethernet"

          onToggled: c => c ? NetworkService.connectEthernet() : NetworkService.disconnectEthernet()
        }
      }

      NetworkListFrame {
        Layout.fillWidth: true
        contentHeight: Math.max(Theme.itemHeight + root.padding * 1.6, savedCol.implicitHeight + root.padding * 1.6)
        title: "SAVED NETWORKS"
        visible: root.savedNetworks.length > 0

        ColumnLayout {
          id: savedCol

          anchors.fill: parent
          anchors.margins: root.padding * 0.8
          spacing: Theme.spacingXs

          Repeater {
            model: root.savedNetworks

            delegate: NetworkCard {
              Layout.fillWidth: true

              onConnectClicked: ssid => root.connectToNetwork(ssid)
              onDisconnectClicked: () => root.disconnectNetwork()
              onForgetClicked: ssid => root.forgetNetwork(ssid)
            }
          }
        }
      }

      NetworkListFrame {
        Layout.fillWidth: true
        contentHeight: Math.min(availableList.contentHeight + root.padding * 1.6, root.maxItems * root.itemHeight + root.padding * 1.6)
        title: "AVAILABLE NETWORKS"

        ListView {
          id: availableList

          anchors.fill: parent
          anchors.margins: root.padding * 0.8
          boundsBehavior: Flickable.StopAtBounds
          clip: true
          interactive: contentHeight > height
          model: root.availableNetworks
          spacing: Theme.spacingXs

          ScrollBar.vertical: ScrollBar {
            policy: availableList.contentHeight > availableList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: Theme.scrollBarWidth
          }
          delegate: NetworkCard {
            width: ListView.view.width

            onConnectClicked: ssid => root.connectToNetwork(ssid)
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: hiddenActionRow.implicitHeight + root.padding * 1.2
        border.color: Theme.borderLight
        border.width: 1
        color: hiddenMouseArea.containsMouse ? Theme.borderLight : Theme.bgElevated
        radius: Theme.itemRadius
        visible: root.wifiEnabled && root.networkingEnabled

        MouseArea {
          id: hiddenMouseArea

          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          onClicked: root.startHiddenConnection()
        }

        RowLayout {
          id: hiddenActionRow

          anchors.fill: parent
          anchors.leftMargin: root.padding
          anchors.rightMargin: root.padding
          spacing: Theme.spacingSm

          Text {
            color: Theme.textInactiveColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: "󰒟"
          }

          OText {
            Layout.fillWidth: true
            color: Theme.textInactiveColor
            text: qsTr("Connect to Hidden Network")
          }

          IconButton {
            Layout.preferredHeight: Theme.itemHeight * 0.8
            Layout.preferredWidth: Theme.itemHeight * 0.8
            colorBg: Theme.activeColor
            icon: "󰌘"
            tooltipText: qsTr("Connect")

            onClicked: root.startHiddenConnection()
          }
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingSm
      visible: !root.showNetworkLists

      OText {
        Layout.fillWidth: true
        bold: true
        text: root.showSsidInput ? qsTr("HIDDEN NETWORK") : qsTr("CONNECT TO \"%1\"").arg(root.isHiddenTarget ? root.targetSsid : root.activeConnectionTarget)
      }

      CredentialsInput {
        id: ssidInput

        Layout.fillWidth: true
        label: qsTr("Enter network name:")
        placeholder: qsTr("Network name")
        visible: root.showSsidInput

        onAccepted: value => root.setHiddenSsid(value)
        onCancelled: root.resetConnectionState()
      }

      CredentialsInput {
        id: passwordInput

        Layout.fillWidth: true
        errorMessage: root.connectionError
        isPassword: true
        label: root.isHiddenTarget ? qsTr("Password:") : qsTr("Enter password for \"%1\":").arg(root.activeConnectionTarget)
        placeholder: qsTr("Password")
        visible: root.showPasswordInput

        onAccepted: value => root.submitPassword(value)
        onCancelled: root.resetConnectionState()
        onTextChanged: root.connectionError = ""
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Item {
          Layout.fillWidth: true
        }

        OButton {
          text: qsTr("Cancel")
          variant: "ghost"

          onClicked: root.resetConnectionState()
        }

        OButton {
          enabled: ssidInput.text !== ""
          text: qsTr("Next")
          variant: "primary"
          visible: root.showSsidInput

          onClicked: root.setHiddenSsid(ssidInput.text)
        }

        OButton {
          enabled: passwordInput.text !== ""
          icon: root.connectionError !== "" ? "󰀦" : ""
          text: root.connectionError !== "" ? qsTr("Retry") : qsTr("Connect")
          variant: "primary"
          visible: root.showPasswordInput

          onClicked: root.submitPassword(passwordInput.text)
        }
      }
    }
  }

  component CredentialsInput: ColumnLayout {
    id: inputRoot

    property string errorMessage: ""
    readonly property bool hasError: errorMessage !== ""
    property bool isPassword: false
    required property string label
    property string placeholder: ""
    property alias text: field.text

    signal accepted(string value)
    signal cancelled

    spacing: Theme.spacingXs

    onVisibleChanged: if (visible)
      Qt.callLater(() => field.forceActiveFocus())

    OText {
      size: "sm"
      text: inputRoot.label
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Theme.itemHeight * 0.9
      border.color: inputRoot.hasError ? Theme.critical : (field.activeFocus ? Theme.activeColor : Theme.borderColor)
      border.width: inputRoot.hasError ? 2 : 1
      color: Theme.bgColor
      radius: Theme.itemRadius

      Behavior on border.color {
        ColorAnimation {
          duration: Theme.animationDuration
        }
      }

      TextField {
        id: field

        anchors.fill: parent
        anchors.leftMargin: Theme.spacingSm
        anchors.rightMargin: Theme.spacingSm
        color: Theme.textActiveColor
        echoMode: inputRoot.isPassword ? TextInput.Password : TextInput.Normal
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        placeholderText: inputRoot.placeholder
        selectionColor: Theme.activeColor

        background: Rectangle {
          color: "transparent"
        }

        Component.onCompleted: if (inputRoot.visible)
          Qt.callLater(() => field.forceActiveFocus())
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            inputRoot.cancelled();
          } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && field.text !== "") {
            event.accepted = true;
            inputRoot.accepted(field.text);
          }
        }
      }
    }

    OText {
      Layout.fillWidth: true
      color: Theme.critical
      opacity: visible ? 1 : 0
      size: "sm"
      text: "⚠ " + inputRoot.errorMessage
      visible: inputRoot.hasError

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animationDuration
        }
      }
    }
  }
  component NetworkCard: Rectangle {
    id: card

    readonly property bool isConnected: modelData?.connected || false
    readonly property bool isSaved: modelData?.connectionId !== undefined
    required property var modelData
    readonly property string ssid: modelData?.ssid || ""

    signal connectClicked(string ssid)
    signal disconnectClicked
    signal forgetClicked(string ssid)

    border.color: card.isConnected ? Theme.activeColor : "transparent"
    border.width: card.isConnected ? 1 : 0
    color: card.isConnected ? Theme.activeSubtle : (ma.containsMouse ? Theme.borderLight : "transparent")
    height: Theme.itemHeight
    radius: Theme.itemRadius

    Behavior on color {
      ColorAnimation {
        duration: Theme.animationDuration
      }
    }

    MouseArea {
      id: ma

      anchors.fill: parent
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: !card.isConnected
      hoverEnabled: true

      onClicked: card.connectClicked(card.ssid)
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: root.padding
      anchors.rightMargin: root.padding
      spacing: Theme.spacingSm

      Text {
        color: card.isConnected ? Theme.activeColor : Theme.textActiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: NetworkService.getWifiIcon(modelData?.band || "", modelData?.signal || 0)
      }

      OText {
        Layout.fillWidth: true
        bold: card.isConnected
        color: card.isConnected ? Theme.activeColor : Theme.textActiveColor
        elide: Text.ElideRight
        text: card.ssid
      }

      OText {
        color: Theme.activeColor
        size: "sm"
        text: "󰄬"
        visible: card.isConnected
      }

      Rectangle {
        id: bandBadge

        readonly property string bandValue: String(card.modelData?.band || "").trim()

        Layout.preferredHeight: Theme.fontSm + 4
        Layout.preferredWidth: bandText.implicitWidth + Theme.spacingSm
        color: {
          if (bandBadge.bandValue === "6")
            return Theme.powerSaveColor;
          if (bandBadge.bandValue === "5")
            return Theme.activeColor;
          return Theme.inactiveColor;
        }
        radius: height / 2
        visible: bandBadge.bandValue !== ""

        OText {
          id: bandText

          anchors.centerIn: parent
          bold: true
          color: Theme.bgColor
          size: "xs"
          text: bandBadge.bandValue === "2.4" ? "2.4" : bandBadge.bandValue + "G"
        }
      }

      OText {
        color: Theme.textInactiveColor
        size: "xs"
        text: "󰌾"
        visible: (modelData?.security || "") !== "" && (modelData?.security || "") !== "--"
      }

      IconButton {
        Layout.preferredHeight: Theme.itemHeight * 0.75
        Layout.preferredWidth: Theme.itemHeight * 0.75
        colorBg: Theme.critical
        icon: "󰩺"
        tooltipText: qsTr("Forget Network")
        visible: card.isSaved

        onClicked: card.forgetClicked(card.ssid)
      }

      IconButton {
        Layout.preferredHeight: Theme.itemHeight * 0.75
        Layout.preferredWidth: Theme.itemHeight * 0.75
        colorBg: Theme.warning
        icon: "󱘖"
        tooltipText: qsTr("Disconnect")
        visible: card.isConnected

        onClicked: card.disconnectClicked()
      }
    }
  }
  component NetworkListFrame: ColumnLayout {
    default property alias content: container.data
    required property real contentHeight
    required property string title

    spacing: Theme.spacingXs

    OText {
      bold: true
      color: Theme.textInactiveColor
      size: "xs"
      text: parent.title
    }

    Rectangle {
      id: container

      Layout.fillWidth: true
      Layout.preferredHeight: parent.contentHeight
      border.color: Theme.borderLight
      border.width: 1
      clip: true
      color: Theme.bgElevatedAlt
      radius: Theme.itemRadius
    }
  }
  component ToggleCard: Rectangle {
    id: toggleCard

    property bool active: !disabled
    readonly property int cardPadding: Theme.spacingSm * 0.9
    property bool checked: false
    property bool disabled: false
    required property string icon
    readonly property int iconSize: Theme.itemHeight * 0.9
    required property string label

    signal toggled(bool checked)

    Layout.fillWidth: true
    Layout.preferredHeight: contentRow.implicitHeight + cardPadding * 2
    border.color: Theme.borderLight
    border.width: 1
    color: Theme.bgElevated
    opacity: active ? 1.0 : Theme.opacityDisabled
    radius: Theme.itemRadius

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animationDuration
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: toggleCard.active ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: toggleCard.active

      onClicked: toggleCard.toggled(!toggleCard.checked)
    }

    RowLayout {
      id: contentRow

      anchors.fill: parent
      anchors.margins: toggleCard.cardPadding
      spacing: toggleCard.cardPadding

      Rectangle {
        border.color: Qt.rgba(0, 0, 0, 0.12)
        border.width: 1
        color: toggleCard.active ? Qt.lighter(Theme.onHoverColor, 1.25) : Theme.inactiveColor
        implicitHeight: toggleCard.iconSize
        implicitWidth: toggleCard.iconSize
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
          text: toggleCard.icon
        }
      }

      OText {
        Layout.fillWidth: true
        bold: true
        color: toggleCard.active ? Theme.textActiveColor : Theme.textInactiveColor
        text: qsTr(toggleCard.label)
      }

      OToggle {
        Layout.preferredHeight: Theme.itemHeight * 0.72
        Layout.preferredWidth: Theme.itemHeight * 1.5
        checked: toggleCard.checked
        disabled: toggleCard.disabled || !toggleCard.active

        onToggled: c => toggleCard.toggled(c)
      }
    }
  }
}
