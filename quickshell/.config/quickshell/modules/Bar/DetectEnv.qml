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
    property var batteryManager: null  // "power-profile-daemon", "tlp", or null if none

    Component.onCompleted: {
        sessionName = Quickshell.env("XDG_SESSION_DESKTOP") || Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("DESKTOP_SESSION") || "";
    }

    // Detect arch-based (pacman) or other distro
    Process {
        id: detectArch
        command: ["which", "pacman"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("DetectEnv: which pacman output:", this.text);
                if (this.text.trim().length > 0)
                    root.distroId = "arch";
                else
                    root.distroId = "other";
            }
        }
    }

    // Detect power-profiles-daemon availability
    Process {
        id: detectPPD
        command: ["which", "powerprofilesctl"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.isLaptopBattery && this.text.trim().length > 0) {
                    root.batteryManager = "ppd";
                }
            }
        }
    }

    // Detect TLP availability if no power-profiles-daemon found
    Process {
        id: detectTLP
        command: ["which", "tlp"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.isLaptopBattery && root.batteryManager === null && this.text.trim().length > 0) {
                    root.batteryManager = "tlp";
                }
            }
        }
    }
}
