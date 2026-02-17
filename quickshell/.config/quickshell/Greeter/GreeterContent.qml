pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

Item {
  id: root
  required property bool isPrimary

  // ── User Discovery ──────────────────────────────────────────────────
  property var systemUsers: []
  FileView {
    path: "/etc/passwd"
    blockLoading: true
    watchChanges: false
    printErrors: false
    onLoaded: {
      const users = [];
      for (const line of text().split("\n")) {
        const p = line.split(":");
        if (p.length < 7) continue;
        const uid = parseInt(p[2]);
        if (uid < 1000 || uid >= 60000) continue;
        if (p[6].endsWith("/nologin") || p[6].endsWith("/false")) continue;
        const gecos = (p[4] || "").split(",")[0].trim() || p[0];
        users.push({ name: p[0], gecos });
      }
      root.systemUsers = users;
      if (users.length === 1 && !greeterState.username) {
        greeterState.username = users[0].name;
        greeterState.displayName = users[0].gecos;
      } else if (greeterMemory.ready && greeterMemory.lastSuccessfulUser) {
        const found = users.find(u => u.name === greeterMemory.lastSuccessfulUser);
        if (found && !greeterState.username) {
          greeterState.username = found.name;
          greeterState.displayName = found.gecos;
        }
      }
    }
  }

  // ── Session Discovery ──────────────────────────────────────────────
  readonly property var sessionDirs: ["/usr/share/wayland-sessions", "/usr/local/share/wayland-sessions"]
  property var _pendingFiles: ({})
  property int _pendingCount: 0

  function _addSession(path, name, exec) {
    if (!name || !exec || greeterState.sessionList.includes(name)) return;
    greeterState.sessionList = greeterState.sessionList.concat([name]);
    greeterState.sessionExecs = greeterState.sessionExecs.concat([exec]);
    greeterState.sessionPaths = greeterState.sessionPaths.concat([path]);
  }
  function _parseDesktopFile(content, path) {
    let name = "", exec = "";
    for (const line of content.split("\n")) {
      if (!name && line.startsWith("Name=")) name = line.substring(5).trim();
      else if (!exec && line.startsWith("Exec=")) exec = line.substring(5).trim();
      if (name && exec) break;
    }
    _addSession(path, name, exec);
  }
  function _loadDesktopFile(filePath) {
    if (_pendingFiles[filePath]) return;
    _pendingFiles[filePath] = true;
    _pendingCount++;
    desktopFileLoader.createObject(root, { filePath });
  }
  function _onFileLoaded() {
    _pendingCount--;
    if (_pendingCount === 0) Qt.callLater(finalizeSessionSelection);
  }
  function finalizeSessionSelection() {
    if (greeterState.sessionList.length === 0 || !greeterMemory.ready) return;
    const saved = greeterMemory.lastSessionId;
    if (saved) {
      const idx = greeterState.sessionPaths.indexOf(saved);
      if (idx >= 0) { greeterState.currentSessionIndex = idx; return; }
    }
    greeterState.currentSessionIndex = 0;
  }

  Component.onCompleted: {
    if (isPrimary && greeterMemory.ready && greeterMemory.lastSuccessfulUser && !greeterState.username)
      greeterState.username = greeterMemory.lastSuccessfulUser;
  }

  Component {
    id: desktopFileLoader
    FileView {
      property string filePath: ""
      path: filePath
      onLoaded: { root._parseDesktopFile(text(), filePath); root._onFileLoaded(); destroy(); }
      onLoadFailed: { root._onFileLoaded(); destroy(); }
    }
  }

  Repeater {
    model: root.isPrimary ? root.sessionDirs : []
    Item {
      required property string modelData
      FolderListModel {
        folder: "file://" + modelData
        nameFilters: ["*.desktop"]
        showDirs: false
        onStatusChanged: {
          if (status !== FolderListModel.Ready) return;
          for (let i = 0; i < count; i++) {
            let fp = get(i, "filePath");
            if (fp.startsWith("file://")) fp = fp.substring(7);
            root._loadDesktopFile(fp);
          }
        }
      }
    }
  }

  Connections {
    target: greeterMemory
    function onReadyChanged() { root.finalizeSessionSelection(); }
  }

  // ── Greetd Auth Flow ──────────────────────────────────────────────
  Connections {
    target: Greetd
    enabled: root.isPrimary

    function onAuthMessage(message, error, responseRequired, echoResponse) {
      if (responseRequired) {
        Greetd.respond(greeterState.passwordBuffer);
        greeterState.passwordBuffer = "";
        inputField.text = "";
        return;
      }
      if (!error) Greetd.respond("");
    }
    function onReadyToLaunch() {
      const idx = greeterState.currentSessionIndex;
      const cmd = greeterState.sessionExecs[idx];
      const path = greeterState.sessionPaths[idx];
      if (!cmd) { greeterState.pamState = "error"; pamResetTimer.restart(); return; }
      greeterState.unlocking = true;
      launchTimeout.restart();
      greeterMemory.setLastSession(path);
      greeterMemory.setLastUser(greeterState.username);
      Greetd.launch(cmd.replace(/%[fFuUdDnNickvm]/g, "").trim().split(/\s+/), ["XDG_SESSION_TYPE=wayland"]);
      Qt.quit();
    }
    function onAuthFailure() {
      launchTimeout.stop();
      greeterState.unlocking = false;
      greeterState.pamState = "fail";
      greeterState.passwordBuffer = "";
      inputField.text = "";
      pamResetTimer.restart();
    }
    function onError() {
      launchTimeout.stop();
      greeterState.unlocking = false;
      greeterState.pamState = "error";
      greeterState.passwordBuffer = "";
      inputField.text = "";
      pamResetTimer.restart();
      Greetd.cancelSession();
    }
  }

  Timer {
    id: launchTimeout
    interval: 8000
    onTriggered: {
      if (!greeterState.unlocking) return;
      greeterState.unlocking = false;
      greeterState.pamState = "error";
      pamResetTimer.restart();
      Greetd.cancelSession();
    }
  }
  Timer { id: pamResetTimer; interval: 3000; onTriggered: greeterState.pamState = "" }

  // ── Background ────────────────────────────────────────────────────
  Rectangle { anchors.fill: parent; color: theme.bgColor }
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: theme.withOpacity(theme.activeColor, 0.08) }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  SystemClock { id: clock; precision: SystemClock.Seconds }

  // ── Main Card ─────────────────────────────────────────────────────
  Rectangle {
    id: card
    anchors.centerIn: parent
    border.color: theme.withOpacity("#ffffff", 0.22)
    border.width: 1
    color: theme.withOpacity(theme.bgColor, 0.30)
    height: cardLayout.implicitHeight + theme.spacingXl * 2
    width: Math.max(460, Math.min(Math.round(parent.width * 0.38), 640))
    radius: theme.radiusXl

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowBlur: theme.shadowBlurLg
      shadowColor: theme.shadowColor
      shadowEnabled: true
      shadowVerticalOffset: 4
    }

    Rectangle {
      anchors.fill: parent; anchors.margins: 1
      border.color: theme.withOpacity("#ffffff", 0.10)
      border.width: 1
      color: "transparent"
      radius: Math.max(0, card.radius - 1)
    }

    ColumnLayout {
      id: cardLayout
      anchors.fill: parent
      anchors.margins: theme.spacingXl

      // Clock
      Text {
        Layout.fillWidth: true
        color: theme.textActiveColor
        font { family: theme.fontFamily; pixelSize: theme.fontHero; weight: Font.Bold }
        horizontalAlignment: Text.AlignHCenter
        text: clock.date.toLocaleTimeString(Qt.locale(), "h:mm AP")
      }
      Text {
        Layout.fillWidth: true; Layout.topMargin: theme.spacingSm * 0.5
        color: theme.withOpacity(theme.textActiveColor, 0.7)
        font { family: theme.fontFamily; pixelSize: theme.fontLg }
        horizontalAlignment: Text.AlignHCenter
        text: clock.date.toLocaleDateString(Qt.locale(), "dddd, MMMM d")
      }

      Item { Layout.preferredHeight: theme.spacingLg }

      // User strip
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: userFlow.implicitHeight
        visible: root.isPrimary && root.systemUsers.length > 0

        Flow {
          id: userFlow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: theme.spacingSm

          Repeater {
            model: root.systemUsers
            Rectangle {
              required property var modelData
              required property int index
              readonly property bool isSelected: modelData.name === greeterState.username

              color: isSelected ? theme.withOpacity(theme.activeColor, 0.25) : theme.withOpacity(theme.bgColor, 0.4)
              border.color: isSelected ? theme.withOpacity(theme.activeColor, 0.6) : theme.withOpacity("#ffffff", 0.08)
              border.width: 1
              height: 36; radius: theme.radiusMd
              width: userLabel.implicitWidth + theme.spacingLg * 2
              Behavior on color { ColorAnimation { duration: theme.animationDuration } }
              Behavior on border.color { ColorAnimation { duration: theme.animationDuration } }

              RowLayout {
                anchors.centerIn: parent; spacing: theme.spacingSm * 0.5
                Text {
                  color: parent.parent.isSelected ? theme.activeColor : theme.withOpacity(theme.textActiveColor, 0.5)
                  font { family: theme.iconFontFamily; pixelSize: 12 }
                  text: "󰀄"
                  Behavior on color { ColorAnimation { duration: theme.animationDuration } }
                }
                Text {
                  id: userLabel
                  color: parent.parent.isSelected ? theme.textActiveColor : theme.withOpacity(theme.textActiveColor, 0.5)
                  font { family: theme.fontFamily; pixelSize: theme.fontSm; weight: parent.parent.isSelected ? Font.DemiBold : Font.Normal }
                  text: modelData.gecos || modelData.name
                  Behavior on color { ColorAnimation { duration: theme.animationDuration } }
                }
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  greeterState.username = parent.modelData.name;
                  greeterState.displayName = parent.modelData.gecos;
                  greeterState.passwordBuffer = "";
                  inputField.text = "";
                  inputField.forceActiveFocus();
                }
              }
            }
          }
        }
      }

      Item { Layout.preferredHeight: theme.spacingMd }

      // Avatar
      Item {
        readonly property int avatarSize: Math.round(theme.controlHeightLg * 2.4)
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: avatarSize; Layout.preferredWidth: avatarSize

        Rectangle {
          anchors.centerIn: parent
          border.color: theme.withOpacity(theme.activeColor, 0.5)
          border.width: 2
          color: "transparent"
          height: parent.avatarSize + 6; width: height; radius: width / 2
          layer.enabled: true
          layer.effect: MultiEffect {
            shadowBlur: 16
            shadowColor: theme.withOpacity(theme.activeColor, 0.35)
            shadowEnabled: true
          }
        }
        Rectangle {
          anchors.fill: parent
          color: theme.withOpacity(theme.activeColor, 0.22)
          radius: width / 2
          Text {
            anchors.centerIn: parent
            color: theme.textActiveColor
            font { family: theme.fontFamily; pixelSize: Math.round(theme.fontHero * 0.7); weight: Font.Bold }
            text: {
              const src = greeterState.displayName || greeterState.username || "U";
              return src.split(" ").filter(Boolean).slice(0, 2)
                .map(p => p[0]?.toUpperCase() ?? "").join("") || "U";
            }
          }
        }
      }

      // Username label
      Text {
        Layout.fillWidth: true; Layout.topMargin: theme.spacingSm
        color: theme.textActiveColor
        font { family: theme.fontFamily; pixelSize: Math.round(theme.fontXl * 1.2); weight: Font.DemiBold }
        horizontalAlignment: Text.AlignHCenter
        text: greeterState.displayName || greeterState.username || "Welcome"
      }

      Item { Layout.preferredHeight: theme.spacingLg }

      // Password input
      Rectangle {
        id: inputContainer
        readonly property bool isFail: greeterState.pamState === "fail"
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Math.round(card.width * 0.85)
        Layout.preferredHeight: Math.round(theme.controlHeightLg * 1.25)
        border.color: isFail ? theme.critical
          : greeterState.unlocking || Greetd.state !== GreetdState.Inactive ? theme.activeColor
          : inputField.activeFocus ? theme.activeColor
          : theme.withOpacity("#ffffff", 0.18)
        border.width: 2
        color: theme.bgInput
        radius: theme.radiusFull
        visible: root.isPrimary && greeterState.username
        Behavior on border.color { ColorAnimation { duration: theme.animationDuration } }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: theme.spacingMd; anchors.rightMargin: theme.spacingMd
          spacing: theme.spacingSm

          Text {
            color: theme.withOpacity(theme.activeColor, 0.8)
            font { family: theme.iconFontFamily; pixelSize: theme.iconSizeMd }
            text: "󰌋"
          }
          TextInput {
            id: inputField
            Layout.fillWidth: true
            clip: true
            color: theme.textActiveColor
            echoMode: TextInput.Password
            font { family: theme.fontFamily; pixelSize: theme.fontLg }
            focus: root.isPrimary
            onTextChanged: greeterState.passwordBuffer = text
            onAccepted: {
              if (Greetd.state === GreetdState.Inactive && greeterState.username)
                Greetd.createSession(greeterState.username);
            }
            Component.onCompleted: { if (root.isPrimary) forceActiveFocus(); }

            Text {
              anchors.fill: parent; verticalAlignment: Text.AlignVCenter
              color: theme.withOpacity(theme.textActiveColor, 0.4)
              font { family: theme.fontFamily; pixelSize: theme.fontLg }
              text: greeterState.unlocking ? "Logging in…"
                : Greetd.state !== GreetdState.Inactive ? "Authenticating…" : "Password…"
              visible: inputField.text.length === 0
            }
          }
        }
      }

      // Auth hint
      Text {
        Layout.fillWidth: true; Layout.topMargin: theme.spacingSm
        color: greeterState.pamState === "fail" ? theme.critical
          : greeterState.pamState === "error" ? theme.warning
          : theme.withOpacity(theme.textActiveColor, 0.45)
        font { family: theme.fontFamily; pixelSize: Math.round(theme.fontMd * 0.9) }
        horizontalAlignment: Text.AlignHCenter
        text: greeterState.pamState === "fail" ? "Incorrect password"
          : greeterState.pamState === "error" ? "Authentication error"
          : greeterState.username ? "Press Enter to authenticate" : ""
        visible: root.isPrimary
        Behavior on color { ColorAnimation { duration: theme.animationDuration } }
      }

      Item { Layout.preferredHeight: theme.spacingXl }

      // Separator
      Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: 1; Layout.preferredWidth: parent.width * 0.6
        color: theme.withOpacity("#ffffff", 0.08)
      }

      Item { Layout.preferredHeight: theme.spacingSm }

      // Session strip
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: sessionFlow.implicitHeight
        visible: root.isPrimary && greeterState.sessionList.length > 0

        Flow {
          id: sessionFlow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: theme.spacingSm

          Repeater {
            model: greeterState.sessionList
            Rectangle {
              required property string modelData
              required property int index
              readonly property bool isSelected: index === greeterState.currentSessionIndex

              color: isSelected ? theme.withOpacity(theme.activeColor, 0.25) : theme.withOpacity(theme.bgColor, 0.4)
              border.color: isSelected ? theme.withOpacity(theme.activeColor, 0.6) : theme.withOpacity("#ffffff", 0.08)
              border.width: 1
              height: 36; radius: theme.radiusMd
              width: sessionLabel.implicitWidth + theme.spacingLg * 2
              Behavior on color { ColorAnimation { duration: theme.animationDuration } }
              Behavior on border.color { ColorAnimation { duration: theme.animationDuration } }

              RowLayout {
                anchors.centerIn: parent; spacing: theme.spacingSm * 0.5
                Text {
                  color: parent.parent.isSelected ? theme.activeColor : theme.withOpacity(theme.textActiveColor, 0.5)
                  font { family: theme.iconFontFamily; pixelSize: 12 }
                  text: "󰍹"
                  Behavior on color { ColorAnimation { duration: theme.animationDuration } }
                }
                Text {
                  id: sessionLabel
                  color: parent.parent.isSelected ? theme.textActiveColor : theme.withOpacity(theme.textActiveColor, 0.5)
                  font { family: theme.fontFamily; pixelSize: theme.fontSm; weight: parent.parent.isSelected ? Font.DemiBold : Font.Normal }
                  text: modelData
                  Behavior on color { ColorAnimation { duration: theme.animationDuration } }
                }
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: greeterState.currentSessionIndex = index }
            }
          }
        }
      }
    }
  }

  // ── Power Buttons ─────────────────────────────────────────────────
  RowLayout {
    anchors { bottom: parent.bottom; left: parent.left; margins: theme.spacingXl }
    spacing: theme.spacingMd
    visible: root.isPrimary

    Repeater {
      model: [
        { icon: "󰜉", color: theme.warning, action: "reboot" },
        { icon: "󰐥", color: theme.critical, action: "poweroff" }
      ]
      Rectangle {
        required property var modelData
        color: theme.withOpacity(theme.bgColor, 0.5)
        height: 56; width: 56; radius: height / 2
        Text {
          anchors.centerIn: parent
          color: parent.modelData.color
          font { family: theme.iconFontFamily; pixelSize: 24 }
          text: parent.modelData.icon
        }
        MouseArea {
          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
          onClicked: Quickshell.execDetached(["systemctl", parent.modelData.action])
        }
      }
    }
  }
}
