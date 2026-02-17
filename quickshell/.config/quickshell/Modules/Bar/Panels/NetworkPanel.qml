pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import qs.Config
import qs.Components
import qs.Services.Core

PanelContentBase {
  id: root

  property string activeConnectionTarget: ""
  readonly property var availableNetworks: processedWifiAps.available
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

    const saved = savedConnections || [];
    const apMap = new Map();

    // 1. Efficiently map best APs
    for (const ap of (wifiAps || [])) {
      const ssid = ap?.ssid;
      if (!ssid)
        continue;
      const curr = apMap.get(ssid);
      // Logic: Prefer connected > stronger signal
      if (!curr || (ap?.connected && !curr?.connected) || (ap?.connected === curr?.connected && (ap?.signal || 0) > (curr?.signal || 0)))
        apMap.set(ssid, ap);
    }

    const savedSsids = new Set(saved.map(s => s.ssid));

    // 2. Build Saved List
    const savedList = saved.map(conn => {
      const ap = apMap.get(conn.ssid);
      return {
        ssid: conn.ssid,
        connectionId: conn.connectionId,
        connected: ap?.connected || false,
        signal: ap?.signal || 0,
        band: normalizeBand(ap?.band),
        security: ap?.security || "",
        available: !!ap && (ap.signal || 0) > 0,
        _saved: true // Tag for UI
      };
    }).filter(n => n.available || n.connected).sort((a, b) => (b.connected - a.connected) || (b.signal - a.signal));

    // 3. Build Available List
    const availableList = Array.from(apMap.values()).filter(ap => ap?.ssid && !savedSsids.has(ap.ssid)).map(ap => ({
          ssid: ap.ssid,
          signal: ap.signal || 0,
          band: normalizeBand(ap?.band),
          security: ap.security || "",
          connected: ap.connected || false,
          _saved: false // Tag for UI
        })).sort((a, b) => b.signal - a.signal);

    // 4. Generate Unified View List (Everything NOT connected)
    // Doing this here prevents the ListView from recalculating on every paint
    const viewList = [...savedList.filter(n => !n.connected), ...availableList.filter(n => !n.connected)];

    return {
      available: availableList,
      saved: savedList,
      viewList: viewList
    };
  }
  readonly property bool ready: NetworkService.ready
  readonly property var savedConnections: NetworkService.savedWifiAps || []
  readonly property var savedNetworks: processedWifiAps.saved
  readonly property bool showPasswordInput: isConnecting && (!isHiddenTarget || targetSsid !== "")
  readonly property bool showSsidInput: isHiddenTarget && targetSsid === ""
  property string targetSsid: ""
  readonly property var wifiAps: NetworkService.wifiAps || []
  readonly property bool wifiEnabled: NetworkService.wifiRadioEnabled
  readonly property string wifiInterface: NetworkService.wifiInterface

  function connectToNetwork(ssid: string): void {
    const aps = wifiAps.filter(a => a?.ssid === ssid);
    const ap = aps.find(a => a?.connected) || aps[0];
    if (!ap || ap.connected)
      return;
    const saved = savedConnections.find(c => c?.ssid === ssid);
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

  function normalizeBand(b): string {
    const s = String(b || "").trim();
    return s.startsWith("2") ? "2.4" : s.startsWith("5") ? "5" : s.startsWith("6") ? "6" : "";
  }

  function resetConnectionState(): void {
    activeConnectionTarget = "";
    isHiddenTarget = false;
    hiddenConnectStartedOnline = false;
    targetSsid = "";
    if (credentialSheet)
      credentialSheet.clearInputs();
    connectionError = "";
  }

  function submitPassword(password: string): void {
    password = password.trim();
    if (!wifiInterface || !password)
      return;
    connectionError = "";
    if (isHiddenTarget && targetSsid) {
      hiddenConnectStartedOnline = NetworkService.wifiOnline;
      NetworkService.connectToWifi(targetSsid, password, wifiInterface, true);
    } else if (activeConnectionTarget) {
      NetworkService.connectToWifi(activeConnectionTarget, password, wifiInterface, false);
    }
  }

  needsKeyboardFocus: showSsidInput || showPasswordInput

  Component.onDestruction: resetConnectionState()
  onIsOpenChanged: if (!isOpen)
    resetConnectionState()

  Timer {
    interval: 10000
    repeat: true
    running: root.isOpen

    onTriggered: NetworkService.refreshAll()
  }

  Connections {
    function onConnectionError(ssid, errorMessage): void {
      if (ssid === root.activeConnectionTarget || (root.isHiddenTarget && ssid === root.targetSsid))
        root.connectionError = errorMessage;
    }

    function onWifiApsChanged(): void {
      const aps = root.wifiAps.filter(a => a?.ssid === root.activeConnectionTarget);
      if (root.activeConnectionTarget && root.activeConnectionTarget !== "hidden" && aps.find(a => a?.connected)) {
        root.resetConnectionState();
        root.closeRequested();
      } else if (root.isHiddenTarget && root.targetSsid && NetworkService.wifiOnline) {
        const targetAp = root.wifiAps.find(a => a?.ssid === root.targetSsid);
        if (targetAp?.connected || !root.hiddenConnectStartedOnline) {
          root.resetConnectionState();
          root.closeRequested();
        }
      }
    }

    function onWifiOnlineChanged(): void {
      onWifiApsChanged();
    }

    target: NetworkService
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.bgElevatedAlt
    layer.enabled: true
    radius: 16

    layer.effect: MultiEffect {
      shadowBlur: 0.5
      shadowColor: Qt.rgba(0, 0, 0, 0.18)
      shadowEnabled: true
      shadowVerticalOffset: 4
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

      TogglePill {
        active: root.ready
        checked: root.networkingEnabled
        icon: "󱘖"
        label: "Network"

        onToggled: c => NetworkService.setNetworkingEnabled(c)
      }

      TogglePill {
        active: root.ready && root.networkingEnabled
        checked: root.wifiEnabled
        icon: "󰤨"
        label: "Wi-Fi"

        onToggled: c => NetworkService.setWifiRadioEnabled(c)
      }

      TogglePill {
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
        const conn = root.savedConnections.find(c => c?.ssid === ssid);
        if (conn?.connectionId)
          NetworkService.forgetWifiConnection(conn.connectionId);
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

          // Fixed: Binds directly to the property.
          // Since "viewList" is part of the "processedWifiAps" object,
          // it updates automatically when signals change, but avoids inline mapping costs.
          model: root.processedWifiAps.viewList
          spacing: 2

          ScrollBar.vertical: ScrollBar {
            policy: networkList.contentHeight > networkList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 4
          }
          delegate: NetworkRow {
            required property int index
            required property var modelData

            // Simplified: properties are already inside modelData from the JS logic
            isSaved: modelData._saved
            network: modelData
            width: ListView.view.width

            onClicked: root.connectToNetwork(modelData.ssid)
            onForgetClicked: {
              const conn = root.savedConnections.find(c => c?.ssid === modelData.ssid);
              if (conn?.connectionId)
                NetworkService.forgetWifiConnection(conn.connectionId);
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
    height: Theme.fontSm + 2
    opacity: 0.7
    radius: height / 2
    visible: bv !== ""
    width: bandText.implicitWidth + 6

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
      text: sheet.ssidMode ? qsTr("Hidden Network") : qsTr("Connect to \u201C%1\u201D").arg(sheet.targetName)
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

      IconButton {
        icon: "󰩺"
        tint: Theme.critical
        visible: {
          const ssid = hero.network?.ssid || "";
          return ssid !== "" && root.savedConnections.find(c => c?.ssid === ssid) !== undefined;
        }

        onClicked: hero.forgetClicked(hero.network?.ssid || "")
      }

      IconButton {
        icon: "󱘖"
        tint: Theme.critical

        onClicked: hero.disconnectClicked()
      }
    }
  }
  component HoverButton: Item {
    property bool showTopBorder: false

    signal clicked

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
  component IconButton: Rectangle {
    property string icon: ""
    property color tint: Theme.textActiveColor

    signal clicked

    color: ma.containsMouse ? Qt.rgba(tint.r, tint.g, tint.b, 0.15) : "transparent"
    height: 30
    radius: 8
    width: 30

    Behavior on color {
      ColorAnimation {
        duration: 120
      }
    }

    Text {
      anchors.centerIn: parent
      color: parent.tint
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      opacity: ma.containsMouse ? 1.0 : 0.5
      text: parent.icon
    }

    MouseArea {
      id: ma

      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true

      onClicked: parent.clicked()
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
        height: 6
        opacity: 0.5
        radius: 3
        visible: row.isSaved && !rowMa.containsMouse
        width: 6
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

      IconButton {
        icon: "󰩺"
        tint: Theme.critical
        visible: row.isSaved && rowMa.containsMouse

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

    height: 36

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

    height: 18
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

    ColumnLayout {
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
  component TogglePill: Rectangle {
    id: pill

    property bool active: true
    property bool checked: false
    required property string icon
    required property string label

    signal toggled(bool checked)

    Layout.fillWidth: true
    Layout.preferredHeight: 56
    border.color: pill.checked && pill.active ? Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.3) : "transparent"
    border.width: 1
    color: pill.checked && pill.active ? Theme.activeSubtle : Theme.bgElevated
    opacity: pill.active ? 1.0 : Theme.opacityDisabled
    radius: 12

    Behavior on border.color {
      ColorAnimation {
        duration: 150
      }
    }
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

    MouseArea {
      anchors.fill: parent
      cursorShape: pill.active ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: pill.active

      onClicked: pill.toggled(!pill.checked)
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: 4

      Text {
        Layout.alignment: Qt.AlignHCenter
        color: pill.checked && pill.active ? Theme.activeColor : Theme.textInactiveColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize * 1.3
        text: pill.icon

        Behavior on color {
          ColorAnimation {
            duration: 150
          }
        }
      }

      OText {
        Layout.alignment: Qt.AlignHCenter
        bold: pill.checked
        color: pill.checked && pill.active ? Theme.activeColor : Theme.textInactiveColor
        size: "xs"
        text: pill.label

        Behavior on color {
          ColorAnimation {
            duration: 150
          }
        }
      }
    }
  }
}
