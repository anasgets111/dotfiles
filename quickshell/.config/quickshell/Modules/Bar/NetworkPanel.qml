pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Components
import qs.Services.Core

OPanel {
  id: root

  readonly property int itemHeight: Theme.itemHeight
  readonly property int maxItems: 7
  readonly property bool networkingEnabled: NetworkService.networkingEnabled
  readonly property int padding: 8
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

  function findSavedConn(ssid) {
    return savedConnections.find(c => c?.ssid === ssid);
  }

  function handleAction(action: string, data: var) {
    const wifiIface = NetworkService.wifiInterface;

    if (action.startsWith("submit-")) {
      const ssid = action.substring(7);
      const password = (data && "value" in data) ? String(data.value).trim() : "";
      if (wifiIface && ssid && password) {
        passwordError = "";
        NetworkService.connectToWifi(ssid, password, wifiIface, false, "");
      }
      return;
    }

    if (action.startsWith("forget-")) {
      const ssid = action.substring(7);
      const connId = findSavedConn(ssid)?.connectionId;
      if (connId)
        NetworkService.forgetWifiConnection(connId);
      return;
    }

    if (action === "cancel") {
      resetPasswordState();
      return;
    }

    if (action.startsWith("disconnect-")) {
      if (wifiIface)
        NetworkService.disconnectInterface(wifiIface);
      return;
    }

    if (action.startsWith("connect-")) {
      const ssid = action.substring(8);
      const ap = wifiAps.find(a => a?.ssid === ssid);
      if (!ap || ap.connected)
        return;

      const saved = findSavedConn(ssid);
      if (saved?.connectionId) {
        NetworkService.activateConnection(saved.connectionId, wifiIface);
        root.close();
      } else {
        passwordSsid = ssid;
        passwordError = "";
      }
    }
  }

  function resetPasswordState() {
    passwordSsid = "";
    passwordError = "";
  }

  function syncToggles() {
    networkToggle.checked = NetworkService.networkingEnabled;
    wifiToggle.checked = NetworkService.wifiRadioEnabled;
  }

  needsKeyboardFocus: passwordSsid !== ""
  panelNamespace: "obelisk-network-panel"
  panelWidth: passwordSsid ? 350 : 350

  Component.onCompleted: syncToggles()
  onClosed: resetPasswordState()

  Connections {
    function onConnectionError(ssid, errorMessage) {
      if (ssid === root.passwordSsid)
        root.passwordError = errorMessage;
    }

    function onConnectionStateChanged() {
      const ap = root.wifiAps.find(a => a?.ssid === root.passwordSsid && a.connected);
      if (ap) {
        root.resetPasswordState();
        root.close();
      }
    }

    function onNetworkingEnabledChanged() {
      root.syncToggles();
    }

    function onWifiRadioStateChanged() {
      root.syncToggles();
    }

    target: NetworkService
  }

  ColumnLayout {
    spacing: 4
    width: parent.width - root.padding * 2
    x: root.padding
    y: root.padding

    // Toggle Cards Row
    RowLayout {
      Layout.fillWidth: true
      spacing: root.padding * 1.25

      // Networking Toggle Card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: networkCol.implicitHeight + root.padding * 1.2
        border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
        border.width: 1
        color: Qt.lighter(Theme.bgColor, 1.35)
        opacity: root.ready ? 1 : 0.5
        radius: Theme.itemRadius

        Behavior on opacity {
          NumberAnimation {
            duration: 150
          }
        }

        ColumnLayout {
          id: networkCol

          anchors.fill: parent
          anchors.margins: root.padding * 0.9
          spacing: root.padding * 0.4

          OText {
            color: root.ready ? Theme.textActiveColor : Theme.textInactiveColor
            font.bold: true
            text: qsTr("Networking")
          }

          RowLayout {
            spacing: root.padding * 0.9

            Rectangle {
              border.color: Qt.rgba(0, 0, 0, 0.12)
              border.width: 1
              color: root.ready ? Qt.lighter(Theme.activeColor, 1.25) : Theme.inactiveColor
              implicitHeight: implicitWidth
              implicitWidth: Theme.itemHeight * 0.9
              radius: height / 2

              Behavior on color {
                ColorAnimation {
                  duration: 150
                }
              }

              Text {
                anchors.centerIn: parent
                color: root.ready ? Theme.textContrast(parent.color) : Theme.textInactiveColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.95
                text: "󰤨"
              }
            }

            Item {
              Layout.fillWidth: true
            }

            OToggle {
              id: networkToggle

              Layout.preferredHeight: Theme.itemHeight * 0.72
              Layout.preferredWidth: Theme.itemHeight * 2.6
              disabled: !root.ready

              onToggled: checked => NetworkService.setNetworkingEnabled(checked)
            }
          }
        }
      }

      // Wi-Fi Toggle Card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: wifiCol.implicitHeight + root.padding * 1.2
        border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
        border.width: 1
        color: Qt.lighter(Theme.bgColor, 1.35)
        opacity: root.ready && root.networkingEnabled ? 1 : 0.5
        radius: Theme.itemRadius

        Behavior on opacity {
          NumberAnimation {
            duration: 150
          }
        }

        ColumnLayout {
          id: wifiCol

          anchors.fill: parent
          anchors.margins: root.padding * 0.9
          spacing: root.padding * 0.4

          OText {
            color: root.ready && root.networkingEnabled ? Theme.textActiveColor : Theme.textInactiveColor
            font.bold: true
            text: qsTr("Wi-Fi")
          }

          RowLayout {
            spacing: root.padding * 0.9

            Rectangle {
              border.color: Qt.rgba(0, 0, 0, 0.12)
              border.width: 1
              color: root.ready && root.networkingEnabled ? Qt.lighter(Theme.onHoverColor, 1.25) : Qt.darker(Theme.inactiveColor, 1.1)
              implicitHeight: implicitWidth
              implicitWidth: Theme.itemHeight * 0.9
              radius: height / 2

              Behavior on color {
                ColorAnimation {
                  duration: 150
                }
              }

              Text {
                anchors.centerIn: parent
                color: root.ready && root.networkingEnabled ? Theme.textContrast(parent.color) : Theme.textInactiveColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.95
                text: "󰒓"
              }
            }

            Item {
              Layout.fillWidth: true
            }

            OToggle {
              id: wifiToggle

              Layout.preferredHeight: Theme.itemHeight * 0.72
              Layout.preferredWidth: Theme.itemHeight * 2.6
              disabled: !root.ready || !root.networkingEnabled

              onToggled: checked => NetworkService.setWifiRadioEnabled(checked)
            }
          }
        }
      }
    }

    // Network List
    Rectangle {
      Layout.bottomMargin: root.padding * 2
      Layout.fillWidth: true
      Layout.topMargin: root.padding
      border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
      border.width: 1
      clip: true
      color: Qt.lighter(Theme.bgColor, 1.25)
      implicitHeight: visible ? networkList.implicitHeight + root.padding * 1.4 : 0
      radius: Theme.itemRadius
      visible: root.ready && root.networkingEnabled && root.wifiEnabled && networkList.count > 0

      ListView {
        id: networkList

        anchors.fill: parent
        anchors.margins: root.padding * 0.8
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        implicitHeight: Math.min(contentHeight, root.maxItems * root.itemHeight + (root.maxItems - 1) * 4)
        interactive: contentHeight > height
        model: root.buildNetworkList()
        spacing: 4

        ScrollBar.vertical: ScrollBar {
          policy: networkList.contentHeight > networkList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
          width: 8
        }
        delegate: NetworkItem {
          id: delegateItem

          width: ListView.view.width

          onPasswordCleared: root.passwordError = ""
          onTriggered: (action, data) => {
            root.handleAction(action, data);
            if (!action.startsWith("connect-") || delegateItem.modelData.connected || delegateItem.modelData.isSaved) {
              root.close();
            }
          }
        }
      }
    }
  }

  component NetworkItem: Item {
    id: networkItem

    property bool hovered: false
    readonly property bool isInput: networkItem.modelData.type === "input"
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
        spacing: 8

        Item {
          Layout.leftMargin: root.padding
          Layout.preferredHeight: Theme.itemHeight
          Layout.preferredWidth: Theme.fontSize * 1.5

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
            anchors.leftMargin: -2
            color: networkItem.modelData.bandColor || networkItem.textColor
            font.bold: true
            font.family: "Roboto Condensed"
            font.pixelSize: Theme.fontSize * 0.5
            text: networkItem.modelData.band === "2.4" ? "2.4" : networkItem.modelData.band
            visible: networkItem.modelData.band !== ""

            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          color: networkItem.textColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
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
          Layout.rightMargin: 4
          colorBg: "#F38BA8"
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
        spacing: 8

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
          spacing: 4

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

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
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                color: Theme.textActiveColor
                echoMode: TextInput.Password
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                placeholderText: networkItem.modelData.placeholder || ""
                selectedTextColor: Theme.textContrast(Theme.activeColor)
                selectionColor: Theme.activeColor

                background: Rectangle {
                  color: "transparent"
                }

                Component.onCompleted: Qt.callLater(() => passwordField.forceActiveFocus())
                Keys.onPressed: event => {
                  if (event.key === Qt.Key_Escape) {
                    event.accepted = true;
                    networkItem.triggered("cancel", {});
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

              onClicked: networkItem.triggered("cancel", {})
            }

            IconButton {
              Layout.preferredHeight: Theme.itemHeight * 0.8
              Layout.preferredWidth: Theme.itemHeight * 0.8
              colorBg: networkItem.modelData.hasError ? "#F38BA8" : Theme.activeColor
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

          Text {
            Layout.fillWidth: true
            color: "#F38BA8"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize * 0.85
            opacity: visible ? 1 : 0
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
}
