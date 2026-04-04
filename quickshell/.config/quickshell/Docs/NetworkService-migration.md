# NetworkService — Quickshell.Networking Migration

`NetworkService.qml` acts as an adapter: native C++ DBus backend for everything
it supports, nmcli as a fallback only for confirmed API gaps.

## Now using `Quickshell.Networking` (native C++ DBus)

| What | Native call |
|---|---|
| Wifi networks list | `WifiDevice.networks` (ObjectModel) |
| Wifi connected / state | `WifiDevice.connected` |
| Wifi interface name | `WifiDevice.name` |
| Wifi radio on / off | `Networking.wifiEnabled` |
| Service ready check | `Networking.backend !== NetworkBackendType.None` |
| Connect to saved network | `WifiNetwork.connect()` |
| Connect with password | `WifiNetwork.connectWithPsk(psk)` |
| Disconnect wifi | `WifiDevice.disconnect()` |
| Forget network | `WifiNetwork.forget()` |
| Connection error signal | `WifiNetwork.connectionFailed(reason: ConnectionFailReason)` |
| Scanner control | `WifiDevice.scannerEnabled = true/false` |

## Still nmcli — genuine native API gaps

| What | Why native can't |
|---|---|
| Ethernet state / interface / IP | `DeviceType` only has `None` and `Wifi` |
| Wifi IP address | `NetworkDevice.address` is the hardware MAC address |
| `networkingEnabled` toggle | Not exposed in `Networking` singleton |
| Hidden network connect | No hidden-SSID flag in `connectWithPsk` |
| Band / frequency (2.4 / 5 / 6 GHz) | No frequency data anywhere in native API |
| Ethernet connect / disconnect | Follows from no ethernet DeviceType |
| `procMonitor` (nmcli monitor) | Watches for ethernet / networking state changes |

## NMSettings note

`WifiNetwork.nmSettings: list<NMSettings>` is available but unused.
`Network.forget()` handles the common case (removes all profiles for an SSID).
`NMSettings` would only be needed for per-profile management (e.g. a network
saved twice with different credentials) — not currently exposed in the UI.
