pragma Singleton

import QtQuick
import QtQml.Models
import Quickshell
import org.kde.kdeconnect as KDEConnect
import qs.Services.Utils

Singleton {
  id: root

  readonly property string _conversations: "org.kde.kdeconnect.device.conversations"
  readonly property string _deviceInterface: "org.kde.kdeconnect.device."
  readonly property string _deviceRoot: "/modules/kdeconnect/devices/"
  readonly property string _service: "org.kde.kdeconnect.daemon"
  property string _smsActionError: ""
  property int _smsEpoch: 0
  property int _smsLoadEpoch: 0
  property int _smsModalOwner: 0
  property string _smsRefreshError: ""
  property int _smsRefreshEpoch: 0
  readonly property int connectedCount: devices.filter(device => device.usable).length
  readonly property var devices: Array.from({ length: deviceStates.count }, (_, index) => deviceStates.objectAt(index))
  property string error: ""
  property string smsDeviceId: ""
  property bool smsLoading: false
  property var smsMessages: []
  property bool smsMessagesLoading: false
  property string smsThreadId: ""
  property var smsThreads: []
  readonly property string smsError: _smsActionError || _smsRefreshError

  function _call(deviceId: string, plugin: string, method: string, args: var, callback: var): void {
    const suffix = plugin === "conversations" ? "" : "/" + plugin;
    Command.run(["busctl", "--user", "--json=short", "call", _service, _deviceRoot + deviceId + suffix, _deviceInterface + plugin, method].concat(args), result => {
      let callError = result.exitCode === 0 ? "" : root._errorText(result);
      let value;
      try {
        value = callError || !result.stdout.trim() ? undefined : JSON.parse(result.stdout)?.data?.[0];
      } catch (parseError) {
        callError = String(parseError);
      }
      callback?.(value, callError);
    });
  }
  function _command(deviceId: string, args: var, finished = null): void { Command.run(["kdeconnect-cli", "--device", deviceId].concat(args), result => finished?.(result.exitCode === 0 ? "" : root._errorText(result))); }
  function command(deviceId: string, args: var, finished = null): void {
    _command(deviceId, args, commandError => {
      root.error = commandError;
      finished?.(commandError);
    });
  }
  function _errorText(result: var): string { return (result?.stderr || result?.stdout || qsTr("KDE Connect command failed")).trim(); }
  function _handleSignal(line: string): void {
    try {
      const signal = JSON.parse(line);
      if (signal.type !== "signal" || signal.interface !== _conversations || !smsDeviceId || !signal.path?.endsWith("/" + smsDeviceId))
        return;
      const data = signal.payload?.data ?? [];
      if (signal.member === "conversationUpdated" || signal.member === "conversationCreated") {
        const message = _parseMessage(data[0]);
        if (!message)
          return;
        smsThreadsTimer.restart();
        if (message.threadId === smsThreadId)
          smsMessages = smsMessages.filter(existing => existing.uid !== message.uid).concat(message).sort((a, b) => a.date - b.date);
      } else if (signal.member === "conversationRemoved") {
        smsThreadsTimer.restart();
        if (smsThreadId === String(data[0] ?? ""))
          loadSmsConversation("");
      } else if (signal.member === "conversationLoaded" && String(data[0] ?? "") === smsThreadId) {
        smsMessagesLoading = false;
        smsLoadTimeout.stop();
      }
    } catch (parseError) {
    }
  }
  // Only KDE Connect's own runtime mount may reach xdg-open or fusermount.
  function _mountedPath(deviceId: string, mountPoint: var, path: var): string {
    if (!/^[a-zA-Z0-9_-]{32,38}$/.test(deviceId))
      return "";
    const rootPath = `${Quickshell.env("XDG_RUNTIME_DIR")}/${deviceId}`;
    const target = path || mountPoint;
    return mountPoint === rootPath && (target === rootPath || target.startsWith(rootPath + "/")) && !target.split("/").includes("..") ? target : "";
  }
  function _openFiles(deviceId: string, mountPoint: string, path: string): void {
    Command.run(["timeout", "3", "stat", "--", path], result => {
      if (result.exitCode !== 0) {
        root.error = qsTr("Mounted phone storage is not accessible");
        root._unmount(deviceId, mountPoint);
        return;
      }
      root.error = "";
      Command.detached(["xdg-open", path]);
    });
  }
  function _parseMessage(value: var): var {
    const data = value?.data;
    if (!Array.isArray(data) || data.length < 9)
      return null;
    return {
      addresses: (data[2] ?? []).map(address => String(address?.[0] ?? "")).filter(Boolean),
      body: String(data[1] ?? ""),
      date: Number(data[3] ?? 0),
      fromMe: [2, 3, 4, 5, 6].includes(Number(data[4] ?? 0)),
      threadId: String(data[6] ?? ""),
      uid: Number(data[7] ?? -1)
    };
  }
  function _refreshThreads(): void {
    const refreshEpoch = ++_smsRefreshEpoch;
    _smsCall("activeConversations", [], (values, callError) => {
      if (refreshEpoch !== root._smsRefreshEpoch)
        return;
      root._smsRefreshError = callError;
      if (!callError)
        root.smsThreads = (values ?? []).map(root._parseMessage).filter(Boolean).sort((a, b) => b.date - a.date);
      root.smsLoading = false;
    });
  }
  function _smsCall(method: string, args: var, callback: var): void {
    if (!smsDeviceId)
      return;
    const epoch = _smsEpoch;
    _call(smsDeviceId, "conversations", method, args, (value, callError) => {
      if (epoch === root._smsEpoch)
        callback?.(value, callError);
    });
  }
  // KDE's unmount command expects legacy fusermount, which Arch no longer ships.
  function _unmount(deviceId: string, mountPoint: string, finished = null): void {
    Command.run(["fusermount3", "-u", "-z", mountPoint], result => {
      const gone = result.exitCode === 0 || /invalid argument|not mounted/i.test(result.stderr);
      if (gone)
        root.deviceForId(deviceId)?.setSftpMounted(false);
      finished?.(gone ? "" : root._errorText(result));
    });
  }

  function browse(deviceId: string): void {
    _call(deviceId, "sftp", "mountAndWait", [], (mounted, mountError) => {
      if (!mounted) {
        if (mountError)
          root.error = mountError;
        else
          root._call(deviceId, "sftp", "getMountError", [], (reason, callError) => root.error = reason || callError || qsTr("Could not mount device files"));
        return;
      }
      root.deviceForId(deviceId)?.setSftpMounted(true);
      root._call(deviceId, "sftp", "mountPoint", [], (mountPoint, pathError) => root._call(deviceId, "sftp", "getDirectories", [], (directories, directoriesError) => {
        const path = Object.keys(directories ?? {}).concat(mountPoint ?? "").map(candidate => root._mountedPath(deviceId, mountPoint, candidate)).find(Boolean) ?? "";
        if (path)
          root._openFiles(deviceId, mountPoint, path);
        else
          root.error = pathError || directoriesError || qsTr("KDE Connect returned an invalid storage path");
      }));
    });
  }
  function attachSmsModal(): int { return ++_smsModalOwner; }
  function closeSms(): void {
    _smsEpoch++;
    smsThreadsTimer.stop();
    smsDeviceId = "";
    smsLoading = false;
    smsThreads = [];
    _smsRefreshError = "";
    loadSmsConversation("");
  }
  function detachSmsModal(owner: int): void {
    Qt.callLater(() => {
      if (owner === root._smsModalOwner)
        root.closeSms();
    });
  }
  function deviceForId(deviceId: string): var { return devices.find(device => device.id === deviceId) ?? null; }
  function loadSmsConversation(threadId: string): void {
    const loadEpoch = ++_smsLoadEpoch;
    smsLoadTimeout.stop();
    smsThreadId = String(threadId ?? "");
    smsMessages = [];
    _smsActionError = "";
    smsMessagesLoading = smsThreadId !== "";
    if (!smsMessagesLoading || !smsDeviceId)
      return;
    smsLoadTimeout.restart();
    _smsCall("requestConversation", ["xii", smsThreadId, "0", "25"], (value, callError) => {
      if (loadEpoch !== root._smsLoadEpoch)
        return;
      root._smsActionError = callError;
      if (callError) {
        smsLoadTimeout.stop();
        root.smsMessagesLoading = false;
      }
    });
  }
  function openSms(deviceId: string): void {
    closeSms();
    smsDeviceId = deviceId;
    smsLoading = true;
    _smsCall("requestAllConversationThreads", [], (value, callError) => {
      root._smsActionError = callError;
      if (callError)
        root.smsLoading = false;
      else
        smsThreadsTimer.restart();
    });
  }
  function refreshDevices(): void { Command.run(["kdeconnect-cli", "--refresh"], result => root.error = result.exitCode === 0 ? "" : root._errorText(result)); }
  function sendSms(message: string, destination: string, finished = null): void {
    _smsActionError = "";
    if (smsThreadId) {
      const threadId = smsThreadId;
      _smsCall("replyToConversation", ["xsav", threadId, message, "0"], (value, callError) => {
        root._smsActionError = callError;
        finished?.(callError);
        if (!callError && root.smsThreadId === threadId)
          root.loadSmsConversation(threadId);
      });
      return;
    }
    if (!smsDeviceId || !destination) {
      _smsActionError = qsTr("No SMS recipient selected");
      finished?.(_smsActionError);
      return;
    }
    const epoch = _smsEpoch;
    _command(smsDeviceId, ["--send-sms", message, "--destination", destination], commandError => {
      if (epoch !== root._smsEpoch)
        return;
      root._smsActionError = commandError;
      finished?.(commandError);
      if (!commandError)
        smsThreadsTimer.restart();
    });
  }
  function unmountFiles(deviceId: string): void {
    _call(deviceId, "sftp", "mountPoint", [], (mountPoint, pathError) => {
      if (!root._mountedPath(deviceId, mountPoint, "")) {
        root.error = pathError || qsTr("KDE Connect returned an invalid mount point");
        return;
      }
      root._unmount(deviceId, mountPoint, unmountError => root.error = unmountError);
    });
  }
  KDEConnect.DevicesModel {
    id: deviceModel
  }
  Instantiator {
    id: deviceStates

    model: deviceModel

    delegate: DeviceState {
      required property string deviceId

      source: KDEConnect.DeviceDbusInterfaceFactory.create(deviceId)
    }
  }
  CommandStream {
    active: root.smsDeviceId !== ""
    command: ["busctl", "--user", "--json=short", `--match=type='signal',sender='${root._service}',interface='${root._conversations}'`, "monitor"]
    restartDelay: 1000

    onLineRead: line => root._handleSignal(line)
  }
  Timer {
    id: smsThreadsTimer

    interval: 750

    onTriggered: root._refreshThreads()
  }
  Timer {
    id: smsLoadTimeout

    interval: 5000

    onTriggered: root.smsMessagesLoading = false
  }
  Component.onCompleted: {
    const id = "0123456789abcdef0123456789abcdef";
    const mount = `${Quickshell.env("XDG_RUNTIME_DIR")}/${id}`;
    console.assert(_mountedPath(id, mount, mount + "/DCIM") && !_mountedPath(id, mount, mount + "/../bad") && !_mountedPath("../bad", mount, mount), "KDE Connect mount guard self-check failed");
  }
  component DeviceState: QtObject {
    id: state

    property int _mountEpoch: 0
    property int _pluginsEpoch: 0
    readonly property var _batteryInterface: usable && hasPlugin("battery") ? KDEConnect.DeviceBatteryDbusInterfaceFactory.create(id) : null
    readonly property var _connectivityInterface: usable && hasPlugin("connectivity_report") ? KDEConnect.DeviceConnectivityReportDbusInterfaceFactory.create(id) : null
    readonly property var _lockInterface: usable && hasPlugin("lockdevice") ? KDEConnect.LockDeviceDbusInterfaceFactory.create(id) : null
    readonly property var _sftpInterface: usable && hasPlugin("sftp") ? KDEConnect.SftpDbusInterfaceFactory.create(id) : null
    readonly property int battery: _batteryInterface?.charge ?? -1
    readonly property int cellularStrength: Number(_connectivityInterface?.cellularNetworkStrength ?? -1)
    readonly property string cellularType: {
      const type = _connectivityInterface?.cellularNetworkType ?? "";
      return type === "Unknown" ? "" : type;
    }
    readonly property bool charging: _batteryInterface?.isCharging ?? false
    readonly property string id: source?.id() ?? ""
    readonly property bool locked: _lockInterface?.isLocked ?? false
    readonly property string name: source?.name ?? ""
    readonly property bool paired: source?.isPaired ?? false
    readonly property bool pairRequested: pairRequestedByPeer || (source?.isPairRequested ?? false)
    readonly property bool pairRequestedByPeer: source?.isPairRequestedByPeer ?? false
    property var plugins: []
    readonly property bool reachable: source?.isReachable ?? false
    property bool sftpMounted: false
    required property var source
    property string type: "phone"
    readonly property bool usable: paired && reachable
    readonly property string verificationKey: source?.verificationKey ?? ""

    function acceptPairing(): void { source?.acceptPairing(); }
    function cancelPairing(): void { source?.cancelPairing(); }
    function hasPlugin(plugin: string): bool { return plugins.includes("kdeconnect_" + plugin); }
    function _respond(call: var, settled: var): void {
      const response = responseComponent.createObject(state, { settled });
      response.setPendingCall(call);
    }
    function refreshMounted(): void {
      const requestEpoch = ++_mountEpoch;
      if (!_sftpInterface) {
        sftpMounted = false;
        return;
      }
      _respond(_sftpInterface.isMounted(), mounted => {
        if (requestEpoch === state._mountEpoch)
          state.sftpMounted = mounted ?? false;
      });
    }
    function refreshPlugins(): void {
      const requestEpoch = ++_pluginsEpoch;
      if (!source) {
        plugins = [];
        return;
      }
      _respond(source.loadedPlugins(), loadedPlugins => {
        if (requestEpoch === state._pluginsEpoch)
          state.plugins = loadedPlugins ?? [];
      });
    }
    function requestPairing(): void { source?.requestPairing(); }
    function setSftpMounted(value: bool): void { _mountEpoch++; sftpMounted = value; }
    function setLocked(value: bool): void {
      if (_lockInterface)
        _lockInterface.isLocked = value;
    }
    function unpair(): void { source?.unpair(); }

    Component.onCompleted: {
      refreshPlugins();
      type = source?.type ?? "phone";
    }
    on_SftpInterfaceChanged: refreshMounted()

    readonly property Connections deviceConnections: Connections {
      function onPluginsChanged(): void { state.refreshPlugins(); }
      function onTypeChanged(): void { state.type = state.source?.type ?? "phone"; }

      target: state.source
    }
    readonly property Component responseComponent: Component {
      KDEConnect.DBusAsyncResponse {
        required property var settled

        autoDelete: true

        onError: settled()
        onSuccess: value => settled(value)
      }
    }
    readonly property Connections sftpConnections: Connections {
      function onMounted(): void { state.setSftpMounted(true); }
      function onUnmounted(): void { state.setSftpMounted(false); }

      target: state._sftpInterface
    }
  }
}
