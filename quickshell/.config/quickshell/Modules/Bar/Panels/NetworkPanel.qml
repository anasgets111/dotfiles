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
  property var connectingNetwork: null
  readonly property var connectedNetwork: {
    const all = [...savedNetworks, ...availableNetworks];
    return all.find(n => n.connected) || null;
  }
  property string connectionError: ""
  readonly property string ethernetInterface: NetworkService.ethernetInterface
  property bool hiddenConnectStartedOnline: false
  readonly property bool isConnecting: activeConnectionTarget !== ""
  property bool isHiddenTarget: false
  readonly property bool networkingEnabled: NetworkService.networkingEnabled
  readonly property real preferredHeight: mainLayout.implicitHeight + Theme.spacingMd * 2
  readonly property real preferredWidth: 340
  readonly property var processedWifiAps: {
    if (!ready || !networkingEnabled || !wifiEnabled)
      return {
        available: [],
        saved: [],
        viewList: []
      };

    const aps = NetworkService.wifiAps ?? [];

    // Saved: known networks that are in range or connected
    const savedList = aps.filter(ap => ap.saved && (ap.signal > 0 || ap.connected)).sort((a, b) => (b.connected - a.connected) || (b.signal - a.signal)).map(ap => Object.assign({}, ap, {
          _saved: true
        }));

    const savedNames = new Set(savedList.map(n => n.ssid));

    // Available: unknown networks with signal
    const availableList = aps.filter(ap => !savedNames.has(ap.ssid) && ap.signal > 0).sort((a, b) => b.signal - a.signal).map(ap => Object.assign({}, ap, {
          _saved: false
        }));

    const viewList = [...savedList.filter(n => !n.connected), ...availableList.filter(n => !n.connected)];

    return {
      available: availableList,
      saved: savedList,
      viewList: viewList
    };
  }
  readonly property bool ready: NetworkService.ready
  readonly property var savedNetworks: processedWifiAps.saved
  readonly property string pendingSsid: isHiddenTarget ? targetSsid : activeConnectionTarget
  readonly property var pendingAp: pendingSsid ? accessPointForSsid(pendingSsid) : null
  readonly property bool showSsidInput: isHiddenTarget && targetSsid === ""
  readonly property bool showPasswordInput: isConnecting && !showSsidInput && (pendingAp ? securityRequiresPassword(pendingAp.security) : isHiddenTarget)
  property string targetSsid: ""
  readonly property bool wifiEnabled: NetworkService.wifiRadioEnabled
  readonly property string wifiInterface: NetworkService.wifiInterface

  // Look up a flat AP object (for security/UI checks)
  function accessPointForSsid(ssid: string): var {
    const aps = NetworkService.wifiAps ?? [];
    return aps.find(a => a?.ssid === ssid) || null;
  }

  // Look up the live WifiNetwork object (for connect/disconnect/forget actions)
  function wifiNetworkForSsid(ssid: string): var {
    return (NetworkService.wifiDevice?.networks.values ?? []).find(n => n.name === ssid) ?? null;
  }

  function connectToNetwork(ssid: string): void {
    const ap = accessPointForSsid(ssid);
    if (!ap || ap.connected)
      return;
    if (ap.saved) {
      const net = wifiNetworkForSsid(ssid);
      if (net) {
        net.connect();
        root.closeRequested();
      }
    } else {
      activeConnectionTarget = ssid;
      isHiddenTarget = false;
      targetSsid = "";
      connectionError = "";
      if (!securityRequiresPassword(ap.security))
        submitPassword("");
    }
  }

  function securityRequiresPassword(security: string): bool {
    const sec = String(security || "").trim();
    return sec !== "" && sec !== "--";
  }

  function resetConnectionState(): void {
    activeConnectionTarget = "";
    isHiddenTarget = false;
    hiddenConnectStartedOnline = false;
    targetSsid = "";
    connectingNetwork = null;
    if (credentialSheet)
      credentialSheet.clearInputs();
    connectionError = "";
  }

  function submitPassword(password: string): void {
    const trimmedPassword = String(password || "").trim();
    if (!pendingSsid || (showPasswordInput && !trimmedPassword))
      return;
    connectionError = "";
    if (isHiddenTarget) {
      hiddenConnectStartedOnline = NetworkService.wifiOnline;
      NetworkService.connectHiddenWifi(pendingSsid, trimmedPassword, root.wifiInterface);
      return;
    }
    const net = wifiNetworkForSsid(pendingSsid);
    if (!net)
      return;
    root.connectingNetwork = net;
    if (trimmedPassword)
      net.connectWithPsk(trimmedPassword);
    else
      net.connect();
  }

  needsKeyboardFocus: showSsidInput || showPasswordInput

  Component.onDestruction: resetConnectionState()
  onIsOpenChanged: {
    if (!isOpen) {
      resetConnectionState();
      NetworkService.stopWifiScan();
      return;
    }
    NetworkService.startWifiScan();
  }

  // Per-network connection failure / success
  Connections {
    enabled: root.connectingNetwork !== null
    target: root.connectingNetwork ?? null

    function onConnectionFailed(reason) {
      root.connectionError = NetworkService.connectionFailReasonText(reason);
      root.connectingNetwork = null;
    }

    function onConnectedChanged() {
      if (root.connectingNetwork?.connected) {
        root.resetConnectionState();
        root.closeRequested();
      }
    }
  }

  // Hidden network success detection
  Connections {
    target: NetworkService

    function onWifiOnlineChanged() {
      if (root.isHiddenTarget && NetworkService.wifiOnline) {
        root.resetConnectionState();
        root.closeRequested();
      }
    }
  }

  ColumnLayout {
    id: mainLayout

    anchors.fill: parent
    anchors.margins: Theme.spacingMd
    spacing: 0

    RowLayout {
      Layout.bottomMargin: Theme.spacingMd
      Layout.fillWidth: true
      spacing: Theme.spacingXs

      PanelTogglePill {
        active: root.ready
        checked: root.networkingEnabled
        icon: "󱘖"
        label: "Network"

        onToggled: c => NetworkService.setNetworkingEnabled(c)
      }

      PanelTogglePill {
        active: root.ready && root.networkingEnabled
        checked: root.wifiEnabled
        icon: "󰤨"
        label: "Wi-Fi"

        onToggled: c => NetworkService.setWifiRadioEnabled(c)
      }

      PanelTogglePill {
        active: root.ready && root.networkingEnabled && root.ethernetInterface !== ""
        checked: NetworkService.ethernetOnline
        icon: "󰈀"
        label: "Ethernet"

        onToggled: c => c ? NetworkService.connectEthernet() : NetworkService.disconnectEthernet()
      }
    }

    HeroCard {
      Layout.bottomMargin: visible ? Theme.spacingMd : 0
      Layout.fillWidth: true
      network: root.connectedNetwork
      visible: root.connectedNetwork !== null

      onDisconnectClicked: NetworkService.disconnectWifi()
      onForgetClicked: ssid => {
        const net = wifiNetworkForSsid(ssid);
        net?.forget();
      }
    }

    CredentialSheet {
      id: credentialSheet

      Layout.bottomMargin: visible ? Theme.spacingMd : 0
      Layout.fillWidth: true
      errorMessage: root.connectionError
      passwordMode: root.showPasswordInput
      ssidMode: root.showSsidInput
      targetName: root.isHiddenTarget ? root.targetSsid : root.activeConnectionTarget
      visible: root.isConnecting

      onCancelled: root.resetConnectionState()
      onErrorCleared: root.connectionError = ""
      onPasswordSubmitted: pw => root.submitPassword(pw)
      onSsidSubmitted: ssid => {
        ssid = ssid.trim();
        if (ssid) {
          root.targetSsid = ssid;
          root.connectionError = "";
          const targetAp = root.accessPointForSsid(ssid);
          if (targetAp && !root.securityRequiresPassword(targetAp?.security))
            root.submitPassword("");
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      visible: !root.isConnecting && root.wifiEnabled && root.networkingEnabled

      OText {
        Layout.bottomMargin: Theme.spacingXs
        bold: true
        color: Theme.textInactiveColor
        size: "xs"
        text: "NETWORKS"
        visible: root.savedNetworks.length > 0 || root.availableNetworks.length > 0
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(networkList.contentHeight, Theme.itemHeight * 7)
        clip: true
        color: "transparent"

        ListView {
          id: networkList

          anchors.fill: parent
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          model: root.processedWifiAps.viewList
          spacing: 2

          ScrollBar.vertical: ScrollBar {
            policy: networkList.contentHeight > networkList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 4
          }
          delegate: NetworkRow {
            required property var modelData

            isSaved: modelData._saved
            network: modelData
            width: ListView.view.width

            onClicked: root.connectToNetwork(modelData.ssid)
            onForgetClicked: {
              const net = wifiNetworkForSsid(modelData.ssid);
              net?.forget();
            }
          }
        }
      }

      HoverButton {
        Layout.bottomMargin: Theme.spacingSm
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight * 0.85
        Layout.topMargin: Theme.spacingXs
        showTopBorder: true
        visible: root.wifiEnabled && root.networkingEnabled && !root.isConnecting

        onClicked: {
          root.activeConnectionTarget = "hidden";
          root.isHiddenTarget = true;
          root.targetSsid = "";
          if (credentialSheet)
            credentialSheet.clearInputs();
          root.connectionError = "";
        }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Theme.spacingSm
          anchors.rightMargin: Theme.spacingSm
          anchors.topMargin: 1

          OText {
            color: Theme.activeColor
            text: qsTr("Hidden Network…")
          }

          Item {
            Layout.fillWidth: true
          }

          Text {
            color: Theme.textInactiveColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.85
            opacity: 0.5
            text: "󰁔"
          }
        }
      }
    }

    StateMessage {
      Layout.fillHeight: true
      Layout.fillWidth: true
      Layout.minimumHeight: 120
      icon: "󰤭"
      text: qsTr("Scanning\u2026")
      visible: !root.isConnecting && root.wifiEnabled && root.networkingEnabled && root.savedNetworks.length === 0 && root.availableNetworks.length === 0
    }

    StateMessage {
      Layout.fillHeight: true
      Layout.fillWidth: true
      Layout.minimumHeight: 120
      icon: root.networkingEnabled ? "󰤮" : "󱘖"
      text: !root.networkingEnabled ? qsTr("Networking Disabled") : qsTr("Wi-Fi Off")
      visible: !root.networkingEnabled || !root.wifiEnabled
    }
  }

  component BandBadge: Rectangle {
    property string band: ""
    readonly property string bv: String(band || "").trim()

    color: bv === "6" ? Theme.powerSaveColor : bv === "5" ? Theme.activeColor : Theme.inactiveColor
    implicitHeight: Theme.fontSm + 2
    implicitWidth: bandText.implicitWidth + 6
    opacity: 0.7
    radius: height / 2
    visible: bv !== ""

    OText {
      id: bandText

      anchors.centerIn: parent
      bold: true
      color: Theme.bgColor
      size: "xs"
      text: parent.bv === "2.4" ? "2.4" : parent.bv + "G"
    }
  }
  component CredentialSheet: ColumnLayout {
    id: sheet

    property string errorMessage: ""
    property bool passwordMode: false
    property bool ssidMode: false
    property string targetName: ""
    readonly property bool waitingMode: !ssidMode && !passwordMode

    signal cancelled
    signal errorCleared
    signal passwordSubmitted(string password)
    signal ssidSubmitted(string ssid)

    function clearInputs(): void {
      ssidField.text = "";
      pwField.text = "";
    }

    spacing: Theme.spacingSm

    OText {
      bold: true
      color: Theme.textActiveColor
      size: "sm"
      text: sheet.ssidMode ? qsTr("Hidden Network") : sheet.waitingMode ? qsTr("Connecting to \u201C%1\u201D").arg(sheet.targetName) : qsTr("Connect to \u201C%1\u201D").arg(sheet.targetName)
    }

    SheetField {
      id: ssidField

      Layout.fillWidth: true
      placeholder: qsTr("Network name")
      visible: sheet.ssidMode

      onAccepted: val => sheet.ssidSubmitted(val)
      onCancelled: sheet.cancelled()
    }

    SheetField {
      id: pwField

      Layout.fillWidth: true
      hasError: sheet.errorMessage !== ""
      isPassword: true
      placeholder: qsTr("Password")
      visible: sheet.passwordMode

      onAccepted: val => sheet.passwordSubmitted(val)
      onCancelled: sheet.cancelled()
      onTextEdited: sheet.errorCleared()
    }

    OText {
      color: Theme.critical
      size: "xs"
      text: "⚠ " + sheet.errorMessage
      visible: sheet.errorMessage !== ""

      Behavior on opacity {
        NumberAnimation {
          duration: 150
        }
      }
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

        onClicked: sheet.cancelled()
      }

      OButton {
        enabled: ssidField.text.trim() !== ""
        text: qsTr("Next")
        variant: "primary"
        visible: sheet.ssidMode

        onClicked: sheet.ssidSubmitted(ssidField.text)
      }

      OButton {
        enabled: pwField.text.trim() !== ""
        icon: sheet.errorMessage !== "" ? "󰀦" : ""
        text: sheet.errorMessage !== "" ? qsTr("Retry") : qsTr("Connect")
        variant: "primary"
        visible: sheet.passwordMode

        onClicked: sheet.passwordSubmitted(pwField.text)
      }
    }
  }
  component HeroCard: Rectangle {
    id: hero

    property var network: null

    signal disconnectClicked
    signal forgetClicked(string ssid)

    border.color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.25)
    border.width: 1
    color: Theme.activeSubtle
    implicitHeight: visible ? heroContent.implicitHeight + Theme.spacingSm * 2 : 0
    radius: 14

    Behavior on implicitHeight {
      NumberAnimation {
        duration: 200
        easing.type: Easing.OutCubic
      }
    }

    RowLayout {
      id: heroContent

      anchors.fill: parent
      anchors.leftMargin: Theme.spacingMd
      anchors.margins: Theme.spacingSm
      spacing: Theme.spacingSm
      visible: hero.network !== null

      SignalBars {
        activeColor: Theme.activeColor
        signal_: hero.network?.signal || 0
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        OText {
          bold: true
          color: Theme.activeColor
          text: hero.network?.ssid || ""
        }

        RowLayout {
          spacing: Theme.spacingXs

          OText {
            color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.7)
            size: "xs"
            text: qsTr("Connected")
          }

          BandBadge {
            band: hero.network?.band || ""
          }
        }
      }

      Item {
        Layout.fillWidth: true
      }

      PanelActionIcon {
        icon: "󰩺"
        tint: Theme.critical
        visible: hero.network?._saved === true && (hero.network?.ssid || "") !== ""

        onClicked: hero.forgetClicked(hero.network?.ssid || "")
      }

      PanelActionIcon {
        icon: "󱘖"
        tint: Theme.critical

        onClicked: hero.disconnectClicked()
      }
    }
  }
  component HoverButton: Item {
    id: hbtn

    property bool showTopBorder: false

    signal clicked

    implicitHeight: Theme.itemHeight

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      color: Theme.borderLight
      height: 1
      opacity: 0.5
      visible: showTopBorder
    }

    MouseArea {
      id: hma

      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true

      onClicked: parent.clicked()

      Rectangle {
        anchors.fill: parent
        anchors.topMargin: showTopBorder ? 1 : 0
        color: hma.containsMouse ? Qt.rgba(Theme.textActiveColor.r, Theme.textActiveColor.g, Theme.textActiveColor.b, 0.06) : "transparent"
        radius: Theme.itemRadius

        Behavior on color {
          ColorAnimation {
            duration: 120
          }
        }
      }
    }
  }
  component NetworkRow: Rectangle {
    id: row

    property bool isSaved: false
    property var network: null

    signal clicked
    signal forgetClicked

    color: rowMa.containsMouse ? Qt.rgba(Theme.textActiveColor.r, Theme.textActiveColor.g, Theme.textActiveColor.b, 0.06) : "transparent"
    height: Theme.itemHeight
    radius: 10

    Behavior on color {
      ColorAnimation {
        duration: 120
      }
    }

    MouseArea {
      id: rowMa

      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true

      onClicked: row.clicked()
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Theme.spacingSm
      anchors.rightMargin: Theme.spacingSm
      spacing: Theme.spacingSm

      SignalBars {
        activeColor: Theme.textInactiveColor
        signal_: row.network?.signal || 0
      }

      OText {
        Layout.fillWidth: true
        color: Theme.textActiveColor
        elide: Text.ElideRight
        text: row.network?.ssid || ""
      }

      Rectangle {
        color: Theme.activeColor
        implicitHeight: 6
        implicitWidth: 6
        opacity: 0.5
        radius: 3
        visible: row.isSaved && !rowMa.containsMouse
      }

      BandBadge {
        band: row.network?.band || ""
      }

      Text {
        color: Theme.textInactiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize * 0.8
        opacity: 0.35
        text: "󰌾"
        visible: {
          const sec = row.network?.security || "";
          return sec !== "" && sec !== "--";
        }
      }

      PanelActionIcon {
        id: forgetBtn

        icon: "󰩺"
        tint: Theme.critical
        visible: row.isSaved && (rowMa.containsMouse || forgetBtn.hovered)

        onClicked: row.forgetClicked()
      }
    }
  }
  component SheetField: Item {
    id: sf

    property bool hasError: false
    property bool isPassword: false
    property string placeholder: ""
    property alias text: innerField.text

    signal accepted(string val)
    signal cancelled
    signal textEdited

    implicitHeight: 36

    onVisibleChanged: if (visible)
      Qt.callLater(() => innerField.forceActiveFocus())

    Rectangle {
      anchors.fill: parent
      border.color: sf.hasError ? Theme.critical : innerField.activeFocus ? Theme.activeColor : Theme.borderColor
      border.width: sf.hasError ? 2 : 1
      color: Theme.bgColor
      radius: 10

      Behavior on border.color {
        ColorAnimation {
          duration: 150
        }
      }

      TextField {
        id: innerField

        anchors.fill: parent
        anchors.leftMargin: Theme.spacingSm
        anchors.rightMargin: Theme.spacingSm
        color: Theme.textActiveColor
        echoMode: sf.isPassword ? TextInput.Password : TextInput.Normal
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        placeholderText: sf.placeholder
        selectionColor: Theme.activeColor

        background: Rectangle {
          color: "transparent"
        }

        Component.onCompleted: if (sf.visible)
          Qt.callLater(() => innerField.forceActiveFocus())
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            sf.cancelled();
          } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && innerField.text !== "") {
            event.accepted = true;
            sf.accepted(innerField.text);
          }
        }
        onTextEdited: sf.textEdited()
      }
    }
  }
  component SignalBars: Row {
    id: bars

    property color activeColor: Theme.activeColor
    property list<int> barHeights: [8, 13, 18]
    property int barSpacing: 2
    property int barWidth: 4
    readonly property int level: signal_ > 70 ? 3 : signal_ > 40 ? 2 : signal_ > 0 ? 1 : 0
    property int signal_: 0

    Layout.preferredHeight: 18
    spacing: bars.barSpacing

    Repeater {
      model: 3

      Rectangle {
        required property int index

        anchors.bottom: bars.bottom
        color: index < bars.level ? bars.activeColor : Theme.textInactiveColor
        height: bars.barHeights[index]
        opacity: index < bars.level ? 1.0 : 0.25
        radius: bars.barWidth / 2
        width: bars.barWidth

        Behavior on color {
          ColorAnimation {
            duration: 150
          }
        }
        Behavior on opacity {
          NumberAnimation {
            duration: 150
          }
        }
      }
    }
  }
  component StateMessage: Item {
    property string icon: ""
    property string text: ""

    implicitHeight: stateContent.implicitHeight

    ColumnLayout {
      id: stateContent

      anchors.centerIn: parent
      spacing: Theme.spacingSm

      Text {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.textInactiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize * 2
        opacity: 0.4
        text: parent.parent.icon
      }

      OText {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.textInactiveColor
        text: parent.parent.text
      }
    }
  }
}
