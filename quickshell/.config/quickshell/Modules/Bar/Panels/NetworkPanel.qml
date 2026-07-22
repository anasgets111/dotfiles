pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.Config
import qs.Services.Core

PanelContentBase {
  id: root

  readonly property var availableNetworks: NetworkService.availableWifiAps
  readonly property string connectError: root.errorDismissed ? "" : NetworkService.connectError
  readonly property var connectedNetwork: NetworkService.connectedWifiAp
  readonly property string connectingSsid: NetworkService.connectingSsid
  property bool errorDismissed: false
  readonly property string ethernetInterface: NetworkService.ethernetInterface
  property string expandedSsid: ""
  property bool isHiddenTarget: false
  readonly property bool networkingEnabled: NetworkService.networkingEnabled
  readonly property bool ready: NetworkService.ready
  readonly property var savedNetworks: NetworkService.savedWifiAps
  property bool scanning: false
  readonly property bool showPasswordInput: isHiddenTarget && !showSsidInput && connectingSsid !== targetSsid && (networkForSsid(targetSsid)?.secured ?? true)
  readonly property bool showSsidInput: isHiddenTarget && targetSsid === ""
  readonly property string statusDetail: {
    if (!root.ready)
      return qsTr("Unavailable");
    if (!root.networkingEnabled)
      return qsTr("Off");
    if (NetworkService.linkType === "ethernet") {
      return [root.ethernetInterface || qsTr("Ethernet"), NetworkService.ethernetIpAddress, root.formatEthernetSpeed(NetworkService.ethernetSpeed)].filter(Boolean).join(" · ");
    }
    if (root.connectedNetwork) {
      return [root.connectedNetwork.ssid, NetworkService.wifiIpAddress, root.formatBandLabel(root.connectedNetwork.band), `${root.connectedNetwork.signal}%`].filter(Boolean).join(" · ");
    }
    return qsTr("Not connected");
  }
  property string targetSsid: ""
  readonly property var viewList: (root.connectedNetwork ? [root.connectedNetwork] : []).concat(NetworkService.viewWifiAps).map(ap => Object.assign({}, ap, {
      group: ap.saved ? "saved" : "available"
    }))
  readonly property bool wifiEnabled: NetworkService.wifiRadioEnabled

  function cancelInline(): void {
    root.expandedSsid = "";
    NetworkService.cancelConnect();
  }
  function connectToNetwork(ssid: string): void {
    const ap = networkForSsid(ssid);
    if (!ap || ap.connected)
      return;
    root.errorDismissed = false;
    if (ap.saved || !ap.secured) {
      root.expandedSsid = "";
      NetworkService.connectToSsid(ssid, "");
    } else {
      root.expandedSsid = root.expandedSsid === ssid ? "" : ssid;
    }
  }
  function formatBandLabel(band: string): string {
    return band ? `${band}G` : "";
  }
  function formatEthernetSpeed(mbps: real): string {
    if (mbps <= 0)
      return "";
    return mbps >= 1000 ? `${mbps / 1000} Gb/s` : `${mbps} Mb/s`;
  }
  function networkForSsid(ssid: string): var {
    const aps = NetworkService.wifiAps ?? [];
    return aps.find(a => a?.ssid === ssid) || null;
  }
  function resetConnectionState(): void {
    isHiddenTarget = false;
    targetSsid = "";
    expandedSsid = "";
    errorDismissed = false;
    NetworkService.cancelConnect();
    if (credentialSheet)
      credentialSheet.clearInputs();
  }
  function submitHiddenPassword(password: string): void {
    if (!targetSsid || (showPasswordInput && String(password || "").trim() === ""))
      return;
    root.errorDismissed = false;
    NetworkService.connectToSsid(targetSsid, password);
  }

  flatContainer: true
  needsKeyboardFocus: showSsidInput || showPasswordInput || (expandedSsid !== "" && connectingSsid === "")
  preferredHeight: mainLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: Theme.networkPanelWidth

  Component.onDestruction: resetConnectionState()
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

  Timer {
    id: scanGraceTimer

    interval: 4000

    onTriggered: root.scanning = false
  }
  Connections {
    function onConnectFailed(ssid) {
      root.errorDismissed = false;
      if (root.networkForSsid(ssid)?.secured)
        root.expandedSsid = ssid;
    }
    function onConnectSucceeded() {
      root.resetConnectionState();
      root.closeRequested();
    }

    target: NetworkService
  }
  ColumnLayout {
    id: mainLayout

    anchors.fill: parent
    anchors.margins: Theme.spacingMd
    spacing: 0

    PanelToggleCard {
      Layout.bottomMargin: root.networkingEnabled ? Theme.spacingXs : Theme.spacingMd
      active: root.ready
      checked: root.networkingEnabled
      detail: root.statusDetail
      icon: NetworkService.linkType === "wifi" ? "󰤨" : NetworkService.linkType === "ethernet" ? "󰈀" : "󱘖"
      label: qsTr("Network")

      onToggled: c => NetworkService.setNetworkingEnabled(c)
    }
    RowLayout {
      Layout.bottomMargin: Theme.spacingMd
      Layout.fillWidth: true
      spacing: Theme.spacingXs
      visible: root.networkingEnabled

      PanelToggleCard {
        active: root.ready
        checked: root.wifiEnabled
        detail: root.connectedNetwork ? [NetworkService.wifiIpAddress, root.formatBandLabel(root.connectedNetwork.band)].filter(Boolean).join(" · ") : ""
        icon: "󰤨"
        label: qsTr("Wi-Fi")

        onToggled: c => NetworkService.setWifiRadioEnabled(c)
      }
      PanelToggleCard {
        active: root.ready && root.ethernetInterface !== ""
        checked: NetworkService.ethernetOnline
        detail: NetworkService.ethernetOnline ? [NetworkService.ethernetIpAddress, root.formatEthernetSpeed(NetworkService.ethernetSpeed)].filter(Boolean).join(" · ") : ""
        icon: "󰈀"
        label: root.ethernetInterface !== "" ? qsTr("Ethernet") : qsTr("No Ethernet")

        onToggled: c => c ? NetworkService.connectEthernet() : NetworkService.disconnectEthernet()
      }
    }
    CredentialSheet {
      id: credentialSheet

      Layout.bottomMargin: visible ? Theme.spacingMd : 0
      Layout.fillWidth: true
      errorMessage: root.connectError
      passwordMode: root.showPasswordInput
      ssidMode: root.showSsidInput
      targetName: root.targetSsid
      visible: root.isHiddenTarget

      onCancelled: root.resetConnectionState()
      onErrorCleared: root.errorDismissed = true
      onPasswordSubmitted: pw => root.submitHiddenPassword(pw)
      onSsidSubmitted: ssid => {
        ssid = ssid.trim();
        if (ssid) {
          root.targetSsid = ssid;
          root.errorDismissed = false;
          const targetAp = root.networkForSsid(ssid);
          if (targetAp && !targetAp.secured)
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
          text: qsTr("Networks").toUpperCase()
          visible: root.savedNetworks.length > 0 || root.availableNetworks.length > 0
        }
        Item {
          Layout.fillWidth: true
        }
        Item {
          id: rescanBtn

          Layout.preferredHeight: Theme.controlHeightXs
          Layout.preferredWidth: Theme.controlHeightXs

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
              NetworkService.rescanWifi();
              root.scanning = true;
              scanGraceTimer.restart();
            }

            OText {
              anchors.centerIn: parent
              color: Theme.textInactiveColor
              opacity: parent.containsMouse || root.scanning ? 1.0 : 0.5
              text: "󰑐"
              visible: !root.scanning
            }
            OSpinner {
              anchors.centerIn: parent
              color: Theme.textInactiveColor
              running: root.scanning
              spinnerSize: Theme.iconSizeMd
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
          section.property: "group"
          spacing: Theme.borderWidthMedium

          ScrollBar.vertical: ScrollBar {
            policy: networkList.contentHeight > networkList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: Theme.spacingXs
          }
          delegate: NetworkRow {
            required property var modelData

            blockedByOtherConnection: root.connectingSsid !== "" && root.connectingSsid !== modelData.ssid
            connecting: root.connectingSsid !== "" && root.connectingSsid === modelData.ssid
            errorMessage: root.expandedSsid === modelData.ssid ? root.connectError : ""
            expanded: root.expandedSsid === modelData.ssid
            network: modelData
            width: ListView.view.width

            onCancelExpand: root.cancelInline()
            onClicked: root.connectToNetwork(modelData.ssid)
            onDisconnectClicked: NetworkService.disconnectWifi()
            onForgetClicked: NetworkService.forgetWifi(modelData.ssid)
            onPasswordEdited: root.errorDismissed = true
            onPasswordSubmitted: pw => NetworkService.connectToSsid(modelData.ssid, pw)
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
              opacity: Theme.opacityMuted
              size: "xs"
              text: sectionRoot.section === "saved" ? qsTr("Saved") : qsTr("Available")
            }
          }
        }
      }
      PanelRow {
        Layout.bottomMargin: Theme.spacingSm
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacingXs
        icon: "󰖪"
        title: qsTr("Hidden Network…")

        actions: [
          OText {
            color: Theme.textInactiveColor
            text: "󰁔"
          }
        ]

        onClicked: {
          root.isHiddenTarget = true;
          root.targetSsid = "";
          root.expandedSsid = "";
          if (credentialSheet)
            credentialSheet.clearInputs();
          NetworkService.cancelConnect();
        }
      }
    }
    PanelEmptyState {
      Layout.fillHeight: true
      Layout.fillWidth: true
      Layout.minimumHeight: 120
      icon: "󰤭"
      text: root.scanning ? qsTr("Scanning…") : qsTr("No networks found")
      visible: !root.isHiddenTarget && root.wifiEnabled && root.networkingEnabled && root.savedNetworks.length === 0 && root.availableNetworks.length === 0
    }
    PanelEmptyState {
      Layout.fillHeight: true
      Layout.fillWidth: true
      Layout.minimumHeight: 120
      icon: root.networkingEnabled ? "󰤮" : "󱘖"
      text: !root.networkingEnabled ? qsTr("Networking disabled") : qsTr("Wi-Fi off")
      visible: !root.networkingEnabled || !root.wifiEnabled
    }
  }

  component CredentialForm: ColumnLayout {
    id: form

    property string buttonSize: "md"
    property bool connecting: false
    property string errorMessage: ""

    signal cancelled
    signal edited
    signal submitted(string password)

    function clear(): void {
      pwField.text = "";
    }

    spacing: Theme.spacingXs

    SheetField {
      id: pwField

      Layout.fillWidth: true
      echoMode: TextInput.Password
      hasError: form.errorMessage !== ""
      placeholderText: qsTr("Password")
      visible: !form.connecting

      onCancelled: form.cancelled()
      onInputAccepted: if (text !== "")
        form.submitted(text)
      onInputChanged: form.edited()
    }
    OText {
      color: Theme.critical
      size: "xs"
      text: "⚠ " + form.errorMessage
      visible: form.errorMessage !== "" && !form.connecting
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingSm

      OSpinner {
        Layout.alignment: Qt.AlignVCenter
        running: form.connecting
        spinnerSize: Theme.iconSizeMd
      }
      OText {
        color: Theme.textInactiveColor
        size: "xs"
        text: qsTr("Connecting…")
        visible: form.connecting
      }
      Item {
        Layout.fillWidth: true
      }
      OButton {
        size: form.buttonSize
        text: qsTr("Cancel")
        variant: "ghost"

        onClicked: form.cancelled()
      }
      OButton {
        icon: form.errorMessage !== "" ? "󰀦" : ""
        isEnabled: pwField.text.trim() !== ""
        size: form.buttonSize
        text: form.errorMessage !== "" ? qsTr("Retry") : qsTr("Connect")
        visible: !form.connecting

        onClicked: form.submitted(pwField.text)
      }
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
      credForm.clear();
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
      placeholderText: qsTr("Network name")
      visible: sheet.ssidMode

      onCancelled: sheet.cancelled()
      onInputAccepted: if (text !== "")
        sheet.ssidSubmitted(text)
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingSm
      visible: sheet.ssidMode

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

        onClicked: sheet.ssidSubmitted(ssidField.text)
      }
    }
    CredentialForm {
      id: credForm

      Layout.fillWidth: true
      connecting: sheet.waitingMode
      errorMessage: sheet.errorMessage
      visible: !sheet.ssidMode

      onCancelled: sheet.cancelled()
      onEdited: sheet.errorCleared()
      onSubmitted: pw => sheet.passwordSubmitted(pw)
    }
  }
  component NetworkRow: PanelRow {
    id: row

    readonly property string bandValue: String(network?.band ?? "").trim()
    property bool blockedByOtherConnection: false
    property bool connecting: false
    property string errorMessage: ""
    property var network: null

    signal cancelExpand
    signal disconnectClicked
    signal forgetClicked
    signal passwordEdited
    signal passwordSubmitted(string pw)

    busy: connecting
    enabled: !blockedByOtherConnection
    rowActionEnabled: !row.network?.connected
    selected: row.network?.connected === true
    title: row.network?.ssid || ""

    actions: [
      PanelActionIcon {
        icon: "󱘖"
        tint: Theme.critical
        tooltipText: qsTr("Disconnect")
        visible: row.network?.connected === true

        onClicked: row.disconnectClicked()
      },
      PanelActionIcon {
        icon: "󰩺"
        tint: Theme.critical
        tooltipText: qsTr("Forget")
        visible: row.network?.saved === true

        onClicked: row.forgetClicked()
      }
    ]
    badges: [
      OText {
        color: Theme.textInactiveColor
        size: "xs"
        text: "󰌾"
        visible: row.network?.secured === true
      }
    ]
    expandedContent: [
      CredentialForm {
        buttonSize: "sm"
        connecting: row.connecting
        errorMessage: row.errorMessage
        visible: row.expanded
        width: parent?.width ?? 0

        onCancelled: row.cancelExpand()
        onEdited: row.passwordEdited()
        onSubmitted: pw => row.passwordSubmitted(pw)
      }
    ]
    leading: [
      Item {
        implicitHeight: Math.max(signalIcon.implicitHeight, bandLabel.implicitHeight)
        implicitWidth: Theme.controlHeightLg

        OText {
          id: signalIcon

          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          color: row.bandValue !== "" ? Theme.networkBandColor(row.bandValue) : row.selected ? Theme.activeColor : Theme.textActiveColor
          font.family: Theme.iconFontFamily
          font.pixelSize: Theme.iconSizeMd
          text: NetworkService.getWifiIcon(row.network?.signal || 0)
        }
        OText {
          id: bandLabel

          anchors.bottom: signalIcon.bottom
          anchors.left: signalIcon.right
          anchors.leftMargin: row.bandValue === "2.4" ? -Theme.spacingXs : -Theme.spacingXs / 2
          bold: true
          color: Theme.networkBandColor(row.bandValue)
          font.family: "Roboto Condensed"
          font.letterSpacing: row.bandValue === "2.4" ? -1.5 : -1
          size: "xs"
          text: row.bandValue === "2.4" ? "2.4" : row.bandValue + "G"
          visible: row.bandValue !== ""
        }
      }
    ]
  }
  component SheetField: OInput {
    id: sf

    signal cancelled

    autoFocus: visible

    onKeyPressed: event => {
      if (event.key === Qt.Key_Escape) {
        event.accepted = true;
        sf.cancelled();
      }
    }
    onVisibleChanged: if (visible)
      Qt.callLater(() => sf.forceActiveFocus())
  }
}
