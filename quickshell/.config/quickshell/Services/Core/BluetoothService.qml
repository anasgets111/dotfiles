pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.Services.Utils

Singleton {
  id: root

  // Adapter is set at runtime to avoid qml-ls unresolved-type errors
  property var adapter: null
  readonly property var allDevicesWithBattery: {
    if (!devices || devices.length === 0)
      return [];

    return devices.filter(dev => {
      return dev && dev.batteryAvailable && dev.battery > 0;
    });
  }
  readonly property bool available: !!adapter
  // Expose devices as a plain array of device objects for easier filtering/sorting
  readonly property var devices: (adapter && adapter.devices && adapter.devices.values) ? adapter.devices.values : []
  readonly property bool discovering: !!(adapter && adapter.discovering)
  readonly property bool enabled: !!(adapter && adapter.enabled)
  readonly property var pairedDevices: {
    if (!devices || devices.length === 0)
      return [];

    return devices.filter(dev => {
      return dev && (dev.paired || dev.trusted);
    });
  }

  function canConnect(device) {
    if (!device)
      return false;

    return !device.paired && !device.pairing && !device.blocked;
  }

  function connectDeviceWithTrust(device) {
    if (!device) {
      Logger.error("BluetoothService", "connectDeviceWithTrust called with null/undefined device");
      return;
    }
    const name = (device.name || device.deviceName || "");
    const address = (device.address || "");
    if (!canConnect(device)) {
      Logger.warn("BluetoothService", `Cannot connect: name='${name}', address='${address}', paired=${device.paired}, pairing=${device.pairing}, blocked=${device.blocked}, state=${device.state}`);
      return;
    }
    Logger.log("BluetoothService", `Connecting (trust first): name='${name}', address='${address}'`);
    device.trusted = true;
    device.connect();
  }

  function getDeviceIcon(device) {
    if (!device)
      return "bluetooth";

    var name = (device.name || device.deviceName || "").toLowerCase();
    var icon = (device.icon || "").toLowerCase();
    if (icon.includes("headset") || icon.includes("audio") || name.includes("headphone") || name.includes("airpod") || name.includes("headset") || name.includes("arctis"))
      return "headset";

    if (icon.includes("mouse") || name.includes("mouse"))
      return "mouse";

    if (icon.includes("keyboard") || name.includes("keyboard"))
      return "keyboard";

    if (icon.includes("phone") || name.includes("phone") || name.includes("iphone") || name.includes("android") || name.includes("samsung"))
      return "smartphone";

    if (icon.includes("watch") || name.includes("watch"))
      return "watch";

    if (icon.includes("speaker") || name.includes("speaker"))
      return "speaker";

    if (icon.includes("display") || name.includes("tv"))
      return "tv";

    return "bluetooth";
  }

  function getSignalIcon(device) {
    if (!device || device.signalStrength === undefined || device.signalStrength <= 0)
      return "signal_cellular_null";

    var signal = device.signalStrength;
    if (signal >= 80)
      return "signal_cellular_4_bar";

    if (signal >= 60)
      return "signal_cellular_3_bar";

    if (signal >= 40)
      return "signal_cellular_2_bar";

    if (signal >= 20)
      return "signal_cellular_1_bar";

    return "signal_cellular_0_bar";
  }

  function getSignalStrength(device) {
    if (!device || device.signalStrength === undefined || device.signalStrength <= 0)
      return "Unknown";

    var signal = device.signalStrength;
    if (signal >= 80)
      return "Excellent";

    if (signal >= 60)
      return "Good";

    if (signal >= 40)
      return "Fair";

    if (signal >= 20)
      return "Poor";

    return "Very Poor";
  }

  function isDeviceBusy(device) {
    if (!device)
      return false;

    return device.pairing || device.state === BluetoothDeviceState.Disconnecting || device.state === BluetoothDeviceState.Connecting;
  }

  // Optional: allow external wiring to set the adapter without referencing
  // Bluetooth.defaultAdapter here (avoids qml-ls unresolved-type warnings).
  function setAdapter(a) {
    if (!a) {
      Logger.warn("BluetoothService", "Adapter cleared (setAdapter(null))");
    } else {
      const name = (a.name || a.adapterName || "");
      const address = (a.address || "");
      Logger.log("BluetoothService", `Adapter set: name='${name}', address='${address}'`);
    }
    adapter = a;
  }

  function sortDevices(devices) {
    return devices.slice().sort((a, b) => {
      var aName = a.name || a.deviceName || "";
      var bName = b.name || b.deviceName || "";
      var aHasRealName = aName.includes(" ") && aName.length > 3;
      var bHasRealName = bName.includes(" ") && bName.length > 3;
      if (aHasRealName && !bHasRealName)
        return -1;

      if (!aHasRealName && bHasRealName)
        return 1;

      var aSignal = (a.signalStrength !== undefined && a.signalStrength > 0) ? a.signalStrength : 0;
      var bSignal = (b.signalStrength !== undefined && b.signalStrength > 0) ? b.signalStrength : 0;
      return bSignal - aSignal;
    });
  }

  // Lifecycle and state-change logs
  Component.onCompleted: {
    const count = devices ? devices.length : 0;
    Logger.log("BluetoothService", `Init: available=${available}, enabled=${enabled}, discovering=${discovering}, devices=${count}`);
  }
  onAllDevicesWithBatteryChanged: {
    const count = allDevicesWithBattery ? allDevicesWithBattery.length : 0;
    Logger.log("BluetoothService", `Devices with battery: count=${count}`);
  }
  onAvailableChanged: {
    Logger.log("BluetoothService", `Adapter available=${available}`);
  }
  onDevicesChanged: {
    const count = devices ? devices.length : 0;
    Logger.log("BluetoothService", `Devices updated: count=${count}`);
  }
  onDiscoveringChanged: {
    Logger.log("BluetoothService", `Discovering=${discovering}`);
  }
  onEnabledChanged: {
    Logger.log("BluetoothService", `Adapter enabled=${enabled}`);
  }
  onPairedDevicesChanged: {
    const count = pairedDevices ? pairedDevices.length : 0;
    Logger.log("BluetoothService", `Paired devices: count=${count}`);
  }
}
