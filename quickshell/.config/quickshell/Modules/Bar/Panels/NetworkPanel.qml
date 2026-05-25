pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Core

PanelContentBase {
  id: root

  readonly property var availableNetworks: NetworkService.availableWifiAps
  readonly property var connectedNetwork: NetworkService.connectedWifiAp
  property var connectingNetwork: null
  property string connectionError: ""
  readonly property string ethernetInterface: NetworkService.ethernetInterface
  // SSID whose inline password field is open ("" = none)
  property string expandedSsid: ""
  property bool hiddenConnecting: false
  property bool isHiddenTarget: false
  readonly property bool networkingEnabled: NetworkService.networkingEnabled
  readonly property var pendingAp: (isHiddenTarget && targetSsid !== "") ? accessPointForSsid(targetSsid) : null
  readonly property bool ready: NetworkService.ready
  readonly property var savedNetworks: NetworkService.savedWifiAps
  property bool scanning: false
  readonly property bool showGroups: savedNetworks.some(ap => !ap.connected) && availableNetworks.length > 0
  readonly property bool showPasswordInput: isHiddenTarget && !showSsidInput && !hiddenConnecting && (pendingAp ? securityRequiresPassword(pendingAp.security) : true)
  readonly property bool showSsidInput: isHiddenTarget && targetSsid === ""
  property string targetSsid: ""
  readonly property var viewList: NetworkService.viewWifiAps.map(ap => Object.assign({}, ap, {
      group: ap.saved ? "saved" : "available"
    }))
  readonly property bool wifiEnabled: NetworkService.wifiRadioEnabled
  readonly property string wifiInterface: NetworkService.wifiInterface

  // Look up a flat AP object (for security/UI checks)
  function accessPointForSsid(ssid: string): var {
    const aps = NetworkService.wifiAps ?? [];
    return aps.find(a => a?.ssid === ssid) || null;
  }

  function cancelInline(): void {
    root.expandedSsid = "";
    root.connectingNetwork = null;
    root.connectionError = "";
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
      return;
    }
    root.connectionError = "";
    if (securityRequiresPassword(ap.security)) {
      root.expandedSsid = root.expandedSsid === ssid ? "" : ssid;
    } else {
      root.expandedSsid = "";
      submitConnect(ssid, "");
    }
  }

  function resetConnectionState(): void {
    isHiddenTarget = false;
    targetSsid = "";
    expandedSsid = "";
    connectingNetwork = null;
    hiddenConnecting = false;
    hiddenTimeout.stop();
    if (credentialSheet)
      credentialSheet.clearInputs();
    connectionError = "";
  }

  function securityRequiresPassword(security: string): bool {
    const sec = String(security || "").trim();
    return sec !== "" && sec !== "--";
  }

  // Inline (visible-network) connection
  function submitConnect(ssid: string, password: string): void {
    const net = wifiNetworkForSsid(ssid);
    if (!net)
      return;
    const trimmedPassword = String(password || "").trim();
    root.connectionError = "";
    root.connectingNetwork = net;
    if (trimmedPassword)
      net.connectWithPsk(trimmedPassword);
    else
      net.connect();
  }

  // Hidden-network connection (sheet flow)
  function submitHiddenPassword(password: string): void {
    const trimmedPassword = String(password || "").trim();
    if (!targetSsid || (showPasswordInput && !trimmedPassword))
      return;
    connectionError = "";
    hiddenConnecting = true;
    hiddenTimeout.restart();
    NetworkService.connectHiddenWifi(targetSsid, trimmedPassword);
  }

  // Look up the live WifiNetwork object (for connect/disconnect/forget actions)
  function wifiNetworkForSsid(ssid: string): var {
    return (NetworkService.wifiDevice?.networks.values ?? []).find(n => n.name === ssid) ?? null;
  }

  needsKeyboardFocus: showSsidInput || showPasswordInput || (expandedSsid !== "" && connectingNetwork === null)
  preferredHeight: mainLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: 340

  Component.onDestruction: resetConnectionState()
  // Pause scanning while a password field is open so the model doesn't churn
  // and clobber the field the user is typing into.
  onExpandedSsidChanged: {
    if (!isOpen)
      return;
    if (expandedSsid !== "")
      NetworkService.stopWifiScan();
    else if (wifiEnabled && networkingEnabled)
      NetworkService.startWifiScan();
  }
  onIsOpenChanged: {
    if (!isOpen) {
      resetConnectionState();
      NetworkService.stopWifiScan();
      scanning = false;
      scanGraceTimer.stop();
      return;
    }
    NetworkService.startWifiScan();
    scanning = true;
    scanGraceTimer.restart();
  }

  // Grace window for distinguishing "scanning" from "no networks found"
  // (the backend exposes no active-scan signal).
  Timer {
    id: scanGraceTimer

    interval: 4000

    onTriggered: root.scanning = false
  }

  // Hidden-connect has no failure signal; bail out after a timeout so the
  // sheet doesn't hang forever.
  Timer {
    id: hiddenTimeout

    interval: 20000

    onTriggered: {
      if (root.isHiddenTarget && root.hiddenConnecting) {
        root.connectionError = qsTr("Connection failed");
        root.hiddenConnecting = false;
      }
    }
  }

  // Per-network connection failure / success (inline flow)
  Connections {
    function onConnectedChanged() {
      if (root.connectingNetwork?.connected) {
        root.resetConnectionState();
        root.closeRequested();
      }
    }

    function onConnectionFailed(reason) {
      root.connectionError = NetworkService.connectionFailReasonText(reason);
      root.connectingNetwork = null;
    }

    enabled: root.connectingNetwork !== null
    target: root.connectingNetwork ?? null
  }

  // Hidden network success detection
  Connections {
    function onWifiOnlineChanged() {
      if (root.isHiddenTarget && root.hiddenConnecting && NetworkService.wifiOnline) {
        root.resetConnectionState();
        root.closeRequested();
      }
    }

    target: NetworkService
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

    EthernetHeroCard {
      Layout.bottomMargin: visible ? Theme.spacingMd : 0
      Layout.fillWidth: true
      interfaceName: root.ethernetInterface
      ip: NetworkService.ethernetIpAddress
      speed: NetworkService.ethernetSpeed
      visible: NetworkService.ethernetOnline && root.ethernetInterface !== ""

      onDisconnectClicked: NetworkService.disconnectEthernet()
    }

    HeroCard {
      Layout.bottomMargin: visible ? Theme.spacingMd : 0
      Layout.fillWidth: true
      ip: NetworkService.wifiIpAddress
      network: root.connectedNetwork
      visible: root.connectedNetwork !== null

      onDisconnectClicked: NetworkService.disconnectWifi()
      onForgetClicked: ssid => {
        const net = root.wifiNetworkForSsid(ssid);
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
      targetName: root.targetSsid
      visible: root.isHiddenTarget

      onCancelled: root.resetConnectionState()
      onErrorCleared: root.connectionError = ""
      onPasswordSubmitted: pw => root.submitHiddenPassword(pw)
      onSsidSubmitted: ssid => {
        ssid = ssid.trim();
        if (ssid) {
          root.targetSsid = ssid;
          root.connectionError = "";
          const targetAp = root.accessPointForSsid(ssid);
          if (targetAp && !root.securityRequiresPassword(targetAp?.security))
            root.submitHiddenPassword("");
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      visible: !root.isHiddenTarget && root.wifiEnabled && root.networkingEnabled

      RowLayout {
        Layout.bottomMargin: Theme.spacingXs
        Layout.fillWidth: true
        spacing: Theme.spacingXs

        OText {
          bold: true
          color: Theme.textInactiveColor
          size: "xs"
          text: "NETWORKS"
          visible: root.savedNetworks.length > 0 || root.availableNetworks.length > 0
        }

        Item {
          Layout.fillWidth: true
        }

        Item {
          id: rescanBtn

          Layout.preferredHeight: 22
          Layout.preferredWidth: 22

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
              NetworkService.rescanWifi();
              root.scanning = true;
              scanGraceTimer.restart();
            }

            Text {
              id: rescanGlyph

              anchors.centerIn: parent
              color: Theme.textInactiveColor
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize * 0.9
              opacity: parent.containsMouse || root.scanning ? 1.0 : 0.5
              text: "󰑐"

              RotationAnimation on rotation {
                duration: 1000
                from: 0
                loops: Animation.Infinite
                running: root.scanning
                to: 360
              }
            }
          }
        }
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
          model: root.viewList
          section.criteria: ViewSection.FullString
          section.property: root.showGroups ? "group" : ""
          spacing: 2

          ScrollBar.vertical: ScrollBar {
            policy: networkList.contentHeight > networkList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 4
          }
          delegate: NetworkRow {
            required property var modelData

            connecting: root.connectingNetwork !== null && root.connectingNetwork.name === modelData.ssid
            errorMessage: root.expandedSsid === modelData.ssid ? root.connectionError : ""
            expanded: root.expandedSsid === modelData.ssid
            isSaved: modelData.saved
            network: modelData
            width: ListView.view.width

            onCancelExpand: root.cancelInline()
            onClicked: root.connectToNetwork(modelData.ssid)
            onForgetClicked: {
              const net = root.wifiNetworkForSsid(modelData.ssid);
              net?.forget();
            }
            onPasswordEdited: root.connectionError = ""
            onPasswordSubmitted: pw => root.submitConnect(modelData.ssid, pw)
          }
          section.delegate: Item {
            id: sectionRoot

            required property string section

            implicitHeight: sectionLabel.implicitHeight + Theme.spacingXs
            width: ListView.view.width

            OText {
              id: sectionLabel

              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.leftMargin: Theme.spacingSm
              bold: true
              color: Theme.textInactiveColor
              opacity: 0.7
              size: "xs"
              text: sectionRoot.section === "saved" ? qsTr("Saved") : qsTr("Available")
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

        onClicked: {
          root.isHiddenTarget = true;
          root.targetSsid = "";
          root.expandedSsid = "";
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
      text: root.scanning ? qsTr("Scanning…") : qsTr("No networks found")
      visible: !root.isHiddenTarget && root.wifiEnabled && root.networkingEnabled && root.savedNetworks.length === 0 && root.availableNetworks.length === 0
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
      text: sheet.ssidMode ? qsTr("Hidden Network") : sheet.waitingMode ? qsTr("Connecting to “%1”").arg(sheet.targetName) : qsTr("Connect to “%1”").arg(sheet.targetName)
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
      spacing: Theme.spacingSm
      visible: sheet.waitingMode

      Text {
        color: Theme.activeColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: "󰇙"

        RotationAnimation on rotation {
          duration: 1000
          from: 0
          loops: Animation.Infinite
          running: sheet.waitingMode
          to: 360
        }
      }

      OText {
        color: Theme.textInactiveColor
        size: "xs"
        text: qsTr("Connecting…")
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
        isEnabled: ssidField.text.trim() !== ""
        text: qsTr("Next")
        variant: "primary"
        visible: sheet.ssidMode

        onClicked: sheet.ssidSubmitted(ssidField.text)
      }

      OButton {
        icon: sheet.errorMessage !== "" ? "󰀦" : ""
        isEnabled: pwField.text.trim() !== ""
        text: sheet.errorMessage !== "" ? qsTr("Retry") : qsTr("Connect")
        variant: "primary"
        visible: sheet.passwordMode

        onClicked: sheet.passwordSubmitted(pwField.text)
      }
    }
  }
  component EthernetHeroCard: Rectangle {
    id: ethHero

    property string interfaceName: ""
    property string ip: ""
    property int speed: 0
    readonly property string speedText: speed >= 1000 ? (speed / 1000) + " Gb/s" : speed + " Mb/s"

    signal disconnectClicked

    border.color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.25)
    border.width: 1
    color: Theme.activeSubtle
    implicitHeight: visible ? ethContent.implicitHeight + Theme.spacingSm * 2 : 0
    radius: 14

    Behavior on implicitHeight {
      NumberAnimation {
        duration: 200
        easing.type: Easing.OutCubic
      }
    }

    RowLayout {
      id: ethContent

      anchors.fill: parent
      anchors.leftMargin: Theme.spacingMd
      anchors.margins: Theme.spacingSm
      spacing: Theme.spacingSm

      Text {
        color: Theme.activeColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize * 1.2
        text: "󰈀"
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        OText {
          Layout.fillWidth: true
          bold: true
          color: Theme.activeColor
          elide: Text.ElideRight
          text: ethHero.interfaceName || qsTr("Ethernet")
        }

        OText {
          color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.7)
          size: "xs"
          text: ethHero.speed > 0 ? ethHero.speedText : qsTr("Connected")
        }

        OText {
          Layout.fillWidth: true
          color: Theme.textInactiveColor
          elide: Text.ElideRight
          size: "xs"
          text: ethHero.ip
          visible: ethHero.ip !== ""
        }
      }

      PanelActionIcon {
        icon: "󱘖"
        tint: Theme.critical

        onClicked: ethHero.disconnectClicked()
      }
    }
  }
  component HeroCard: Rectangle {
    id: hero

    property string ip: ""
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
          Layout.fillWidth: true
          bold: true
          color: Theme.activeColor
          elide: Text.ElideRight
          text: hero.network?.ssid || ""
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Theme.spacingXs

          OText {
            color: Qt.rgba(Theme.activeColor.r, Theme.activeColor.g, Theme.activeColor.b, 0.7)
            size: "xs"
            text: qsTr("Connected")
          }

          BandBadge {
            band: hero.network?.band || ""
          }

          Item {
            Layout.fillWidth: true
          }
        }

        OText {
          Layout.fillWidth: true
          color: Theme.textInactiveColor
          elide: Text.ElideRight
          size: "xs"
          text: hero.ip
          visible: hero.ip !== ""
        }
      }

      Item {
        Layout.fillWidth: true
      }

      PanelActionIcon {
        icon: "󰩺"
        tint: Theme.critical
        visible: hero.network?.saved === true && (hero.network?.ssid || "") !== ""

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
      visible: hbtn.showTopBorder
    }

    MouseArea {
      id: hma

      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true

      onClicked: parent.clicked()

      Rectangle {
        anchors.fill: parent
        anchors.topMargin: hbtn.showTopBorder ? 1 : 0
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

    property bool connecting: false
    property string errorMessage: ""
    property bool expanded: false
    property bool isSaved: false
    property var network: null
    readonly property bool secured: {
      const sec = network?.security || "";
      return sec !== "" && sec !== "--";
    }

    signal cancelExpand
    signal clicked
    signal forgetClicked
    signal passwordEdited
    signal passwordSubmitted(string pw)

    color: "transparent"
    height: rowCol.implicitHeight
    radius: 10

    Behavior on height {
      NumberAnimation {
        duration: 150
        easing.type: Easing.OutCubic
      }
    }

    ColumnLayout {
      id: rowCol

      spacing: 0
      width: parent.width

      Rectangle {
        id: rowHeader

        Layout.fillWidth: true
        Layout.preferredHeight: Theme.itemHeight
        color: rowMa.containsMouse && !row.connecting ? Qt.rgba(Theme.textActiveColor.r, Theme.textActiveColor.g, Theme.textActiveColor.b, 0.06) : "transparent"
        radius: 10

        Behavior on color {
          ColorAnimation {
            duration: 120
          }
        }

        MouseArea {
          id: rowMa

          anchors.fill: parent
          cursorShape: row.connecting ? Qt.ArrowCursor : Qt.PointingHandCursor
          hoverEnabled: true

          onClicked: if (!row.connecting)
            row.clicked()
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
            visible: row.isSaved && !rowMa.containsMouse && !row.connecting && !row.expanded
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
            visible: row.secured && !row.connecting
          }

          Text {
            color: Theme.activeColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: "󰇙"
            visible: row.connecting

            RotationAnimation on rotation {
              duration: 1000
              from: 0
              loops: Animation.Infinite
              running: row.connecting
              to: 360
            }
          }

          PanelActionIcon {
            id: forgetBtn

            icon: "󰩺"
            tint: Theme.critical
            visible: row.isSaved && !row.connecting && (rowMa.containsMouse || forgetBtn.hovered)

            onClicked: row.forgetClicked()
          }
        }
      }

      // Inline password expander
      ColumnLayout {
        Layout.bottomMargin: row.expanded ? Theme.spacingSm : 0
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacingSm
        Layout.rightMargin: Theme.spacingSm
        Layout.topMargin: row.expanded ? Theme.spacingXs : 0
        spacing: Theme.spacingXs
        visible: row.expanded

        SheetField {
          id: rowPwField

          Layout.fillWidth: true
          hasError: row.errorMessage !== ""
          isPassword: true
          placeholder: qsTr("Password")
          visible: row.expanded && !row.connecting

          onAccepted: val => row.passwordSubmitted(val)
          onCancelled: row.cancelExpand()
          onTextEdited: row.passwordEdited()
        }

        OText {
          color: Theme.critical
          size: "xs"
          text: "⚠ " + row.errorMessage
          visible: row.errorMessage !== "" && !row.connecting
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Theme.spacingSm

          Text {
            color: Theme.activeColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            text: "󰇙"
            visible: row.connecting

            RotationAnimation on rotation {
              duration: 1000
              from: 0
              loops: Animation.Infinite
              running: row.connecting
              to: 360
            }
          }

          OText {
            color: Theme.textInactiveColor
            size: "xs"
            text: qsTr("Connecting…")
            visible: row.connecting
          }

          Item {
            Layout.fillWidth: true
          }

          OButton {
            size: "sm"
            text: qsTr("Cancel")
            variant: "ghost"

            onClicked: row.cancelExpand()
          }

          OButton {
            icon: row.errorMessage !== "" ? "󰀦" : ""
            isEnabled: rowPwField.text.trim() !== ""
            size: "sm"
            text: row.errorMessage !== "" ? qsTr("Retry") : qsTr("Connect")
            variant: "primary"
            visible: !row.connecting

            onClicked: row.passwordSubmitted(rowPwField.text)
          }
        }
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
    id: stateMessage

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
        text: stateMessage.icon
      }

      OText {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.textInactiveColor
        text: stateMessage.text
      }
    }
  }
}
