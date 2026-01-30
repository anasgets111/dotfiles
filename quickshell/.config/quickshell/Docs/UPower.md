# Quickshell UPower Service Findings

Based on investigations and logs within the `BatteryService.qml`, here is a summary of how the `Quickshell.Services.UPower` API behaves.

## UPower Singleton
The `UPower` singleton is the entry point for power information.

### Properties
- `onBattery` (bool): A daemon-level flag. `false` when the system is connected to ANY AC power source (including USB-C), `true` when running solely on battery. **This is the most reliable way to check for AC connection.**
- `displayDevice` (UPowerDevice): An aggregate device representing the system's overall power status.
- `devices` (UntypedObjectModel): A collection of all power devices.

## UPowerDevice
Objects returned by `UPower.displayDevice` or found within `UPower.devices`.

### Properties (Identified via Object.keys)
- `type` (int): Device type (e.g., `1` for LinePower, `2` for Battery).
- `state` (int): Current state (e.g., `2` for Discharging/Charging, see `UPowerDeviceState` enum).
- `isPresent` (bool): Whether the device is physically present.
- `powerSupply` (bool): Whether the device acts as a power supply.
- `percentage` (real): Charge percentage (0.0 to 1.0).
- `energy` / `energyCapacity` (real): Energy levels in Wh.
- `changeRate` (real): Rate of charge/discharge in W.
- `timeToEmpty` / `timeToFull` (int): Estimated time remaining in seconds.
- `healthPercentage` (real): Battery health.
- `healthSupported` (bool).
- `iconName` (string): The system icon name (e.g., `ac-adapter-symbolic`, `battery-full-symbolic`).
- `nativePath` (string): The sysfs path (e.g., `BAT0`, `AC0`).
- `model` (string).
- `isLaptopBattery` (bool): Convenience flag.
- `ready` (bool): Whether the device object is fully initialized.

### Notable Omissions
- `online`: Although shown in the `upower -i` CLI, the property is **not present** on the QML `UPowerDevice` object.

## Iterating Over Devices
The `UPower.devices` property is an `UntypedObjectModel`. To iterate over it in Javascript/QML:

1. **Accessing values**: Use `UPower.devices.values`.
2. **Iteration**:
   ```javascript
   const devices = UPower.devices.values || [];
   for (let i = 0; i < devices.length; i++) {
     const d = devices[i];
     // ...
   }
   ```

## Enums
- `UPowerDeviceType`:
    - `LinePower`: 1
    - `Battery`: 2
- `UPowerDeviceState`:
    - `Unknown`: 0
    - `Charging`: 1
    - `Discharging`: 2
    - `Empty`: 3
    - `FullyCharged`: 4
    - `PendingCharge`: 5
    - `PendingDischarge`: 6

## Recommendations for BatteryService
- **AC Detection**: Use `!UPower.onBattery`. It is more robust than checking `isCharging` on the battery device, as it remains `false` (meaning AC is connected) even when the battery is not charging due to charge limits.
- **Laptop Detection**: `MainService.isLaptop` combined with `BatteryService.isLaptopBattery`.
