pragma ComponentBehavior: Bound

import QtQuick
import qs.Components
import qs.Services.Core
import qs.Services.Utils

ContextMenu {
  id: root

  // Network state properties
  property bool ready: false
  property string link: "disconnected"
  property var ap: null

  // Password input state
  property string passwordInputSsid: ""  // SSID currently requesting password
  property string passwordInputError: ""  // Error message if password failed

  // Check for successful connection whenever WiFi APs update
  onApChanged: {
    if (root.passwordInputSsid === "" || !ap)
      return;

    // Check if the network we're trying to connect to is now connected
    if (ap.ssid === root.passwordInputSsid && ap.connected) {
      Logger.log("NetworkPanel", `Successfully connected to ${ap.ssid}, closing menu`);
      root.passwordInputSsid = "";
      root.passwordInputError = "";
      root.close();
    }
  }

  Connections {
    target: NetworkService

    function onConnectionError(ssid, errorMessage) {
      if (ssid === root.passwordInputSsid)
        root.passwordInputError = errorMessage;
    }

    function onConnectionStateChanged() {
      if (root.passwordInputSsid === "")
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

  // Fixed actions at the top
  model: [
    {
      itemType: "action",
      icon: "󰒓",
      label: "Toggle Wi-Fi Radio",
      action: "toggle-radio",
      visible: true,
      enabled: root.ready
    }
  ]

  scrollableModel: {
    const networks = [];

    if (NetworkService.wifiRadioEnabled && NetworkService.wifiAps) {
      const saved = NetworkService.savedWifiAps || [];
      const findSaved = ssid => saved.find(conn => conn?.ssid === ssid);

      for (const ap of NetworkService.wifiAps) {
        if (!ap?.ssid)
          continue;

        // If this network is requesting password, show textInput instead
        if (ap.ssid === root.passwordInputSsid) {
          networks.push({
            itemType: "textInput",
            icon: "󰌾"  // Lock icon to show password input
            ,
            label: ""  // No label - using placeholder instead
            ,
            placeholder: qsTr("Password for %1").arg(root.passwordInputSsid),
            echoMode: TextInput.Password,
            hasError: root.passwordInputError !== "",
            errorMessage: root.passwordInputError,
            action: "password-submit-" + root.passwordInputSsid,
            actionButton: {
              text: "",
              icon: "󰌘"
            },
            onTextChanged: () => {
              root.passwordInputError = "";
            },
            visible: true,
            enabled: true
          });
          continue;
        }

        const signal = (typeof ap.signal === "number") ? ap.signal : 0;
        const band = ap.band || "";
        const savedConn = findSaved(ap.ssid);

        networks.push({
          itemType: "action",
          icon: NetworkService.getWifiIcon(band, signal),
          label: ap.ssid,
          action: ap.connected ? `disconnect-${ap.ssid}` : `connect-${ap.ssid}`,
          actionIcon: ap.connected ? "󱘖" : "󰌘",
          forgetIcon: savedConn ? "󰩺" : undefined,
          band: band,
          bandColor: NetworkService.getBandColor(band),
          visible: true,
          enabled: root.ready,
          ssid: ap.ssid,
          signal: signal,
          connected: ap.connected,
          connectionId: savedConn?.connectionId,
          isSaved: !!savedConn
        });
      }
    }
    return networks;
  }

  onTriggered: (action, data) => {
    const saved = NetworkService.savedWifiAps || [];
    const findSaved = ssid => saved.find(conn => conn?.ssid === ssid);

    if (action === "toggle-radio") {
      NetworkService.toggleWifiRadio();
    } else if (action.startsWith("password-submit-")) {
      const ssid = action.substring(16);
      const password = data?.value || "";
      const wifiInterface = NetworkService.wifiInterface;

      if (wifiInterface && ssid && password) {
        root.passwordInputError = "";
        NetworkService.connectToWifi(ssid, password, wifiInterface, false, "");
      }
    } else if (action.startsWith("forget-")) {
      const ssid = action.substring(7);
      const savedConn = findSaved(ssid);
      if (savedConn?.connectionId) {
        NetworkService.forgetWifiConnection(savedConn.connectionId);
      }
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

  // Clear password input when menu closes
  onMenuClosed: {
    root.passwordInputSsid = "";
    root.passwordInputError = "";
  }
}
