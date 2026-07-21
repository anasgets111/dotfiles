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
  readonly property bool hiddenConnecting: isHiddenTarget && targetSsid !== "" && connectingSsid === targetSsid
  property bool isHiddenTarget: false
  readonly property bool networkingEnabled: NetworkService.networkingEnabled
  readonly property var pendingAp: (isHiddenTarget && targetSsid !== "") ? networkForSsid(targetSsid) : null
  readonly property bool ready: NetworkService.ready
  readonly property var savedNetworks: NetworkService.savedWifiAps
  property bool scanning: false
  readonly property bool showGroups: savedNetworks.some(ap => !ap.connected) && availableNetworks.length > 0
  readonly property bool showPasswordInput: isHiddenTarget && !showSsidInput && !hiddenConnecting && (pendingAp ? pendingAp.secured : true)
  readonly property bool showSsidInput: isHiddenTarget && targetSsid === ""
  property string targetSsid: ""
  readonly property var viewList: NetworkService.viewWifiAps.map(ap => Object.assign({}, ap, {
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

  needsKeyboardFocus: showSsidInput || showPasswordInput || (expandedSsid !== "" && connectingSsid === "")
  preferredHeight: mainLayout.implicitHeight + Theme.spacingMd * 2
  preferredWidth: 340

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
    function onConnectFailed() {
      root.errorDismissed = false;
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

    PanelTogglePill {
      Layout.bottomMargin: root.networkingEnabled ? Theme.spacingXs : Theme.spacingMd
      active: root.ready
      checked: root.networkingEnabled
      detail: !root.ready ? qsTr("Unavailable") : !root.networkingEnabled ? qsTr("Off") : root.connectedNetwork !== null ? root.connectedNetwork.ssid : NetworkService.ethernetOnline ? qsTr("Ethernet connected") : qsTr("Not connected")
      icon: root.connectedNetwork !== null ? "󰤨" : NetworkService.ethernetOnline ? "󰈀" : "󱘖"
      label: qsTr("Network")

      onToggled: c => NetworkService.setNetworkingEnabled(c)
    }
    RowLayout {
      Layout.bottomMargin: Theme.spacingMd
      Layout.fillWidth: true
      spacing: Theme.spacingXs
      visible: root.networkingEnabled

      PanelTogglePill {
        active: root.ready
        checked: root.wifiEnabled
        icon: "󰤨"
        label: qsTr("Wi-Fi")

        onToggled: c => NetworkService.setWifiRadioEnabled(c)
      }
      PanelTogglePill {
        active: root.ready && root.ethernetInterface !== ""
        checked: NetworkService.ethernetOnline
        icon: "󰈀"
        label: root.ethernetInterface !== "" ? qsTr("Ethernet") : qsTr("No Ethernet")

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
      onForgetClicked: ssid => NetworkService.forgetWifi(ssid)
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

            connecting: root.connectingSsid !== "" && root.connectingSsid === modelData.ssid
            errorMessage: root.expandedSsid === modelData.ssid ? root.connectError : ""
            expanded: root.expandedSsid === modelData.ssid
            isSaved: modelData.saved
            network: modelData
            width: ListView.view.width

            onCancelExpand: root.cancelInline()
            onClicked: root.connectToNetwork(modelData.ssid)
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
          NetworkService.cancelConnect();
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
      text: !root.networkingEnabled ? qsTr("Networking disabled") : qsTr("Wi-Fi off")
      visible: !root.networkingEnabled || !root.wifiEnabled
    }
  }

  component BandBadge: InfoBadge {
    property string band: ""
    readonly property string bv: String(band || "").trim()

    badgeColor: bv === "6" ? Theme.powerSaveColor : bv === "5" ? Theme.activeColor : Theme.inactiveColor
    opacity: 0.7
    text: bv === "2.4" ? "2.4" : bv + "G"
    visible: bv !== ""
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
      hasError: form.errorMessage !== ""
      isPassword: true
      placeholder: qsTr("Password")
      visible: !form.connecting

      onAccepted: val => form.submitted(val)
      onCancelled: form.cancelled()
      onTextEdited: form.edited()
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

      Text {
        color: Theme.activeColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: "󰑐"
        visible: form.connecting

        RotationAnimation on rotation {
          duration: 1000
          from: 0
          loops: Animation.Infinite
          running: form.connecting
          to: 360
        }
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
        variant: "primary"
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
      placeholder: qsTr("Network name")
      visible: sheet.ssidMode

      onAccepted: val => sheet.ssidSubmitted(val)
      onCancelled: sheet.cancelled()
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
        variant: "primary"

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
  component EthernetHeroCard: Rectangle {
    id: ethHero

    property string interfaceName: ""
    property string ip: ""
    property int speed: 0
    readonly property string speedText: speed >= 1000 ? (speed / 1000) + " Gb/s" : speed + " Mb/s"

    signal disconnectClicked

    border.color: Theme.withOpacity(Theme.activeColor, 0.35)
    border.width: Theme.borderWidthMedium
    color: Theme.activeSubtle
    implicitHeight: visible ? ethContent.implicitHeight + Theme.spacingSm * 2 : 0
    radius: Theme.radiusLg

    Behavior on implicitHeight {
      NumberAnimation {
        duration: Theme.animationDuration
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
          color: Theme.textActiveColor
          elide: Text.ElideRight
          text: ethHero.interfaceName || qsTr("Ethernet")
        }
        OText {
          color: Theme.textInactiveColor
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

    border.color: Theme.withOpacity(Theme.activeColor, 0.35)
    border.width: Theme.borderWidthMedium
    color: Theme.activeSubtle
    implicitHeight: visible ? heroContent.implicitHeight + Theme.spacingSm * 2 : 0
    radius: Theme.radiusLg

    Behavior on implicitHeight {
      NumberAnimation {
        duration: Theme.animationDuration
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
          color: Theme.textActiveColor
          elide: Text.ElideRight
          text: hero.network?.ssid || ""
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: Theme.spacingXs

          OText {
            color: Theme.textInactiveColor
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
        color: hma.containsMouse ? Theme.withOpacity(Theme.activeColor, 0.08) : "transparent"
        radius: Theme.itemRadius

        Behavior on color {
          ColorAnimation {
            duration: Theme.animationDuration
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
    readonly property bool secured: network?.secured === true

    signal cancelExpand
    signal clicked
    signal forgetClicked
    signal passwordEdited
    signal passwordSubmitted(string pw)

    color: "transparent"
    height: rowCol.implicitHeight
    radius: Theme.radiusMd

    Behavior on height {
      NumberAnimation {
        duration: Theme.animationDuration
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
        color: rowMa.containsMouse && !row.connecting ? Theme.withOpacity(Theme.activeColor, 0.08) : "transparent"
        radius: Theme.radiusMd

        Behavior on color {
          ColorAnimation {
            duration: Theme.animationDuration
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
            text: "󰑐"
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
      CredentialForm {
        Layout.bottomMargin: row.expanded ? Theme.spacingSm : 0
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacingSm
        Layout.rightMargin: Theme.spacingSm
        Layout.topMargin: row.expanded ? Theme.spacingXs : 0
        buttonSize: "sm"
        connecting: row.connecting
        errorMessage: row.errorMessage
        visible: row.expanded

        onCancelled: row.cancelExpand()
        onEdited: row.passwordEdited()
        onSubmitted: pw => row.passwordSubmitted(pw)
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
      border.width: sf.hasError ? Theme.borderWidthMedium : Theme.borderWidthThin
      color: Theme.bgInput
      radius: Theme.radiusMd

      Behavior on border.color {
        ColorAnimation {
          duration: Theme.animationDuration
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

        background: null

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
            duration: Theme.animationDuration
          }
        }
        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animationDuration
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
