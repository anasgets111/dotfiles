pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Components
import qs.Services.Core
import qs.Services.Utils

OPanel {
  id: root

  readonly property bool ready: NetworkService.ready
  readonly property bool networkingEnabled: NetworkService.networkingEnabled
  readonly property bool wifiEnabled: NetworkService.wifiRadioEnabled
  readonly property var wifiAps: NetworkService.wifiAps || []
  readonly property var savedConnections: NetworkService.savedWifiAps || []

  property string passwordSsid: ""
  property string passwordError: ""

  readonly property int maxItems: 7
  readonly property int itemHeight: Theme.itemHeight
  readonly property int padding: 8

  panelWidth: passwordSsid ? 350 : 350
  needsKeyboardFocus: passwordSsid !== ""

  onClosed: resetPasswordState()

  Connections {
    target: NetworkService

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

    function onWifiRadioStateChanged() {
      root.syncToggles();
    }
    function onNetworkingEnabledChanged() {
      root.syncToggles();
    }
  }

  Component.onCompleted: syncToggles()

  function syncToggles() {
    networkToggle.checked = NetworkService.networkingEnabled;
    wifiToggle.checked = NetworkService.wifiRadioEnabled;
  }

  function resetPasswordState() {
    passwordSsid = "";
    passwordError = "";
  }

  function findSavedConn(ssid) {
    return savedConnections.find(c => c?.ssid === ssid);
  }

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

  ColumnLayout {
    width: parent.width - root.padding * 2
    x: root.padding
    y: root.padding
    spacing: 4

    // Toggle Cards Row
    RowLayout {
      Layout.fillWidth: true
      spacing: root.padding * 1.25

      // Networking Toggle Card
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: networkCol.implicitHeight + root.padding * 1.2
        radius: Theme.itemRadius
        color: Qt.lighter(Theme.bgColor, 1.35)
        border.width: 1
        border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
        opacity: root.ready ? 1 : 0.5

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
            text: qsTr("Networking")
            font.bold: true
            color: root.ready ? Theme.textActiveColor : Theme.textInactiveColor
          }

          RowLayout {
            spacing: root.padding * 0.9

            Rectangle {
              implicitWidth: Theme.itemHeight * 0.9
              implicitHeight: implicitWidth
              radius: height / 2
              color: root.ready ? Qt.lighter(Theme.activeColor, 1.25) : Theme.inactiveColor
              border.width: 1
              border.color: Qt.rgba(0, 0, 0, 0.12)

              Behavior on color {
                ColorAnimation {
                  duration: 150
                }
              }

              Text {
                text: "󰤨"
                anchors.centerIn: parent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.95
                color: root.ready ? Theme.textContrast(parent.color) : Theme.textInactiveColor
              }
            }

            Item {
              Layout.fillWidth: true
            }

            OToggle {
              id: networkToggle
              Layout.preferredWidth: Theme.itemHeight * 2.6
              Layout.preferredHeight: Theme.itemHeight * 0.72
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
        radius: Theme.itemRadius
        color: Qt.lighter(Theme.bgColor, 1.35)
        border.width: 1
        border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
        opacity: root.ready && root.networkingEnabled ? 1 : 0.5

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
            text: qsTr("Wi-Fi")
            font.bold: true
            color: root.ready && root.networkingEnabled ? Theme.textActiveColor : Theme.textInactiveColor
          }

          RowLayout {
            spacing: root.padding * 0.9

            Rectangle {
              implicitWidth: Theme.itemHeight * 0.9
              implicitHeight: implicitWidth
              radius: height / 2
              color: root.ready && root.networkingEnabled ? Qt.lighter(Theme.onHoverColor, 1.25) : Qt.darker(Theme.inactiveColor, 1.1)
              border.width: 1
              border.color: Qt.rgba(0, 0, 0, 0.12)

              Behavior on color {
                ColorAnimation {
                  duration: 150
                }
              }

              Text {
                text: "󰒓"
                anchors.centerIn: parent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize * 0.95
                color: root.ready && root.networkingEnabled ? Theme.textContrast(parent.color) : Theme.textInactiveColor
              }
            }

            Item {
              Layout.fillWidth: true
            }

            OToggle {
              id: wifiToggle
              Layout.preferredWidth: Theme.itemHeight * 2.6
              Layout.preferredHeight: Theme.itemHeight * 0.72
              disabled: !root.ready || !root.networkingEnabled
              onToggled: checked => NetworkService.setWifiRadioEnabled(checked)
            }
          }
        }
      }
    }

    // Network List
    Rectangle {
      Layout.fillWidth: true
      Layout.topMargin: root.padding
      Layout.bottomMargin: root.padding * 2
      radius: Theme.itemRadius
      color: Qt.lighter(Theme.bgColor, 1.25)
      border.width: 1
      border.color: Qt.rgba(Theme.borderColor.r, Theme.borderColor.g, Theme.borderColor.b, 0.35)
      visible: root.ready && root.networkingEnabled && root.wifiEnabled && networkList.count > 0
      clip: true
      implicitHeight: visible ? networkList.implicitHeight + root.padding * 1.4 : 0

      ListView {
        id: networkList
        anchors.fill: parent
        anchors.margins: root.padding * 0.8
        spacing: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        implicitHeight: Math.min(contentHeight, root.maxItems * root.itemHeight + (root.maxItems - 1) * 4)
        interactive: contentHeight > height
        model: root.buildNetworkList()

        ScrollBar.vertical: ScrollBar {
          policy: networkList.contentHeight > networkList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
          width: 8
        }

        delegate: NetworkItem {
          id: delegateItem
          width: ListView.view.width
          onTriggered: (action, data) => {
            root.handleAction(action, data);
            if (!action.startsWith("connect-") || delegateItem.modelData.connected || delegateItem.modelData.isSaved) {
              root.close();
            }
          }
          onPasswordCleared: root.passwordError = ""
        }
      }
    }
  }

  component NetworkItem: Item {
    id: networkItem
    required property var modelData

    readonly property bool isInput: networkItem.modelData.type === "input"
    readonly property color textColor: networkItem.hovered ? Theme.textOnHoverColor : Theme.textActiveColor

    property bool hovered: false

    signal triggered(string action, var data)
    signal passwordCleared

    height: networkItem.isInput ? (networkItem.modelData.hasError ? Theme.itemHeight * 1.6 : Theme.itemHeight * 0.8) : Theme.itemHeight

    Rectangle {
      anchors.fill: parent
      visible: !networkItem.isInput
      color: networkItem.hovered ? Theme.onHoverColor : "transparent"
      radius: Theme.itemRadius
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
          Layout.preferredWidth: Theme.fontSize * 1.5
          Layout.preferredHeight: Theme.itemHeight
          Layout.leftMargin: root.padding

          Text {
            id: networkIcon
            text: networkItem.modelData.icon || ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: networkItem.modelData.bandColor || networkItem.textColor
            anchors.centerIn: parent
            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }

          Text {
            text: networkItem.modelData.band === "2.4" ? "2.4" : networkItem.modelData.band
            font.family: "Roboto Condensed"
            font.pixelSize: Theme.fontSize * 0.5
            font.bold: true
            color: networkItem.modelData.bandColor || networkItem.textColor
            anchors.left: networkIcon.right
            anchors.leftMargin: -2
            anchors.bottom: networkIcon.bottom
            visible: networkItem.modelData.band !== ""
            Behavior on color {
              ColorAnimation {
                duration: Theme.animationDuration
              }
            }
          }
        }

        Text {
          text: networkItem.modelData.label || ""
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: networkItem.textColor
          Layout.fillWidth: true
          Behavior on color {
            ColorAnimation {
              duration: Theme.animationDuration
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: networkItem.hovered = true
            onExited: networkItem.hovered = false
            onClicked: networkItem.triggered(networkItem.modelData.action || "", {})
          }
        }

        IconButton {
          visible: networkItem.modelData.forgetIcon !== undefined
          Layout.preferredWidth: Theme.itemHeight * 0.8
          Layout.preferredHeight: Theme.itemHeight * 0.8
          Layout.rightMargin: 4
          icon: networkItem.modelData.forgetIcon || ""
          colorBg: "#F38BA8"
          tooltipText: qsTr("Forget Network")
          onClicked: networkItem.triggered("forget-" + networkItem.modelData.ssid, {})
        }

        IconButton {
          visible: networkItem.modelData.actionIcon !== undefined
          Layout.preferredWidth: Theme.itemHeight * 0.8
          Layout.preferredHeight: Theme.itemHeight * 0.8
          Layout.rightMargin: root.padding
          icon: networkItem.modelData.actionIcon || ""
          colorBg: Theme.activeColor
          tooltipText: networkItem.modelData.connected ? qsTr("Disconnect") : qsTr("Connect")
          onClicked: networkItem.triggered(networkItem.modelData.action || "", {})
        }
      }
    }

    Component {
      id: inputComp
      RowLayout {
        spacing: 8

        Text {
          text: networkItem.modelData.icon || ""
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          color: networkItem.textColor
          Layout.leftMargin: root.padding
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
              color: Theme.bgColor
              border.color: networkItem.modelData.hasError ? Theme.critical : (passwordField.activeFocus ? Theme.activeColor : Theme.borderColor)
              border.width: networkItem.modelData.hasError ? 2 : 1
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

                placeholderText: networkItem.modelData.placeholder || ""
                echoMode: TextInput.Password
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.textActiveColor
                selectionColor: Theme.activeColor
                selectedTextColor: Theme.textContrast(Theme.activeColor)

                background: Rectangle {
                  color: "transparent"
                }

                onTextChanged: networkItem.passwordCleared()

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

                Component.onCompleted: Qt.callLater(() => passwordField.forceActiveFocus())
              }
            }

            IconButton {
              Layout.preferredWidth: Theme.itemHeight * 0.8
              Layout.preferredHeight: Theme.itemHeight * 0.8
              icon: "󰅖"
              colorBg: Theme.inactiveColor
              tooltipText: qsTr("Cancel")
              onClicked: networkItem.triggered("cancel", {})
            }

            IconButton {
              Layout.preferredWidth: Theme.itemHeight * 0.8
              Layout.preferredHeight: Theme.itemHeight * 0.8
              icon: networkItem.modelData.hasError ? "󰀦" : "󰌘"
              colorBg: networkItem.modelData.hasError ? "#F38BA8" : Theme.activeColor
              enabled: passwordField.text !== ""
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
            visible: networkItem.modelData.hasError && networkItem.modelData.errorMessage !== ""
            text: "⚠ " + (networkItem.modelData.errorMessage || "")
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
