pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: root

    property string sessionName: ""
    readonly property string session: sessionName.toLowerCase().split(":")[0]
    property bool isHyprland: session === "hyprland"
    property bool isNiri: session === "niri"
    property string distroId: "unknown"
    property var upowerDevice: UPower.displayDevice
    readonly property bool isLaptopBattery: upowerDevice && upowerDevice.type === 2 && upowerDevice.isPresent
    property var batteryManager: null  // "ppd", "tlp", or null if none
    property bool hasWifiHardware: false

    Component.onCompleted: {
        sessionName = Quickshell.env("XDG_SESSION_DESKTOP") || Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("DESKTOP_SESSION") || "";
    }

    Process {
        id: wifiCheck
        command: ["sh", "-c", "nmcli -t -f TYPE device | grep -q '^wifi$' && echo yes || echo no"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (data) {
                root.hasWifiHardware = (data.trim() === "yes");
                console.log("WiFi hardware detected:", root.hasWifiHardware);
            }
        }
    }
    // Detect arch-based (pacman) or other distro
    Process {
        id: detectArch
        command: ["which", "pacman"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    root.distroId = "arch";
                else
                    root.distroId = "other";
            }
        }
    }

    // Detect power management tools (PPD has priority over TLP)
    Process {
        id: detectPowerManager
        command: ["sh", "-c", "if which powerprofilesctl >/dev/null 2>&1; then echo 'ppd'; elif which tlp >/dev/null 2>&1; then echo 'tlp'; else echo 'none'; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var result = this.text.trim();
                if (root.isLaptopBattery) {
                    if (result === "ppd") {
                        root.batteryManager = "ppd";
                    } else if (result === "tlp") {
                        root.batteryManager = "tlp";
                    } else {
                        root.batteryManager = null;
                    }
                } else {
                    // Not a laptop, so battery manager is not applicable
                    root.batteryManager = null;
                }
            }
        }
    }
}
